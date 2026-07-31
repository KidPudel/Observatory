import AppKit
import Darwin
import Foundation
import ObservatoryDomain

public actor MacOSApplicationDiscovery: ApplicationDiscovering {
    private let processSampler: MacOSProcessSampler

    public init(processSampler: MacOSProcessSampler) {
        self.processSampler = processSampler
    }

    public func runningApplications() async -> [DiscoveredApplication] {
        let applications = await MainActor.run {
            NSWorkspace.shared.runningApplications.map {
                (
                    bundleIdentifier: $0.bundleIdentifier,
                    bundleURL: $0.bundleURL,
                    displayName: $0.localizedName,
                    processIdentifier: $0.processIdentifier,
                    isTerminated: $0.isTerminated,
                    isActive: $0.isActive,
                    isHidden: $0.isHidden,
                    activationPolicy: $0.activationPolicy
                )
            }
        }

        var discovered: [DiscoveredApplication] = []
        for application in applications {
            guard
                application.activationPolicy == .regular,
                let bundleIdentifier = application.bundleIdentifier,
                let bundleURL = application.bundleURL,
                let displayName = application.displayName
            else {
                continue
            }
            let process = await processSampler.identity(for: application.processIdentifier)

            let state: ApplicationState
            if application.isTerminated {
                state = .terminated
            } else if application.isActive {
                state = .frontmost
            } else if application.isHidden {
                state = .hidden
            } else {
                state = .visible
            }

            discovered.append(
                DiscoveredApplication(
                    identity: ApplicationIdentity(
                        bundleIdentifier: bundleIdentifier,
                        bundleURL: bundleURL
                    ),
                    displayName: displayName,
                    primaryProcessIdentifier: application.processIdentifier,
                    primaryProcess: process,
                    state: state
                )
            )
        }

        return discovered.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }
}

public actor MacOSProcessSampler: ProcessDiscovering, ProcessInventorying, ProcessSampling {
    private let timebase: mach_timebase_info_data_t
    private var calculator = ProcessSampleCalculator()
    private var processCache: [pid_t: DiscoveredProcess] = [:]
    private var bundleIdentifierCache: [String: String] = [:]
    private var pathsWithoutBundleIdentifier: Set<String> = []

    public init(now: Date = Date(), systemUptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        _ = now
        _ = systemUptime
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        timebase = info
    }

    public func runningProcessIdentities() -> [ProcessIdentity] {
        runningPIDs().compactMap(identity(for:))
    }

    public func runningProcesses() -> [DiscoveredProcess] {
        var current: [pid_t: DiscoveredProcess] = [:]
        for processIdentifier in runningPIDs() {
            guard let info = bsdInfo(for: processIdentifier) else { continue }
            let startTime = processStartTime(from: info)

            if let cached = processCache[processIdentifier],
               cached.identity.startTime == startTime {
                current[processIdentifier] = cached
                continue
            }

            let executablePath = executablePath(for: processIdentifier)
            let identity = ProcessIdentity(
                processIdentifier: processIdentifier,
                startTime: startTime,
                executablePath: executablePath
            )
            let process = DiscoveredProcess(
                identity: identity,
                parentProcessIdentifier: parentProcessIdentifier(from: info),
                bundleIdentifier: bundleIdentifier(for: executablePath)
            )
            current[processIdentifier] = process
        }
        processCache = current
        return current.values.sorted {
            $0.identity.processIdentifier < $1.identity.processIdentifier
        }
    }

    private func runningPIDs() -> [pid_t] {
        let capacity = max(Int(proc_listallpids(nil, 0)), 0)
        guard capacity > 0 else { return [] }

        var pids = [pid_t](repeating: 0, count: capacity)
        let processCount = pids.withUnsafeMutableBytes {
            proc_listallpids($0.baseAddress, Int32($0.count))
        }
        guard processCount > 0 else { return [] }

        return pids.prefix(Int(processCount))
            .filter { $0 > 0 }
    }

    public func identity(for processIdentifier: pid_t) -> ProcessIdentity? {
        guard let info = bsdInfo(for: processIdentifier) else { return nil }
        let startTime = processStartTime(from: info)
        if let cached = processCache[processIdentifier],
           cached.identity.startTime == startTime {
            return cached.identity
        }
        return ProcessIdentity(
            processIdentifier: processIdentifier,
            startTime: startTime,
            executablePath: executablePath(for: processIdentifier)
        )
    }

    public func sample(processes: [ProcessIdentity], at date: Date) -> [ProcessSample] {
        let monotonicTime = monotonicNanoseconds()
        return processes.map { expectedIdentity in
            let rawSample: RawProcessSample

            if let usage = resourceUsage(for: expectedIdentity.processIdentifier) {
                if identity(for: expectedIdentity.processIdentifier)?.startTime
                    != expectedIdentity.startTime {
                    rawSample = RawProcessSample(
                        process: expectedIdentity,
                        capturedAt: date,
                        monotonicTimeNanoseconds: monotonicTime,
                        availability: .reusedIdentifier
                    )
                } else {
                    rawSample = RawProcessSample(
                        process: expectedIdentity,
                        capturedAt: date,
                        monotonicTimeNanoseconds: monotonicTime,
                        availability: .available,
                        counters: ProcessCounters(
                            cpuTimeNanoseconds: addingClamped(
                                usage.ri_user_time,
                                usage.ri_system_time
                            ),
                            physicalMemoryBytes: usage.ri_phys_footprint,
                            disk: DiskCounters(
                                bytesRead: usage.ri_diskio_bytesread,
                                bytesWritten: usage.ri_diskio_byteswritten
                            ),
                            wakeups: addingClamped(
                                usage.ri_pkg_idle_wkups,
                                usage.ri_interrupt_wkups
                            ),
                            threadCount: threadCount(for: expectedIdentity.processIdentifier)
                        )
                    )
                }
            } else {
                rawSample = RawProcessSample(
                    process: expectedIdentity,
                    capturedAt: date,
                    monotonicTimeNanoseconds: monotonicTime,
                    availability: processExists(expectedIdentity.processIdentifier) ? .inaccessible : .exited
                )
            }

            return calculator.calculate(from: rawSample)
        }
    }

    private func resourceUsage(for processIdentifier: pid_t) -> rusage_info_v4? {
        var usage = rusage_info_v4()
        let result = withUnsafeMutablePointer(to: &usage) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(processIdentifier, RUSAGE_INFO_V4, $0)
            }
        }
        return result == 0 ? usage : nil
    }

    private func bsdInfo(for processIdentifier: pid_t) -> proc_bsdinfo? {
        var info = proc_bsdinfo()
        let size = MemoryLayout<proc_bsdinfo>.stride
        let read = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(processIdentifier, PROC_PIDTBSDINFO, 0, $0, Int32(size))
        }
        return read == size ? info : nil
    }

    private func processStartTime(from info: proc_bsdinfo) -> Date {
        Date(
            timeIntervalSince1970:
                TimeInterval(info.pbi_start_tvsec)
                + TimeInterval(info.pbi_start_tvusec) / 1_000_000
        )
    }

    private func parentProcessIdentifier(from info: proc_bsdinfo) -> Int32? {
        guard info.pbi_ppid > 0, info.pbi_ppid <= UInt32(Int32.max) else {
            return nil
        }
        return Int32(info.pbi_ppid)
    }

    private func executablePath(for processIdentifier: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN * 4))
        let length = proc_pidpath(processIdentifier, &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(
            decoding: buffer.prefix(Int(length)).map(UInt8.init(bitPattern:)),
            as: UTF8.self
        )
    }

    private func bundleIdentifier(for executablePath: String?) -> String? {
        guard let executablePath else { return nil }
        if let cached = bundleIdentifierCache[executablePath] {
            return cached
        }
        if pathsWithoutBundleIdentifier.contains(executablePath) {
            return nil
        }
        var url = URL(fileURLWithPath: executablePath).deletingLastPathComponent()

        while url.path != "/" {
            if ["app", "xpc"].contains(url.pathExtension.lowercased()),
               let bundleIdentifier = Bundle(url: url)?.bundleIdentifier {
                bundleIdentifierCache[executablePath] = bundleIdentifier
                return bundleIdentifier
            }
            url.deleteLastPathComponent()
        }
        pathsWithoutBundleIdentifier.insert(executablePath)
        return nil
    }

    private func threadCount(for processIdentifier: pid_t) -> Int? {
        var taskInfo = proc_taskinfo()
        let size = MemoryLayout<proc_taskinfo>.stride
        let read = withUnsafeMutablePointer(to: &taskInfo) {
            proc_pidinfo(processIdentifier, PROC_PIDTASKINFO, 0, $0, Int32(size))
        }
        return read == size ? Int(taskInfo.pti_threadnum) : nil
    }

    private func processExists(_ processIdentifier: pid_t) -> Bool {
        if kill(processIdentifier, 0) == 0 { return true }
        return errno != ESRCH
    }

    private func monotonicNanoseconds() -> UInt64 {
        nanoseconds(forMachTicks: mach_continuous_time())
    }

    private func nanoseconds(forMachTicks ticks: UInt64) -> UInt64 {
        let quotient = ticks / UInt64(timebase.denom)
        let remainder = ticks % UInt64(timebase.denom)
        return quotient * UInt64(timebase.numer)
            + remainder * UInt64(timebase.numer) / UInt64(timebase.denom)
    }

    private func addingClamped(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (result, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : result
    }
}

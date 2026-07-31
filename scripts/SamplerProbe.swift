import Foundation
import ObservatoryDomain

@main
struct SamplerProbe {
    static func main() async {
        let iterationCount = 100
        let targetCount = 25
        let sampler = MacOSProcessSampler()
        let discovery = MacOSApplicationDiscovery(processSampler: sampler)
        let applications = await discovery.runningApplications()
        let applicationIdentities = await applications.asyncCompactMap {
            await sampler.identity(for: $0.primaryProcessIdentifier)
        }
        let discoveredProcesses = await sampler.runningProcesses()
        let applicationPIDs = Set(applicationIdentities.map(\.processIdentifier))
        let supplemental = discoveredProcesses.map(\.identity).filter {
            !applicationPIDs.contains($0.processIdentifier)
        }
        let targets = Array((applicationIdentities + supplemental).prefix(targetCount))

        guard !targets.isEmpty else {
            print("FAIL: no regular applications were discoverable")
            Foundation.exit(1)
        }

        let workloadPassed = await verifyKnownWorkload(using: sampler)
        var passDurations: [Double] = []
        var availableSampleCount = 0
        for _ in 0..<iterationCount {
            let start = ContinuousClock.now
            let samples = await sampler.sample(processes: targets, at: Date())
            passDurations.append(start.duration(to: .now).seconds)
            availableSampleCount += samples.count { $0.availability == .available }
        }

        let exitedIdentity = ProcessIdentity(
            processIdentifier: Int32.max,
            startTime: .distantPast
        )
        let exited = await sampler.sample(processes: [exitedIdentity], at: Date()).first
        let sorted = passDurations.sorted()
        let p95Index = min(Int(Double(sorted.count) * 0.95), sorted.count - 1)
        let average = passDurations.reduce(0, +) / Double(passDurations.count)
        let p95 = sorted[p95Index]
        let estimatedCorePercent = average * 100

        print("Regular applications discovered: \(applicationIdentities.count)")
        print(
            "Processes with parent evidence: "
                + "\(discoveredProcesses.filter { $0.parentProcessIdentifier != nil }.count)"
        )
        print(
            "Processes with bundle evidence: "
                + "\(discoveredProcesses.filter { $0.bundleIdentifier != nil }.count)"
        )
        print("Processes sampled per pass: \(targets.count)")
        print("Available samples: \(availableSampleCount)/\(targets.count * iterationCount)")
        print(String(format: "Average pass: %.3f ms", average * 1_000))
        print(String(format: "P95 pass: %.3f ms", p95 * 1_000))
        print(String(format: "Estimated one-second-cadence cost: %.3f%% of one core", estimatedCorePercent))
        print("Synthetic absent PID state: \(exited?.availability.rawValue ?? "missing")")

        let passed = workloadPassed
            && discoveredProcesses.contains(where: { $0.parentProcessIdentifier != nil })
            && discoveredProcesses.contains(where: { $0.bundleIdentifier != nil })
            && estimatedCorePercent <= 2
            && p95 <= 0.1
            && exited?.availability == .exited
        print(passed ? "PASS" : "FAIL")
        if !passed {
            Foundation.exit(1)
        }
    }

    private static func verifyKnownWorkload(using sampler: MacOSProcessSampler) async -> Bool {
        guard let identity = await sampler.identity(for: getpid()) else {
            print("Known workload: FAIL (probe identity unavailable)")
            return false
        }

        _ = await sampler.sample(processes: [identity], at: Date())

        var checksum: UInt64 = 0
        for value in 0..<2_000_000 {
            checksum &+= UInt64(value) &* 31
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("observatory-sampler-\(UUID().uuidString)")
        do {
            try Data(repeating: 0x5a, count: 2 * 1_024 * 1_024).write(
                to: fileURL,
                options: .withoutOverwriting
            )
            try FileManager.default.removeItem(at: fileURL)
        } catch {
            print("Known workload: FAIL (\(error.localizedDescription))")
            return false
        }

        guard
            checksum > 0,
            let sample = await sampler.sample(processes: [identity], at: Date()).first
        else {
            print("Known workload: FAIL (sample unavailable)")
            return false
        }

        let passed = sample.availability == .available
            && (sample.cpuCoreUsage ?? 0) > 0
            && (sample.physicalMemoryBytes ?? 0) > 0
            && sample.diskReadBytesPerSecond != nil
            && (sample.diskWriteBytesPerSecond ?? 0) > 0
            && sample.wakeupsPerSecond != nil
            && (sample.threadCount ?? 0) > 0

        print(
            String(
                format: "Known workload: %@ (CPU %.3f cores, writes %.0f B/s, memory %llu B, threads %d)",
                passed ? "PASS" : "FAIL",
                sample.cpuCoreUsage ?? -1,
                sample.diskWriteBytesPerSecond ?? -1,
                sample.physicalMemoryBytes ?? 0,
                sample.threadCount ?? -1
            )
        )
        return passed
    }
}

private extension Duration {
    var seconds: Double {
        let parts = components
        return Double(parts.seconds) + Double(parts.attoseconds) / 1e18
    }
}

private extension Sequence {
    func asyncCompactMap<T>(
        _ transform: (Element) async -> T?
    ) async -> [T] {
        var transformed: [T] = []
        for element in self {
            if let value = await transform(element) {
                transformed.append(value)
            }
        }
        return transformed
    }
}

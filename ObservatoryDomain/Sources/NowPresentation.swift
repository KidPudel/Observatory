import Foundation

public enum CPURepresentation: String, Codable, CaseIterable, Identifiable, Sendable {
    case cores
    case activityMonitorPercentage
    case totalCapacityPercentage

    public static let productDefault: Self = .activityMonitorPercentage

    public var id: Self { self }

    public func value(coreUsage: Double, logicalProcessorCount: Int) -> Double {
        switch self {
        case .cores:
            return coreUsage
        case .activityMonitorPercentage:
            return coreUsage * 100
        case .totalCapacityPercentage:
            guard logicalProcessorCount > 0 else { return 0 }
            return coreUsage / Double(logicalProcessorCount) * 100
        }
    }
}

public enum NowSortOption: String, Codable, CaseIterable, Identifiable, Sendable {
    case name
    case cpu
    case memory
    case disk
    case wakeups
    case processCount

    public var id: Self { self }
}

public struct NowProcessSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: ProcessIdentity { process.identity }

    public let process: DiscoveredProcess
    public let displayName: String
    public let sample: ProcessSample?
    public let ownership: ProcessOwnership

    public init(
        process: DiscoveredProcess,
        displayName: String,
        sample: ProcessSample?,
        ownership: ProcessOwnership
    ) {
        self.process = process
        self.displayName = displayName
        self.sample = sample
        self.ownership = ownership
    }

    public var ruleMatcher: ProcessRuleMatcher? {
        if let bundleIdentifier = process.bundleIdentifier {
            return .bundleIdentifier(bundleIdentifier)
        }
        if let executablePath = process.identity.executablePath {
            return .executablePath(executablePath)
        }
        return nil
    }
}

public struct NowApplicationSnapshot: Codable, Equatable, Identifiable, Sendable {
    public var id: ApplicationIdentity { application.identity }

    public let application: DiscoveredApplication
    public let state: ApplicationState
    public let metrics: GroupedProcessMetrics
    public let memoryPeakBytes: UInt64?
    public let members: [NowProcessSnapshot]
    public let isPartialTotal: Bool
    public let partialExplanation: String?

    public init(
        application: DiscoveredApplication,
        state: ApplicationState,
        metrics: GroupedProcessMetrics,
        memoryPeakBytes: UInt64?,
        members: [NowProcessSnapshot],
        isPartialTotal: Bool,
        partialExplanation: String?
    ) {
        self.application = application
        self.state = state
        self.metrics = metrics
        self.memoryPeakBytes = memoryPeakBytes
        self.members = members
        self.isPartialTotal = isPartialTotal
        self.partialExplanation = partialExplanation
    }

    public func matches(searchText: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }
        if application.displayName.localizedCaseInsensitiveContains(query) {
            return true
        }
        return members.contains {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }
}

public struct NowSnapshot: Codable, Equatable, Sendable {
    public let capturedAt: Date
    public let applications: [NowApplicationSnapshot]
    public let unassignedProcesses: [NowProcessSnapshot]
    public let systemProcessCount: Int

    public init(
        capturedAt: Date,
        applications: [NowApplicationSnapshot],
        unassignedProcesses: [NowProcessSnapshot],
        systemProcessCount: Int = 0
    ) {
        self.capturedAt = capturedAt
        self.applications = applications
        self.unassignedProcesses = unassignedProcesses
        self.systemProcessCount = systemProcessCount
    }

    public static let empty = NowSnapshot(
        capturedAt: .distantPast,
        applications: [],
        unassignedProcesses: [],
        systemProcessCount: 0
    )

    public func applications(
        matching searchText: String,
        sortedBy sort: NowSortOption
    ) -> [NowApplicationSnapshot] {
        let matching = applications.filter { $0.matches(searchText: searchText) }
        return matching.sorted { lhs, rhs in
            switch sort {
            case .name:
                return compareNames(lhs, rhs)
            case .cpu:
                return compareDescending(
                    lhs.metrics.cpuCoreUsage,
                    rhs.metrics.cpuCoreUsage,
                    lhs: lhs,
                    rhs: rhs
                )
            case .memory:
                return compareDescending(
                    lhs.metrics.physicalMemoryBytes.map { Double($0) },
                    rhs.metrics.physicalMemoryBytes.map { Double($0) },
                    lhs: lhs,
                    rhs: rhs
                )
            case .disk:
                return compareDescending(
                    diskRate(lhs.metrics),
                    diskRate(rhs.metrics),
                    lhs: lhs,
                    rhs: rhs
                )
            case .wakeups:
                return compareDescending(
                    lhs.metrics.wakeupsPerSecond,
                    rhs.metrics.wakeupsPerSecond,
                    lhs: lhs,
                    rhs: rhs
                )
            case .processCount:
                if lhs.metrics.processCount == rhs.metrics.processCount {
                    return compareNames(lhs, rhs)
                }
                return lhs.metrics.processCount > rhs.metrics.processCount
            }
        }
    }

    private func diskRate(_ metrics: GroupedProcessMetrics) -> Double? {
        let values = [
            metrics.diskReadBytesPerSecond,
            metrics.diskWriteBytesPerSecond
        ].compactMap { $0 }
        return values.isEmpty ? nil : values.reduce(0, +)
    }

    private func compareDescending(
        _ lhsValue: Double?,
        _ rhsValue: Double?,
        lhs: NowApplicationSnapshot,
        rhs: NowApplicationSnapshot
    ) -> Bool {
        switch (lhsValue, rhsValue) {
        case let (.some(left), .some(right)):
            return left == right ? compareNames(lhs, rhs) : left > right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return compareNames(lhs, rhs)
        }
    }

    private func compareNames(
        _ lhs: NowApplicationSnapshot,
        _ rhs: NowApplicationSnapshot
    ) -> Bool {
        lhs.application.displayName.localizedStandardCompare(
            rhs.application.displayName
        ) == .orderedAscending
    }
}

public struct NowTimelineApplicationPoint: Equatable, Identifiable, Sendable {
    public var id: ApplicationIdentity { application }

    public let application: ApplicationIdentity
    public let displayName: String
    public let metrics: GroupedProcessMetrics

    public init(snapshot: NowApplicationSnapshot) {
        application = snapshot.id
        displayName = snapshot.application.displayName
        metrics = snapshot.metrics
    }

    public func value(
        for metric: ResultTimelineMetric,
        cpuRepresentation: CPURepresentation,
        logicalProcessorCount: Int
    ) -> Double? {
        switch metric {
        case .cpu:
            return metrics.cpuCoreUsage.map {
                cpuRepresentation.value(
                    coreUsage: $0,
                    logicalProcessorCount: logicalProcessorCount
                )
            }
        case .memory:
            return metrics.physicalMemoryBytes.map { Double($0) }
        case .disk:
            guard
                let read = metrics.diskReadBytesPerSecond,
                let write = metrics.diskWriteBytesPerSecond
            else {
                return nil
            }
            return read + write
        case .wakeups:
            return metrics.wakeupsPerSecond
        case .processCount:
            return Double(metrics.processCount)
        }
    }
}

public struct NowTimelineSystemCapacity: Equatable, Sendable {
    public let logicalProcessorCount: Int
    public let physicalMemoryBytes: UInt64

    public init(
        logicalProcessorCount: Int,
        physicalMemoryBytes: UInt64
    ) {
        self.logicalProcessorCount = max(logicalProcessorCount, 1)
        self.physicalMemoryBytes = physicalMemoryBytes
    }

    public func value(
        for metric: ResultTimelineMetric,
        cpuRepresentation: CPURepresentation
    ) -> Double? {
        switch metric {
        case .cpu:
            switch cpuRepresentation {
            case .activityMonitorPercentage:
                return Double(logicalProcessorCount) * 100
            case .cores:
                return Double(logicalProcessorCount)
            case .totalCapacityPercentage:
                return 100
            }
        case .memory:
            guard physicalMemoryBytes > 0 else { return nil }
            return Double(physicalMemoryBytes)
        case .disk, .wakeups, .processCount:
            return nil
        }
    }
}

public struct NowTimelinePoint: Equatable, Identifiable, Sendable {
    public var id: Date { capturedAt }

    public let capturedAt: Date
    public let applications: [NowTimelineApplicationPoint]

    public init(snapshot: NowSnapshot) {
        capturedAt = snapshot.capturedAt
        applications = snapshot.applications.map(NowTimelineApplicationPoint.init)
    }

    public func totalValue(
        for metric: ResultTimelineMetric,
        cpuRepresentation: CPURepresentation,
        logicalProcessorCount: Int
    ) -> Double? {
        guard !applications.isEmpty else { return nil }
        let values = applications.compactMap {
            $0.value(
                for: metric,
                cpuRepresentation: cpuRepresentation,
                logicalProcessorCount: logicalProcessorCount
            )
        }
        guard values.count == applications.count else { return nil }
        return values.reduce(0, +)
    }
}

public struct NowTimelineAccumulator: Equatable, Sendable {
    public private(set) var points: [NowTimelinePoint]
    public let windowDuration: TimeInterval

    public init(
        windowDuration: TimeInterval = 60,
        points: [NowTimelinePoint] = []
    ) {
        self.windowDuration = windowDuration
        self.points = points
    }

    public mutating func ingest(_ snapshot: NowSnapshot) {
        guard snapshot.capturedAt != .distantPast else { return }
        let point = NowTimelinePoint(snapshot: snapshot)
        if let last = points.last, point.capturedAt < last.capturedAt {
            points.removeAll(keepingCapacity: true)
        }
        if points.last?.capturedAt == point.capturedAt {
            points[points.count - 1] = point
        } else {
            points.append(point)
        }

        let cutoff = point.capturedAt.addingTimeInterval(-windowDuration)
        points.removeAll { $0.capturedAt < cutoff }
    }
}

public struct NowSnapshotAccumulator: Sendable {
    private struct TimedCPUValue: Sendable {
        let capturedAt: Date
        let interval: TimeInterval
        let value: Double
    }

    private let rollingWindow: TimeInterval
    private var cpuHistory: [ApplicationIdentity: [TimedCPUValue]] = [:]
    private var memoryPeaks: [ApplicationIdentity: UInt64] = [:]
    private var lastCapturedAt: Date?

    public init(rollingWindow: TimeInterval = 5) {
        self.rollingWindow = rollingWindow
    }

    public mutating func ingest(
        grouping: GroupingResult,
        processes: [DiscoveredProcess],
        samples: [ProcessSample],
        capturedAt: Date
    ) -> NowSnapshot {
        if let lastCapturedAt, capturedAt < lastCapturedAt {
            cpuHistory.removeAll(keepingCapacity: true)
        }
        lastCapturedAt = capturedAt
        let processByIdentity = Dictionary(
            processes.map { ($0.identity, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let sampleByIdentity = Dictionary(
            samples.map { ($0.process, $0) },
            uniquingKeysWith: { first, second in
                first.capturedAt >= second.capturedAt ? first : second
            }
        )
        let liveApplicationIDs = Set(grouping.groups.map(\.application.identity))
        cpuHistory = cpuHistory.filter { liveApplicationIDs.contains($0.key) }
        memoryPeaks = memoryPeaks.filter { liveApplicationIDs.contains($0.key) }

        let applications = grouping.groups.map { group in
            makeApplication(
                group,
                allOwnerships: grouping.ownerships,
                processByIdentity: processByIdentity,
                sampleByIdentity: sampleByIdentity,
                capturedAt: capturedAt
            )
        }
        let allUnassigned = grouping.ownerships.filter { $0.application == nil }
        let ambiguousUnassigned = allUnassigned.filter {
            !$0.evidence.isEmpty || !$0.conflictingApplications.isEmpty
        }
        let unassigned = ambiguousUnassigned
            .compactMap {
                makeProcess(
                    ownership: $0,
                    processByIdentity: processByIdentity,
                    sampleByIdentity: sampleByIdentity
                )
            }
            .sorted {
                if $0.displayName == $1.displayName {
                    return $0.process.identity.processIdentifier
                        < $1.process.identity.processIdentifier
                }
                return $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }

        return NowSnapshot(
            capturedAt: capturedAt,
            applications: applications,
            unassignedProcesses: unassigned,
            systemProcessCount: allUnassigned.count - ambiguousUnassigned.count
        )
    }

    private mutating func makeApplication(
        _ group: ApplicationGroupSnapshot,
        allOwnerships: [ProcessOwnership],
        processByIdentity: [ProcessIdentity: DiscoveredProcess],
        sampleByIdentity: [ProcessIdentity: ProcessSample],
        capturedAt: Date
    ) -> NowApplicationSnapshot {
        let identity = group.application.identity
        updateCPUHistory(
            for: identity,
            value: group.metrics.cpuCoreUsage,
            interval: representativeInterval(
                members: group.members,
                samples: sampleByIdentity
            ),
            capturedAt: capturedAt
        )
        let rollingCPU = rollingAverage(for: identity, at: capturedAt)

        if let memory = group.metrics.physicalMemoryBytes {
            memoryPeaks[identity] = max(memoryPeaks[identity] ?? 0, memory)
        }

        let possibleUnassigned = allOwnerships.contains {
            $0.application == nil && $0.conflictingApplications.contains(identity)
        }
        var partialReasons: [String] = []
        if group.metrics.unavailableProcessCount > 0 {
            let count = group.metrics.unavailableProcessCount
            partialReasons.append(
                "\(count) \(count == 1 ? "process is" : "processes are") unavailable"
            )
        }
        if group.members.contains(where: { $0.confidence < .high }) {
            partialReasons.append("some ownership is uncertain")
        }
        if possibleUnassigned {
            partialReasons.append("an unassigned process may belong here")
        }
        if group.members.isEmpty {
            partialReasons.append("the primary process could not be measured")
        }

        let members = group.members.compactMap {
            makeProcess(
                ownership: $0,
                processByIdentity: processByIdentity,
                sampleByIdentity: sampleByIdentity
            )
        }
        let metrics = GroupedProcessMetrics(
            cpuCoreUsage: rollingCPU,
            physicalMemoryBytes: group.metrics.physicalMemoryBytes,
            diskReadBytesPerSecond: group.metrics.diskReadBytesPerSecond,
            diskWriteBytesPerSecond: group.metrics.diskWriteBytesPerSecond,
            wakeupsPerSecond: group.metrics.wakeupsPerSecond,
            processCount: group.metrics.processCount,
            threadCount: group.metrics.threadCount,
            unavailableProcessCount: group.metrics.unavailableProcessCount
        )

        return NowApplicationSnapshot(
            application: group.application,
            state: presentationState(
                platformState: group.application.state,
                metrics: metrics
            ),
            metrics: metrics,
            memoryPeakBytes: memoryPeaks[identity],
            members: members,
            isPartialTotal: !partialReasons.isEmpty,
            partialExplanation: partialReasons.isEmpty
                ? nil
                : partialReasons.joined(separator: "; ") + "."
        )
    }

    private func makeProcess(
        ownership: ProcessOwnership,
        processByIdentity: [ProcessIdentity: DiscoveredProcess],
        sampleByIdentity: [ProcessIdentity: ProcessSample]
    ) -> NowProcessSnapshot? {
        guard let process = processByIdentity[ownership.process] else { return nil }
        let displayName = process.identity.executablePath.map {
            URL(fileURLWithPath: $0).lastPathComponent
        }.flatMap { $0.isEmpty ? nil : $0 }
            ?? "Process \(process.identity.processIdentifier)"
        return NowProcessSnapshot(
            process: process,
            displayName: displayName,
            sample: sampleByIdentity[ownership.process],
            ownership: ownership
        )
    }

    private func representativeInterval(
        members: [ProcessOwnership],
        samples: [ProcessIdentity: ProcessSample]
    ) -> TimeInterval? {
        let intervals = members.compactMap { samples[$0.process]?.intervalSeconds }
            .filter { $0 > 0 }
            .sorted()
        guard !intervals.isEmpty else { return nil }
        return intervals[intervals.count / 2]
    }

    private mutating func updateCPUHistory(
        for application: ApplicationIdentity,
        value: Double?,
        interval: TimeInterval?,
        capturedAt: Date
    ) {
        let cutoff = capturedAt.addingTimeInterval(-rollingWindow)
        var history = cpuHistory[application, default: []]
        history.removeAll { $0.capturedAt <= cutoff }
        if let value, let interval, interval > 0 {
            history.append(
                TimedCPUValue(
                    capturedAt: capturedAt,
                    interval: min(interval, rollingWindow),
                    value: value
                )
            )
        }
        cpuHistory[application] = history
    }

    private func rollingAverage(
        for application: ApplicationIdentity,
        at capturedAt: Date
    ) -> Double? {
        let windowStart = capturedAt.addingTimeInterval(-rollingWindow)
        let weighted = cpuHistory[application, default: []].compactMap { item -> (Double, Double)? in
            let sampleStart = item.capturedAt.addingTimeInterval(-item.interval)
            let overlapStart = max(sampleStart, windowStart)
            let overlapEnd = min(item.capturedAt, capturedAt)
            let duration = overlapEnd.timeIntervalSince(overlapStart)
            return duration > 0 ? (item.value * duration, duration) : nil
        }
        let duration = weighted.reduce(0) { $0 + $1.1 }
        guard duration > 0 else { return nil }
        return weighted.reduce(0) { $0 + $1.0 } / duration
    }

    private func presentationState(
        platformState: ApplicationState,
        metrics: GroupedProcessMetrics
    ) -> ApplicationState {
        guard platformState != .frontmost, platformState != .terminated else {
            return platformState
        }
        let diskRate = [
            metrics.diskReadBytesPerSecond,
            metrics.diskWriteBytesPerSecond
        ].compactMap { $0 }.reduce(0, +)
        let hasActivityMeasurement =
            metrics.cpuCoreUsage != nil
            || metrics.diskReadBytesPerSecond != nil
            || metrics.diskWriteBytesPerSecond != nil
            || metrics.wakeupsPerSecond != nil
        let isQuiet =
            (metrics.cpuCoreUsage ?? 0) < 0.01
            && diskRate < 1_024
            && (metrics.wakeupsPerSecond ?? 0) < 1
        return hasActivityMeasurement && isQuiet ? .idle : platformState
    }
}

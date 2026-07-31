import Foundation

public enum ControlledTestMode: String, Codable, CaseIterable, Sendable {
    case manualGuided
    case automaticForegroundIdle
}

public enum GlobalShortcutChoice: String, Codable, CaseIterable, Identifiable, Sendable {
    case none
    case commandOptionSpace
    case controlOptionReturn

    public var id: Self { self }
}

public struct SessionApplication: Codable, Equatable, Hashable, Identifiable, Sendable {
    public var id: ApplicationIdentity { identity }

    public let identity: ApplicationIdentity
    public let displayName: String
    public let version: String?

    public init(
        identity: ApplicationIdentity,
        displayName: String,
        version: String? = nil
    ) {
        self.identity = identity
        self.displayName = displayName
        self.version = version
    }
}

public struct ControlledTestConfiguration: Codable, Equatable, Sendable {
    public let measuredDuration: TimeInterval
    public let warmUpDuration: TimeInterval
    public let roundCount: Int
    public let shortcut: GlobalShortcutChoice

    public init(
        measuredDuration: TimeInterval,
        warmUpDuration: TimeInterval,
        roundCount: Int,
        shortcut: GlobalShortcutChoice = .none
    ) {
        self.measuredDuration = measuredDuration
        self.warmUpDuration = warmUpDuration
        self.roundCount = roundCount
        self.shortcut = shortcut
    }

    public var isValid: Bool {
        measuredDuration > 0
            && warmUpDuration >= 0
            && roundCount > 0
    }
}

// Retained as a source-compatible alias while persisted sessions continue to
// use the original `manualConfiguration` JSON key.
public typealias ManualTestConfiguration = ControlledTestConfiguration

public enum SessionRoundStatus: String, Codable, CaseIterable, Sendable {
    case pending
    case activating
    case warmingUp
    case recording
    case completed
    case failed
    case skipped
    case interrupted
    case cancelled
}

public struct SessionRound: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let application: SessionApplication
    public let roundNumber: Int
    public let sequenceNumber: Int
    public let status: SessionRoundStatus
    public let startedAt: Date?
    public let measuredAt: Date?
    public let endedAt: Date?
    public let interruptionReason: String?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        application: SessionApplication,
        roundNumber: Int,
        sequenceNumber: Int,
        status: SessionRoundStatus = .pending,
        startedAt: Date? = nil,
        measuredAt: Date? = nil,
        endedAt: Date? = nil,
        interruptionReason: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.application = application
        self.roundNumber = roundNumber
        self.sequenceNumber = sequenceNumber
        self.status = status
        self.startedAt = startedAt
        self.measuredAt = measuredAt
        self.endedAt = endedAt
        self.interruptionReason = interruptionReason
    }

    public func updating(
        status: SessionRoundStatus,
        startedAt: Date? = nil,
        measuredAt: Date? = nil,
        endedAt: Date? = nil,
        interruptionReason: String? = nil
    ) -> SessionRound {
        SessionRound(
            id: id,
            sessionID: sessionID,
            application: application,
            roundNumber: roundNumber,
            sequenceNumber: sequenceNumber,
            status: status,
            startedAt: startedAt ?? self.startedAt,
            measuredAt: measuredAt ?? self.measuredAt,
            endedAt: endedAt ?? self.endedAt,
            interruptionReason: interruptionReason ?? self.interruptionReason
        )
    }
}

public struct ApplicationMetricReading: Codable, Equatable, Sendable {
    public let application: ApplicationIdentity
    public let capturedAt: Date
    public let state: ApplicationState
    public let metrics: GroupedProcessMetrics
    public let isPartial: Bool

    public init(
        application: ApplicationIdentity,
        capturedAt: Date,
        state: ApplicationState,
        metrics: GroupedProcessMetrics,
        isPartial: Bool
    ) {
        self.application = application
        self.capturedAt = capturedAt
        self.state = state
        self.metrics = metrics
        self.isPartial = isPartial
    }
}

public struct SessionMetricSample: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let roundID: UUID
    public let application: ApplicationIdentity
    public let capturedAt: Date
    public let elapsed: TimeInterval
    public let isWarmUp: Bool
    public let state: ApplicationState
    public let metrics: GroupedProcessMetrics
    public let isPartial: Bool

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        roundID: UUID,
        application: ApplicationIdentity,
        capturedAt: Date,
        elapsed: TimeInterval,
        isWarmUp: Bool,
        state: ApplicationState,
        metrics: GroupedProcessMetrics,
        isPartial: Bool
    ) {
        self.id = id
        self.sessionID = sessionID
        self.roundID = roundID
        self.application = application
        self.capturedAt = capturedAt
        self.elapsed = elapsed
        self.isWarmUp = isWarmUp
        self.state = state
        self.metrics = metrics
        self.isPartial = isPartial
    }
}

public struct ApplicationResultSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let sessionID: UUID
    public let application: SessionApplication
    public let completedRoundCount: Int
    public let measuredDuration: TimeInterval
    public let sampleCount: Int
    public let averageCPUCoreUsage: Double?
    public let peakCPUCoreUsage: Double?
    public let averageMemoryBytes: Double?
    public let peakMemoryBytes: UInt64?
    public let diskReadBytes: Double?
    public let diskWriteBytes: Double?
    public let averageWakeupsPerSecond: Double?
    public let peakProcessCount: Int?
    public let peakThreadCount: Int?

    public init(
        id: UUID = UUID(),
        sessionID: UUID,
        application: SessionApplication,
        completedRoundCount: Int,
        measuredDuration: TimeInterval,
        sampleCount: Int,
        averageCPUCoreUsage: Double?,
        peakCPUCoreUsage: Double?,
        averageMemoryBytes: Double?,
        peakMemoryBytes: UInt64?,
        diskReadBytes: Double?,
        diskWriteBytes: Double?,
        averageWakeupsPerSecond: Double?,
        peakProcessCount: Int?,
        peakThreadCount: Int?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.application = application
        self.completedRoundCount = completedRoundCount
        self.measuredDuration = measuredDuration
        self.sampleCount = sampleCount
        self.averageCPUCoreUsage = averageCPUCoreUsage
        self.peakCPUCoreUsage = peakCPUCoreUsage
        self.averageMemoryBytes = averageMemoryBytes
        self.peakMemoryBytes = peakMemoryBytes
        self.diskReadBytes = diskReadBytes
        self.diskWriteBytes = diskWriteBytes
        self.averageWakeupsPerSecond = averageWakeupsPerSecond
        self.peakProcessCount = peakProcessCount
        self.peakThreadCount = peakThreadCount
    }
}

public struct ControlledTestResult: Codable, Equatable, Sendable {
    public let session: MonitoringSession
    public let rounds: [SessionRound]
    public let samples: [SessionMetricSample]
    public let summaries: [ApplicationResultSummary]

    public init(
        session: MonitoringSession,
        rounds: [SessionRound],
        samples: [SessionMetricSample],
        summaries: [ApplicationResultSummary]
    ) {
        self.session = session
        self.rounds = rounds
        self.samples = samples
        self.summaries = summaries
    }
}

public typealias ManualTestResult = ControlledTestResult

public enum ResultTimelineMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case memory
    case disk
    case wakeups
    case processCount

    public var id: Self { self }
}

public enum ResultTimelineComponent: String, CaseIterable, Hashable, Sendable {
    case primary
    case diskRead
    case diskWrite
}

public struct ResultTimelineSample: Equatable, Identifiable, Sendable {
    public var id: UUID { sample.id }

    public let sample: SessionMetricSample
    public let application: SessionApplication
    public let round: SessionRound
    public let elapsed: TimeInterval

    public init(
        sample: SessionMetricSample,
        application: SessionApplication,
        round: SessionRound,
        elapsed: TimeInterval
    ) {
        self.sample = sample
        self.application = application
        self.round = round
        self.elapsed = elapsed
    }

    public func value(
        for metric: ResultTimelineMetric,
        component: ResultTimelineComponent = .primary
    ) -> Double? {
        switch (metric, component) {
        case (.cpu, .primary):
            sample.metrics.cpuCoreUsage.map { $0 * 100 }
        case (.memory, .primary):
            sample.metrics.physicalMemoryBytes.map { Double($0) }
        case (.disk, .diskRead):
            sample.metrics.diskReadBytesPerSecond
        case (.disk, .diskWrite):
            sample.metrics.diskWriteBytesPerSecond
        case (.wakeups, .primary):
            sample.metrics.wakeupsPerSecond
        case (.processCount, .primary):
            Double(sample.metrics.processCount)
        default:
            nil
        }
    }
}

public struct ResultTimelinePoint: Equatable, Identifiable, Sendable {
    public struct ID: Equatable, Hashable, Sendable {
        public let sampleID: UUID
        public let component: ResultTimelineComponent

        public init(
            sampleID: UUID,
            component: ResultTimelineComponent
        ) {
            self.sampleID = sampleID
            self.component = component
        }
    }

    public var id: ID {
        ID(sampleID: sample.id, component: component)
    }

    public let sample: ResultTimelineSample
    public let component: ResultTimelineComponent
    public let value: Double
    public let segment: Int

    public init(
        sample: ResultTimelineSample,
        component: ResultTimelineComponent,
        value: Double,
        segment: Int
    ) {
        self.sample = sample
        self.component = component
        self.value = value
        self.segment = segment
    }
}

public struct ResultTimeline: Equatable, Sendable {
    public let applications: [SessionApplication]
    public let samples: [ResultTimelineSample]

    public init(result: ControlledTestResult) {
        let applicationOrder = Dictionary(
            uniqueKeysWithValues: result.session.applications.enumerated().map {
                ($0.element.identity, $0.offset)
            }
        )
        let applicationsByID = Dictionary(
            uniqueKeysWithValues: result.session.applications.map {
                ($0.identity, $0)
            }
        )
        let roundsByID = Dictionary(
            uniqueKeysWithValues: result.rounds.map { ($0.id, $0) }
        )
        let warmUpDuration =
            result.session.controlledTestConfiguration?.warmUpDuration ?? 0

        applications = result.session.applications.filter { application in
            result.samples.contains { $0.application == application.identity }
        }
        samples = result.samples.compactMap { sample in
            guard let application = applicationsByID[sample.application],
                  let round = roundsByID[sample.roundID] else {
                return nil
            }
            let elapsed: TimeInterval
            if sample.isWarmUp {
                if let measuredAt = round.measuredAt {
                    elapsed = min(
                        -Double.ulpOfOne,
                        sample.capturedAt.timeIntervalSince(measuredAt)
                    )
                } else if let startedAt = round.startedAt {
                    elapsed = min(
                        -Double.ulpOfOne,
                        sample.capturedAt.timeIntervalSince(
                            startedAt.addingTimeInterval(warmUpDuration)
                        )
                    )
                } else {
                    elapsed = -warmUpDuration
                }
            } else {
                elapsed = sample.elapsed
            }
            return ResultTimelineSample(
                sample: sample,
                application: application,
                round: round,
                elapsed: elapsed
            )
        }
        .sorted {
            let lhsApplication = applicationOrder[$0.application.identity] ?? .max
            let rhsApplication = applicationOrder[$1.application.identity] ?? .max
            if lhsApplication != rhsApplication {
                return lhsApplication < rhsApplication
            }
            if $0.round.sequenceNumber != $1.round.sequenceNumber {
                return $0.round.sequenceNumber < $1.round.sequenceNumber
            }
            if $0.elapsed != $1.elapsed {
                return $0.elapsed < $1.elapsed
            }
            return $0.sample.capturedAt < $1.sample.capturedAt
        }
    }

    public var elapsedDomain: ClosedRange<TimeInterval> {
        guard let minimum = samples.map(\.elapsed).min(),
              let maximum = samples.map(\.elapsed).max() else {
            return 0...1
        }
        if minimum == maximum {
            return minimum...(maximum + 1)
        }
        return minimum...maximum
    }

    public func samples(
        for application: ApplicationIdentity
    ) -> [ResultTimelineSample] {
        samples.filter { $0.application.identity == application }
    }

    public func points(
        for application: ApplicationIdentity,
        metric: ResultTimelineMetric
    ) -> [ResultTimelinePoint] {
        let components: [ResultTimelineComponent] =
            metric == .disk ? [.diskRead, .diskWrite] : [.primary]
        let applicationSamples = samples(for: application)
        let grouped = Dictionary(grouping: applicationSamples) { $0.round.id }
        var points: [ResultTimelinePoint] = []

        for roundSamples in grouped.values {
            for component in components {
                var segment = 0
                var previousWasWarmUp: Bool?
                for sample in roundSamples.sorted(by: sampleSort) {
                    if let previousWasWarmUp,
                       previousWasWarmUp != sample.sample.isWarmUp {
                        segment += 1
                    }
                    previousWasWarmUp = sample.sample.isWarmUp
                    guard let value = sample.value(
                        for: metric,
                        component: component
                    ) else {
                        segment += 1
                        continue
                    }
                    points.append(
                        ResultTimelinePoint(
                            sample: sample,
                            component: component,
                            value: value,
                            segment: segment
                        )
                    )
                }
            }
        }

        return points.sorted {
            if $0.sample.round.sequenceNumber
                != $1.sample.round.sequenceNumber {
                return $0.sample.round.sequenceNumber
                    < $1.sample.round.sequenceNumber
            }
            if $0.component != $1.component {
                return $0.component.rawValue < $1.component.rawValue
            }
            return $0.sample.elapsed < $1.sample.elapsed
        }
    }

    public func nearestSamples(
        to elapsed: TimeInterval
    ) -> [ResultTimelineSample] {
        let grouped = Dictionary(grouping: samples) {
            SelectionKey(
                application: $0.application.identity,
                roundID: $0.round.id
            )
        }
        return grouped.values.compactMap { candidates in
            let samePhase = candidates.filter {
                elapsed < 0 ? $0.sample.isWarmUp : !$0.sample.isWarmUp
            }
            let eligible = samePhase.isEmpty ? candidates : samePhase
            let elapsedValues = eligible.map(\.elapsed).sorted()
            guard let minimum = elapsedValues.first,
                  let maximum = elapsedValues.last else {
                return nil
            }
            let intervals = zip(
                elapsedValues.dropFirst(),
                elapsedValues
            )
            .map { later, earlier in later - earlier }
            .filter { $0 > 0 }
            .sorted()
            let cadence = intervals.isEmpty
                ? 1
                : intervals[intervals.count / 2]
            let tolerance = min(1, max(0.05, cadence / 2))
            guard elapsed >= minimum - tolerance,
                  elapsed <= maximum + tolerance else {
                return nil
            }
            return eligible.min {
                let lhsDistance = abs($0.elapsed - elapsed)
                let rhsDistance = abs($1.elapsed - elapsed)
                if lhsDistance == rhsDistance {
                    return $0.sample.capturedAt < $1.sample.capturedAt
                }
                return lhsDistance < rhsDistance
            }
        }
        .sorted {
            if $0.application.displayName != $1.application.displayName {
                return $0.application.displayName.localizedStandardCompare(
                    $1.application.displayName
                ) == .orderedAscending
            }
            return $0.round.sequenceNumber < $1.round.sequenceNumber
        }
    }

    private func sampleSort(
        _ lhs: ResultTimelineSample,
        _ rhs: ResultTimelineSample
    ) -> Bool {
        if lhs.elapsed != rhs.elapsed {
            return lhs.elapsed < rhs.elapsed
        }
        return lhs.sample.capturedAt < rhs.sample.capturedAt
    }

    private struct SelectionKey: Hashable {
        let application: ApplicationIdentity
        let roundID: UUID
    }
}

public enum HistoricalResultScope: Equatable, Hashable, Sendable {
    case combined
    case round(id: UUID, number: Int)

    public var title: String {
        switch self {
        case .combined:
            "Combined rounds"
        case .round(_, let number):
            "Round \(number)"
        }
    }
}

public struct HistoricalApplicationResult: Equatable, Identifiable, Sendable {
    public struct ID: Equatable, Hashable, Sendable {
        public let sessionID: UUID
        public let application: ApplicationIdentity
        public let scope: HistoricalResultScope

        public init(
            sessionID: UUID,
            application: ApplicationIdentity,
            scope: HistoricalResultScope
        ) {
            self.sessionID = sessionID
            self.application = application
            self.scope = scope
        }
    }

    public var id: ID {
        ID(
            sessionID: session.id,
            application: application.identity,
            scope: scope
        )
    }

    public let session: MonitoringSession
    public let application: SessionApplication
    public let scope: HistoricalResultScope
    public let summary: ApplicationResultSummary
    public let result: ControlledTestResult

    public init(
        session: MonitoringSession,
        application: SessionApplication,
        scope: HistoricalResultScope,
        summary: ApplicationResultSummary,
        result: ControlledTestResult
    ) {
        self.session = session
        self.application = application
        self.scope = scope
        self.summary = summary
        self.result = result
    }

    public var diskReadBytesPerSecond: Double? {
        normalized(summary.diskReadBytes)
    }

    public var diskWriteBytesPerSecond: Double? {
        normalized(summary.diskWriteBytes)
    }

    private func normalized(_ total: Double?) -> Double? {
        guard let total, summary.measuredDuration > 0 else { return nil }
        return total / summary.measuredDuration
    }
}

public struct HistoryLibrary: Equatable, Sendable {
    public let tests: [ControlledTestResult]
    public let results: [HistoricalApplicationResult]

    public init(tests: [ControlledTestResult]) {
        let eligibleTests = tests
            .filter {
                $0.session.kind == .controlledTest
                    && [.completed, .cancelled].contains($0.session.status)
            }
            .sorted { $0.session.createdAt > $1.session.createdAt }
        self.tests = eligibleTests

        let calculator = SessionSummaryCalculator()
        results = eligibleTests.flatMap { test in
            test.summaries.flatMap { summary in
                let application = summary.application
                let applicationRounds = test.rounds.filter {
                    $0.application.identity == application.identity
                }
                let applicationSamples = test.samples.filter {
                    $0.application == application.identity
                }
                let combinedResult = ControlledTestResult(
                    session: test.session,
                    rounds: applicationRounds,
                    samples: applicationSamples,
                    summaries: [summary]
                )
                var applicationResults = [
                    HistoricalApplicationResult(
                        session: test.session,
                        application: application,
                        scope: .combined,
                        summary: summary,
                        result: combinedResult
                    )
                ]

                let completedRounds = applicationRounds
                    .filter { $0.status == .completed }
                    .sorted { $0.roundNumber < $1.roundNumber }
                if completedRounds.count > 1 {
                    applicationResults += completedRounds.compactMap { round in
                        let roundSamples = applicationSamples.filter {
                            $0.roundID == round.id
                        }
                        guard let roundSummary = calculator.summarize(
                            session: test.session,
                            rounds: [round],
                            samples: roundSamples
                        ).first(where: {
                            $0.application.identity == application.identity
                        }) else {
                            return nil
                        }
                        return HistoricalApplicationResult(
                            session: test.session,
                            application: application,
                            scope: .round(id: round.id, number: round.roundNumber),
                            summary: roundSummary,
                            result: ControlledTestResult(
                                session: test.session,
                                rounds: [round],
                                samples: roundSamples,
                                summaries: [roundSummary]
                            )
                        )
                    }
                }
                return applicationResults
            }
        }
    }

    public func results(matching query: String) -> [HistoricalApplicationResult] {
        let terms = query
            .lowercased()
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        guard !terms.isEmpty else { return results }

        return results.filter { result in
            let mode =
                result.session.controlledTestMode == .automaticForegroundIdle
                    ? "automatic foreground idle"
                    : "manual guided"
            let searchable = [
                result.application.displayName,
                result.application.version ?? "",
                result.session.name,
                result.session.note,
                result.scope.title,
                mode,
                String(Int(result.summary.measuredDuration)),
                result.session.createdAt.ISO8601Format()
            ]
            .joined(separator: " ")
            .lowercased()
            return terms.allSatisfy(searchable.contains)
        }
    }
}

public struct HistoricalComparison: Equatable, Sendable {
    public let results: [HistoricalApplicationResult]

    public init(results: [HistoricalApplicationResult]) {
        self.results = Array(results.prefix(4))
    }

    public var isValid: Bool {
        (2...4).contains(results.count)
    }

    public var contextWarnings: [String] {
        var warnings: [String] = []
        let resultsByApplication = Dictionary(
            grouping: results,
            by: \.application.identity
        )
        if resultsByApplication.values.contains(where: {
            Set($0.map { $0.application.version ?? "Unknown" }).count > 1
        }) {
            warnings.append("Application versions differ.")
        }
        if Set(results.map { roundedDuration($0.summary.measuredDuration) }).count > 1 {
            warnings.append(
                "Measured durations differ; totals are paired with per-second rates."
            )
        }
        if Set(results.compactMap(\.session.controlledTestMode)).count > 1 {
            warnings.append("Controlled-test modes differ.")
        }
        if Set(results.map { normalizedNote($0.session.note) }).count > 1 {
            warnings.append("Workload notes differ.")
        }
        if Set(results.map(\.session.systemVersion)).count > 1 {
            warnings.append("macOS versions differ.")
        }
        return warnings
    }

    private func roundedDuration(_ duration: TimeInterval) -> Int {
        Int(duration.rounded())
    }

    private func normalizedNote(_ note: String) -> String {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "No workload note" : trimmed
    }
}

public struct ControlledTestEngineState: Equatable, Sendable {
    public let session: MonitoringSession?
    public let rounds: [SessionRound]
    public let summaries: [ApplicationResultSummary]
    public let currentRound: SessionRound?
    public let remainingDuration: TimeInterval?
    public let recoveryRequired: Bool
    public let notice: String?

    public init(
        session: MonitoringSession?,
        rounds: [SessionRound],
        summaries: [ApplicationResultSummary],
        currentRound: SessionRound?,
        remainingDuration: TimeInterval?,
        recoveryRequired: Bool,
        notice: String?
    ) {
        self.session = session
        self.rounds = rounds
        self.summaries = summaries
        self.currentRound = currentRound
        self.remainingDuration = remainingDuration
        self.recoveryRequired = recoveryRequired
        self.notice = notice
    }
}

public enum ControlledTestEngineError: Error, Equatable, LocalizedError {
    case invalidApplicationCount
    case invalidConfiguration
    case activeControlledTest
    case noSession
    case recoveryDecisionRequired
    case roundAlreadyRunning
    case noRoundAvailable
    case wrongControlledTestMode
    case activationServiceUnavailable

    public var errorDescription: String? {
        switch self {
        case .invalidApplicationCount:
            "Select between one and four applications."
        case .invalidConfiguration:
            "Choose a positive duration and at least one round."
        case .activeControlledTest:
            "Another controlled test is already active."
        case .noSession:
            "There is no controlled test to update."
        case .recoveryDecisionRequired:
            "Continue or discard the recovered test first."
        case .roundAlreadyRunning:
            "The current round is already recording."
        case .noRoundAvailable:
            "There is no pending round."
        case .wrongControlledTestMode:
            "That action is not available for this controlled-test mode."
        case .activationServiceUnavailable:
            "Automatic foreground activation is unavailable."
        }
    }
}

public struct SessionSummaryCalculator: Sendable {
    public init() {}

    public func summarize(
        session: MonitoringSession,
        rounds: [SessionRound],
        samples: [SessionMetricSample]
    ) -> [ApplicationResultSummary] {
        session.applications.compactMap { application in
            let completedRounds = rounds.filter {
                $0.application.identity == application.identity
                    && $0.status == .completed
            }
            let completedRoundIDs = Set(completedRounds.map(\.id))
            let measured = samples
                .filter {
                    $0.application == application.identity
                        && completedRoundIDs.contains($0.roundID)
                        && !$0.isWarmUp
                }
                .sorted { $0.capturedAt < $1.capturedAt }
            guard !completedRounds.isEmpty else { return nil }

            return ApplicationResultSummary(
                sessionID: session.id,
                application: application,
                completedRoundCount: completedRounds.count,
                measuredDuration: measuredDuration(
                    rounds: completedRounds,
                    configuration: session.controlledTestConfiguration
                ),
                sampleCount: measured.count,
                averageCPUCoreUsage: average(measured.compactMap(\.metrics.cpuCoreUsage)),
                peakCPUCoreUsage: measured.compactMap(\.metrics.cpuCoreUsage).max(),
                averageMemoryBytes: average(
                    measured.compactMap {
                        $0.metrics.physicalMemoryBytes.map { Double($0) }
                    }
                ),
                peakMemoryBytes: measured.compactMap(\.metrics.physicalMemoryBytes).max(),
                diskReadBytes: totalRate(
                    measured,
                    value: \.metrics.diskReadBytesPerSecond
                ),
                diskWriteBytes: totalRate(
                    measured,
                    value: \.metrics.diskWriteBytesPerSecond
                ),
                averageWakeupsPerSecond: average(
                    measured.compactMap(\.metrics.wakeupsPerSecond)
                ),
                peakProcessCount: measured.map(\.metrics.processCount).max(),
                peakThreadCount: measured.compactMap(\.metrics.threadCount).max()
            )
        }
    }

    private func measuredDuration(
        rounds: [SessionRound],
        configuration: ControlledTestConfiguration?
    ) -> TimeInterval {
        if let configuration {
            return configuration.measuredDuration * Double(rounds.count)
        }
        return rounds.reduce(0) { result, round in
            guard let start = round.measuredAt, let end = round.endedAt else {
                return result
            }
            return result + max(0, end.timeIntervalSince(start))
        }
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    private func totalRate(
        _ samples: [SessionMetricSample],
        value: KeyPath<SessionMetricSample, Double?>
    ) -> Double? {
        let rounds = Dictionary(grouping: samples, by: \.roundID)
        var foundValue = false
        let total = rounds.values.reduce(0) { roundTotal, roundSamples in
            let values = roundSamples
                .sorted { $0.elapsed < $1.elapsed }
                .compactMap { sample in
                    sample[keyPath: value].map { ($0, sample) }
                }
            guard !values.isEmpty else { return roundTotal }
            foundValue = true
            let valueTotal = values.enumerated().reduce(0) { total, pair in
                let index = pair.offset
                let rate = pair.element.0
                let sample = pair.element.1
                let interval: TimeInterval
                if index == 0 {
                    interval = 1
                } else {
                    let previous = values[index - 1].1
                    interval = min(max(sample.elapsed - previous.elapsed, 0), 2)
                }
                return total + rate * interval
            }
            return roundTotal + valueTotal
        }
        return foundValue ? total : nil
    }
}

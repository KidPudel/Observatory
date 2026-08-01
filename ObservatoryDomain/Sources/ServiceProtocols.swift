import Foundation

public protocol ObservatoryClock: Sendable {
    var now: Date { get async }
    var monotonicNow: Duration { get async }
    func sleep(for duration: Duration) async throws
}

public protocol ApplicationDiscovering: Sendable {
    func runningApplications() async -> [DiscoveredApplication]
}

public protocol ProcessSampling: Sendable {
    func sample(processes: [ProcessIdentity], at date: Date) async -> [ProcessSample]
    func resetBaselines(for processes: [ProcessIdentity]) async
}

public extension ProcessSampling {
    func resetBaselines(for processes: [ProcessIdentity]) async {
        _ = processes
    }
}

public protocol ProcessInventorying: Sendable {
    func runningProcessIdentities() async -> [ProcessIdentity]
}

public protocol ProcessDiscovering: Sendable {
    func runningProcesses() async -> [DiscoveredProcess]
}

public protocol GroupingRulePersisting: Sendable {
    func saveGroupingRule(_ rule: GroupingRule) async throws
    func groupingRules() async throws -> [GroupingRule]
    func deleteGroupingRule(id: UUID) async throws
    func resetGroupingRules(for application: ApplicationIdentity?) async throws
}

public protocol ApplicationActivating: Sendable {
    func activate(_ application: ApplicationIdentity) async throws
    func isFrontmost(_ application: ApplicationIdentity) async -> Bool
}

public protocol ScreenCapturing: Sendable {
    func captureWindow(for request: CaptureRequest) async throws -> CapturedAsset
}

public protocol RedactedInputActivityProviding: Sendable {
    func activities() async -> AsyncStream<RedactedInputActivity>
    func stop() async
}

public protocol StorageRootAccessing: Sendable {
    func sessionDirectory(named name: String, createdAt: Date) async throws -> URL
    func writeSummary(_ result: ControlledTestResult, to directory: URL) async throws
    func removeSessionDirectory(_ directory: URL) async throws
}

public protocol SessionMetricSampling: Sendable {
    func prepareForRound(
        application: ApplicationIdentity,
        sessionID: UUID,
        at date: Date
    ) async
    func readings(
        for applications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading]
}

public extension SessionMetricSampling {
    func prepareForRound(
        application: ApplicationIdentity,
        sessionID: UUID,
        at date: Date
    ) async {
        _ = application
        _ = sessionID
        _ = date
    }
}

public protocol SessionPersisting: Sendable {
    func createSession(
        _ session: MonitoringSession,
        rounds: [SessionRound]
    ) async throws
    func saveSession(_ session: MonitoringSession) async throws
    func session(id: UUID) async throws -> MonitoringSession?
    func sessions() async throws -> [MonitoringSession]
    func unfinishedControlledSession() async throws -> MonitoringSession?
    func saveRound(_ round: SessionRound) async throws
    func rounds(sessionID: UUID) async throws -> [SessionRound]
    func saveSample(_ sample: SessionMetricSample) async throws
    func samples(sessionID: UUID) async throws -> [SessionMetricSample]
    func replaceSummaries(
        _ summaries: [ApplicationResultSummary],
        sessionID: UUID
    ) async throws
    func summaries(sessionID: UUID) async throws -> [ApplicationResultSummary]
    func deleteSamples(roundID: UUID) async throws
    func deleteSession(id: UUID) async throws
}

public extension SessionPersisting {
    func createSession(
        _ session: MonitoringSession,
        rounds: [SessionRound]
    ) async throws {
        if try await unfinishedControlledSession() != nil {
            throw ControlledTestEngineError.activeControlledTest
        }
        try await saveSession(session)
        for round in rounds {
            try await saveRound(round)
        }
    }
}

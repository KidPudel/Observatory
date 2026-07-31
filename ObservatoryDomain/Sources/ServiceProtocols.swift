import Foundation

public protocol ObservatoryClock: Sendable {
    var now: Date { get async }
    func sleep(for duration: Duration) async throws
}

public protocol ApplicationDiscovering: Sendable {
    func runningApplications() async -> [DiscoveredApplication]
}

public protocol ProcessSampling: Sendable {
    func sample(processes: [ProcessIdentity], at date: Date) async -> [ProcessSample]
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
    func readings(
        for applications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading]
}

public protocol SessionPersisting: Sendable {
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

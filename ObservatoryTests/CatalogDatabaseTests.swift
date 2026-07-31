import Foundation
import Testing
@testable import ObservatoryDomain
import ObservatoryPersistence

struct CatalogDatabaseTests {
    @Test
    func firstMigrationCreatesCatalogAndRoundTripsSession() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let session = MonitoringSession(
            id: UUID(uuidString: "6A67E44A-03B0-4B56-A571-0478D1BC7F36")!,
            name: "Browser idle",
            kind: .backgroundObservation,
            status: .completed,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        try await database.saveSession(session)

        let restored = try await database.session(id: session.id)
        let migrations = try await database.appliedMigrations()
        #expect(restored == session)
        #expect(
            migrations
                == [
                    "v1_create_session_catalog",
                    "v2_create_grouping_rule_catalog",
                    "v3_create_manual_session_records"
                ]
        )
    }

    @Test
    func sessionsAreReturnedNewestFirst() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let older = MonitoringSession(
            name: "Older",
            kind: .controlledTest,
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let newer = MonitoringSession(
            name: "Newer",
            kind: .controlledTest,
            createdAt: Date(timeIntervalSince1970: 200)
        )

        try await database.saveSession(older)
        try await database.saveSession(newer)

        let sessions = try await database.sessions()
        #expect(sessions.map(\.name) == ["Newer", "Older"])
    }

    @Test
    func groupingRulesRoundTripDeleteAndReset() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let firstApplication = ApplicationIdentity(
            bundleIdentifier: "test.first",
            bundleURL: URL(fileURLWithPath: "/Applications/First.app")
        )
        let secondApplication = ApplicationIdentity(
            bundleIdentifier: "test.second",
            bundleURL: URL(fileURLWithPath: "/Applications/Second.app")
        )
        let firstRule = GroupingRule(
            id: UUID(uuidString: "D16A47AA-D687-45C2-858B-F62F44EF3BF5")!,
            application: firstApplication,
            matcher: .executablePath("/opt/first-helper"),
            action: .include
        )
        let secondRule = GroupingRule(
            id: UUID(uuidString: "35913A2A-B6BF-466B-BE16-62CAFA750829")!,
            application: secondApplication,
            matcher: .bundleIdentifier("test.second.helper"),
            action: .exclude
        )

        try await database.saveGroupingRule(firstRule)
        try await database.saveGroupingRule(secondRule)
        let savedRuleIDs = Set(try await database.groupingRules().map(\.id))
        #expect(savedRuleIDs == [firstRule.id, secondRule.id])

        try await database.deleteGroupingRule(id: firstRule.id)
        #expect(try await database.groupingRules() == [secondRule])

        try await database.saveGroupingRule(firstRule)
        try await database.resetGroupingRules(for: firstApplication)
        #expect(try await database.groupingRules() == [secondRule])

        try await database.resetGroupingRules(for: nil)
        #expect(try await database.groupingRules().isEmpty)
    }

    @Test
    func manualRoundSamplesAndSummariesRoundTripAndDeleteTogether() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let application = SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: "test.editor",
                bundleURL: URL(fileURLWithPath: "/Applications/Editor.app")
            ),
            displayName: "Editor",
            version: "1.2"
        )
        let session = MonitoringSession(
            name: "Search",
            kind: .controlledTest,
            status: .paused,
            controlledTestMode: .manualGuided,
            manualConfiguration: ControlledTestConfiguration(
                measuredDuration: 10,
                warmUpDuration: 2,
                roundCount: 1
            ),
            applications: [application],
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let round = SessionRound(
            sessionID: session.id,
            application: application,
            roundNumber: 1,
            sequenceNumber: 1,
            status: .completed
        )
        let metrics = GroupedProcessMetrics(
            cpuCoreUsage: 1.5,
            physicalMemoryBytes: 256,
            diskReadBytesPerSecond: 20,
            diskWriteBytesPerSecond: 30,
            wakeupsPerSecond: 4,
            processCount: 2,
            threadCount: 8,
            unavailableProcessCount: 0
        )
        let sample = SessionMetricSample(
            sessionID: session.id,
            roundID: round.id,
            application: application.identity,
            capturedAt: Date(timeIntervalSince1970: 1_003),
            elapsed: 1,
            isWarmUp: false,
            state: .frontmost,
            metrics: metrics,
            isPartial: false
        )
        let summary = ApplicationResultSummary(
            sessionID: session.id,
            application: application,
            completedRoundCount: 1,
            measuredDuration: 10,
            sampleCount: 1,
            averageCPUCoreUsage: 1.5,
            peakCPUCoreUsage: 1.5,
            averageMemoryBytes: 256,
            peakMemoryBytes: 256,
            diskReadBytes: 20,
            diskWriteBytes: 30,
            averageWakeupsPerSecond: 4,
            peakProcessCount: 2,
            peakThreadCount: 8
        )

        try await database.saveSession(session)
        try await database.saveRound(round)
        try await database.saveSample(sample)
        try await database.replaceSummaries([summary], sessionID: session.id)

        #expect(try await database.rounds(sessionID: session.id) == [round])
        #expect(try await database.samples(sessionID: session.id) == [sample])
        #expect(try await database.summaries(sessionID: session.id) == [summary])
        #expect(try await database.unfinishedControlledSession()?.id == session.id)

        try await database.deleteSession(id: session.id)
        #expect(try await database.session(id: session.id) == nil)
        #expect(try await database.rounds(sessionID: session.id).isEmpty)
        #expect(try await database.samples(sessionID: session.id).isEmpty)
        #expect(try await database.summaries(sessionID: session.id).isEmpty)
    }
}

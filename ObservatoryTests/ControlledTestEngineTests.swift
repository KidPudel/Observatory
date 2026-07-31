import Foundation
import Testing
@testable import ObservatoryDomain
import ObservatoryPersistence

struct ControlledTestEngineTests {
    @Test
    func samplingWorkDoesNotAccumulateIntoCadenceDrift() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(
            date: Date(timeIntervalSince1970: 9_000)
        )
        let application = fixtureApplication()
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: WorkAdvancingSessionSampler(
                application: application.identity,
                clock: clock,
                workDuration: 0.1
            ),
            storage: TestSessionStorage(),
            clock: clock
        )
        _ = try await engine.createSession(
            name: "Fixed cadence",
            note: "",
            applications: [application],
            configuration: ControlledTestConfiguration(
                measuredDuration: 3,
                warmUpDuration: 0,
                roundCount: 1
            )
        )

        try await engine.startNextRound()
        try await waitForStatus(.completed, engine: engine)

        let state = await engine.state()
        let result = try #require(
            try await engine.result(sessionID: state.session!.id)
        )
        let elapsed = result.samples.map(\.elapsed)
        #expect(elapsed.count == 3)
        #expect(zip(elapsed, [0.0, 1.0, 2.0]).allSatisfy {
            abs($0.0 - $0.1) < 0.000_001
        })
    }

    @Test
    func warmUpIsExcludedAndCompletedRoundsCombine() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(
            date: Date(timeIntervalSince1970: 10_000)
        )
        let application = fixtureApplication()
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: FixedSessionSampler(application: application.identity),
            storage: TestSessionStorage(),
            clock: clock
        )
        _ = try await engine.createSession(
            name: "Two rounds",
            note: "Search the same project",
            applications: [application],
            configuration: ControlledTestConfiguration(
                measuredDuration: 3,
                warmUpDuration: 2,
                roundCount: 2
            )
        )

        try await engine.startNextRound()
        try await waitForStatus(.paused, engine: engine)
        try await engine.startNextRound()
        try await waitForStatus(.completed, engine: engine)

        let state = await engine.state()
        let summary = try #require(state.summaries.first)
        #expect(state.rounds.map(\.status) == [.completed, .completed])
        #expect(summary.completedRoundCount == 2)
        #expect(summary.sampleCount == 6)
        #expect(summary.measuredDuration == 6)
        #expect(summary.averageCPUCoreUsage == 1.25)
        #expect(summary.averageMemoryBytes == Double(512 * 1_024 * 1_024))
        #expect(summary.peakMemoryBytes == 512 * 1_024 * 1_024)
        #expect(summary.diskWriteBytes == 18_000)

        let result = try #require(
            try await engine.result(sessionID: state.session!.id)
        )
        #expect(result.samples.count == 10)
        #expect(result.samples.filter(\.isWarmUp).count == 4)
    }

    @Test
    func secondEngineCannotCreateAControlledTestWhileOneIsUnfinished() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(date: Date(timeIntervalSince1970: 100))
        let application = fixtureApplication()
        let first = makeEngine(
            database: database,
            clock: clock,
            application: application
        )
        let second = makeEngine(
            database: database,
            clock: clock,
            application: application
        )

        _ = try await first.createSession(
            name: "First",
            note: "",
            applications: [application],
            configuration: ControlledTestConfiguration(
                measuredDuration: 10,
                warmUpDuration: 0,
                roundCount: 1
            )
        )

        await #expect(throws: ControlledTestEngineError.activeControlledTest) {
            _ = try await second.createSession(
                name: "Second",
                note: "",
                applications: [application],
                configuration: ControlledTestConfiguration(
                    measuredDuration: 10,
                    warmUpDuration: 0,
                    roundCount: 1
                )
            )
        }
    }

    @Test
    func relaunchMarksAnActiveRoundInterruptedAndOffersRecovery() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let application = fixtureApplication()
        let date = Date(timeIntervalSince1970: 500)
        let configuration = ControlledTestConfiguration(
            measuredDuration: 30,
            warmUpDuration: 5,
            roundCount: 1
        )
        let session = MonitoringSession(
            name: "Interrupted",
            kind: .controlledTest,
            status: .recording,
            controlledTestMode: .manualGuided,
            manualConfiguration: configuration,
            applications: [application],
            createdAt: date,
            startedAt: date
        )
        let round = SessionRound(
            sessionID: session.id,
            application: application,
            roundNumber: 1,
            sequenceNumber: 1,
            status: .recording,
            startedAt: date,
            measuredAt: date
        )
        try await database.saveSession(session)
        try await database.saveRound(round)

        let engine = makeEngine(
            database: database,
            clock: AdvancingTestClock(date: date.addingTimeInterval(10)),
            application: application
        )
        try await engine.restoreUnfinishedSession()

        let recovered = await engine.state()
        #expect(recovered.recoveryRequired)
        #expect(recovered.session?.status == .paused)
        #expect(recovered.rounds.first?.status == .interrupted)
        #expect(
            recovered.rounds.first?.interruptionReason
                == "Observatory quit before this round finished."
        )
    }

    @Test
    func discardedSessionRemovesCatalogRecordsAndAssets() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(date: Date(timeIntervalSince1970: 800))
        let storage = TestSessionStorage()
        let application = fixtureApplication()
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: FixedSessionSampler(application: application.identity),
            storage: storage,
            clock: clock
        )
        let session = try await engine.createSession(
            name: "Discard me",
            note: "",
            applications: [application],
            configuration: ControlledTestConfiguration(
                measuredDuration: 10,
                warmUpDuration: 0,
                roundCount: 1
            )
        )

        try await engine.cancel(preservingPartialResult: false)

        #expect(try await database.session(id: session.id) == nil)
        #expect(await engine.state().session == nil)
        #expect(await storage.removedDirectoryCount == 1)
    }

    @Test
    func deletingSavedTestRemovesItsFolderAndPreservesUnrelatedTest() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let storage = TestSessionStorage()
        let application = fixtureApplication()
        let deleted = MonitoringSession(
            name: "Delete",
            kind: .controlledTest,
            status: .completed,
            controlledTestMode: .manualGuided,
            manualConfiguration: ControlledTestConfiguration(
                measuredDuration: 10,
                warmUpDuration: 0,
                roundCount: 1
            ),
            applications: [application],
            assetDirectoryPath: "/tmp/ObservatoryTests/Delete",
            createdAt: Date(timeIntervalSince1970: 1_000),
            completedAt: Date(timeIntervalSince1970: 1_010)
        )
        let preserved = MonitoringSession(
            name: "Keep",
            kind: .controlledTest,
            status: .completed,
            controlledTestMode: .manualGuided,
            manualConfiguration: ControlledTestConfiguration(
                measuredDuration: 10,
                warmUpDuration: 0,
                roundCount: 1
            ),
            applications: [application],
            assetDirectoryPath: "/tmp/ObservatoryTests/Keep",
            createdAt: Date(timeIntervalSince1970: 2_000),
            completedAt: Date(timeIntervalSince1970: 2_010)
        )
        try await database.saveSession(deleted)
        try await database.saveSession(preserved)
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: FixedSessionSampler(application: application.identity),
            storage: storage,
            clock: AdvancingTestClock(date: Date(timeIntervalSince1970: 3_000))
        )

        try await engine.deleteSavedSession(id: deleted.id)

        #expect(try await database.session(id: deleted.id) == nil)
        #expect(try await database.session(id: preserved.id) == preserved)
        #expect(await storage.removedDirectoryCount == 1)
    }

    @Test
    func automaticForegroundIdleRotatesApplicationsForEqualMeasuredTime() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(date: Date(timeIntervalSince1970: 1_000))
        let editor = fixtureApplication()
        let browser = SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: "test.browser",
                bundleURL: URL(fileURLWithPath: "/Applications/Browser.app")
            ),
            displayName: "Browser",
            version: "2.0"
        )
        let activation = TestApplicationActivation()
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: MultiSessionSampler(
                applications: [editor.identity, browser.identity]
            ),
            storage: TestSessionStorage(),
            clock: clock,
            activation: activation
        )
        _ = try await engine.createSession(
            name: "Idle rotation",
            note: "",
            applications: [editor, browser],
            configuration: ControlledTestConfiguration(
                measuredDuration: 3,
                warmUpDuration: 1,
                roundCount: 2
            ),
            mode: .automaticForegroundIdle
        )

        try await engine.startAutomaticSequence()
        try await waitForStatus(.completed, engine: engine)

        let state = await engine.state()
        #expect(state.rounds.map(\.status) == [
            .completed, .completed, .completed, .completed
        ])
        #expect(state.summaries.map(\.measuredDuration) == [6, 6])
        #expect(state.summaries.map(\.sampleCount) == [6, 6])
        #expect(await activation.activationOrder == [
            editor.identity,
            browser.identity,
            editor.identity,
            browser.identity
        ])
        #expect(state.session?.controlledTestMode == .automaticForegroundIdle)
    }

    @Test
    func automaticActivationFailureIsBoundedAndDoesNotStopLaterRounds() async throws {
        let database = try CatalogDatabase(inMemory: true)
        let clock = AdvancingTestClock(date: Date(timeIntervalSince1970: 2_000))
        let unavailable = fixtureApplication()
        let available = SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: "test.available",
                bundleURL: URL(fileURLWithPath: "/Applications/Available.app")
            ),
            displayName: "Available",
            version: nil
        )
        let activation = TestApplicationActivation(
            applicationsThatNeverBecomeFrontmost: [unavailable.identity]
        )
        let engine = ControlledTestEngine(
            persistence: database,
            sampler: MultiSessionSampler(
                applications: [unavailable.identity, available.identity]
            ),
            storage: TestSessionStorage(),
            clock: clock,
            activation: activation
        )
        _ = try await engine.createSession(
            name: "Failure handling",
            note: "",
            applications: [unavailable, available],
            configuration: ControlledTestConfiguration(
                measuredDuration: 2,
                warmUpDuration: 0,
                roundCount: 1
            ),
            mode: .automaticForegroundIdle
        )

        try await engine.startAutomaticSequence()
        try await waitForStatus(.completed, engine: engine)

        let state = await engine.state()
        #expect(state.rounds.map(\.status) == [.failed, .completed])
        #expect(
            state.rounds.first?.interruptionReason?
                .contains("after 3 attempts") == true
        )
        #expect(await activation.attemptCount(for: unavailable.identity) == 3)
        #expect(state.summaries.map(\.application.identity) == [available.identity])
    }

    private func fixtureApplication() -> SessionApplication {
        SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: "test.editor",
                bundleURL: URL(fileURLWithPath: "/Applications/Editor.app")
            ),
            displayName: "Editor",
            version: "1.0"
        )
    }

    private func makeEngine(
        database: CatalogDatabase,
        clock: AdvancingTestClock,
        application: SessionApplication
    ) -> ControlledTestEngine {
        ControlledTestEngine(
            persistence: database,
            sampler: FixedSessionSampler(application: application.identity),
            storage: TestSessionStorage(),
            clock: clock
        )
    }

    private func waitForStatus(
        _ status: MonitoringSessionStatus,
        engine: ControlledTestEngine
    ) async throws {
        for _ in 0..<400 {
            if await engine.state().session?.status == status {
                return
            }
            try await Task.sleep(for: .milliseconds(2))
        }
        Issue.record("Session did not reach \(status.rawValue)")
        throw TestTimeout()
    }
}

private struct TestTimeout: Error {}

private actor AdvancingTestClock: ObservatoryClock {
    private var date: Date

    init(date: Date) {
        self.date = date
    }

    var now: Date {
        get async { date }
    }

    func sleep(for duration: Duration) async throws {
        try Task.checkCancellation()
        advance(by: duration)
        await Task.yield()
    }

    func advance(by duration: Duration) {
        let components = duration.components
        let seconds = Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
        date = date.addingTimeInterval(seconds)
    }
}

private struct FixedSessionSampler: SessionMetricSampling {
    let application: ApplicationIdentity

    func readings(
        for applications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading] {
        guard applications.contains(application) else { return [] }
        return [
            ApplicationMetricReading(
                application: application,
                capturedAt: date,
                state: .frontmost,
                metrics: GroupedProcessMetrics(
                    cpuCoreUsage: 1.25,
                    physicalMemoryBytes: 512 * 1_024 * 1_024,
                    diskReadBytesPerSecond: 2_000,
                    diskWriteBytesPerSecond: 3_000,
                    wakeupsPerSecond: 5,
                    processCount: 3,
                    threadCount: 12,
                    unavailableProcessCount: 0
                ),
                isPartial: false
            )
        ]
    }
}

private struct WorkAdvancingSessionSampler: SessionMetricSampling {
    let application: ApplicationIdentity
    let clock: AdvancingTestClock
    let workDuration: TimeInterval

    func readings(
        for applications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading] {
        guard applications.contains(application) else { return [] }
        await clock.advance(by: .seconds(workDuration))
        return await FixedSessionSampler(application: application).readings(
            for: applications,
            sessionID: sessionID,
            at: date
        )
    }
}

private struct MultiSessionSampler: SessionMetricSampling {
    let applications: Set<ApplicationIdentity>

    init(applications: [ApplicationIdentity]) {
        self.applications = Set(applications)
    }

    func readings(
        for requestedApplications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading] {
        requestedApplications.compactMap { application in
            guard applications.contains(application) else { return nil }
            return ApplicationMetricReading(
                application: application,
                capturedAt: date,
                state: .frontmost,
                metrics: GroupedProcessMetrics(
                    cpuCoreUsage: 0.5,
                    physicalMemoryBytes: 256 * 1_024 * 1_024,
                    diskReadBytesPerSecond: 100,
                    diskWriteBytesPerSecond: 200,
                    wakeupsPerSecond: 2,
                    processCount: 1,
                    threadCount: 4,
                    unavailableProcessCount: 0
                ),
                isPartial: false
            )
        }
    }
}

private actor TestApplicationActivation: ApplicationActivating {
    private let applicationsThatNeverBecomeFrontmost: Set<ApplicationIdentity>
    private var frontmostApplication: ApplicationIdentity?
    private var attempts: [ApplicationIdentity: Int] = [:]
    private(set) var activationOrder: [ApplicationIdentity] = []

    init(
        applicationsThatNeverBecomeFrontmost: Set<ApplicationIdentity> = []
    ) {
        self.applicationsThatNeverBecomeFrontmost =
            applicationsThatNeverBecomeFrontmost
    }

    func activate(_ application: ApplicationIdentity) {
        attempts[application, default: 0] += 1
        activationOrder.append(application)
        if !applicationsThatNeverBecomeFrontmost.contains(application) {
            frontmostApplication = application
        }
    }

    func isFrontmost(_ application: ApplicationIdentity) -> Bool {
        frontmostApplication == application
    }

    func attemptCount(for application: ApplicationIdentity) -> Int {
        attempts[application, default: 0]
    }
}

private actor TestSessionStorage: StorageRootAccessing {
    private(set) var removedDirectoryCount = 0

    func sessionDirectory(named name: String, createdAt: Date) -> URL {
        URL(fileURLWithPath: "/tmp/ObservatoryTests/\(name)-\(createdAt.timeIntervalSince1970)")
    }

    func writeSummary(_ result: ControlledTestResult, to directory: URL) {}

    func removeSessionDirectory(_ directory: URL) {
        removedDirectoryCount += 1
    }
}

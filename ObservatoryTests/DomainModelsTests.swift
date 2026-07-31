import Foundation
import Testing
@testable import ObservatoryDomain

struct DomainModelsTests {
    @Test
    func processIdentityDistinguishesReusedProcessIdentifiers() {
        let first = ProcessIdentity(
            processIdentifier: 42,
            startTime: Date(timeIntervalSince1970: 100)
        )
        let reused = ProcessIdentity(
            processIdentifier: 42,
            startTime: Date(timeIntervalSince1970: 200)
        )

        #expect(first != reused)
    }

    @Test
    func fixtureSessionDefaultsToPlannedMetricsOnlyTest() {
        let session = MonitoringSession(
            name: "Editor comparison",
            kind: .controlledTest,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )

        #expect(session.status == .planned)
        #expect(session.context == .metricsOnly)
    }

    @Test
    func resultTimelinePreservesMeasuredTimeAndSplitsUnavailableValues() throws {
        let fixture = timelineFixture()
        let originalSamples = fixture.samples
        let timeline = ResultTimeline(result: fixture)
        let application = try #require(fixture.session.applications.first)
        let cpuPoints = timeline.points(
            for: application.identity,
            metric: .cpu
        )

        #expect(timeline.samples.map(\.elapsed) == [-1, 0, 1, 2])
        #expect(cpuPoints.map(\.value) == [50, 100, 200])
        #expect(cpuPoints.map(\.segment) == [0, 1, 2])
        #expect(timeline.samples.first?.value(for: .memory) == 1_024)
        #expect(fixture.samples == originalSamples)
    }

    @Test
    func resultTimelineSelectsExactSamplesAndKeepsDiskDirections() throws {
        let fixture = timelineFixture()
        let timeline = ResultTimeline(result: fixture)
        let application = try #require(fixture.session.applications.first)
        let diskPoints = timeline.points(
            for: application.identity,
            metric: .disk
        )
        let selected = timeline.nearestSamples(to: 1)

        #expect(
            diskPoints.filter { $0.component == .diskRead }.map(\.value)
                == [10, 20, 30, 40]
        )
        #expect(
            diskPoints.filter { $0.component == .diskWrite }.map(\.value)
                == [20, 30, 40, 50]
        )
        #expect(selected.count == 1)
        #expect(selected.first?.elapsed == 1)
        #expect(
            selected.first?.sample.capturedAt
                == Date(timeIntervalSince1970: 101)
        )
        #expect(timeline.nearestSamples(to: 3).isEmpty)
    }

    @Test
    func historyLibraryBuildsCombinedAndPerRoundResultsWithoutChangingSamples()
        throws {
        let fixture = historyFixture(
            name: "Editor baseline",
            version: "1.0",
            duration: 3,
            note: "Index the workspace",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let originalSamples = fixture.samples

        let library = HistoryLibrary(tests: [fixture])

        #expect(library.tests.count == 1)
        #expect(library.results.count == 3)
        #expect(library.results.map(\.scope.title) == [
            "Combined rounds", "Round 1", "Round 2"
        ])
        #expect(library.results.first?.summary.measuredDuration == 6)
        #expect(library.results.dropFirst().map(\.summary.measuredDuration) == [3, 3])
        #expect(library.results(matching: "editor 1.0 baseline").count == 3)
        #expect(library.results(matching: "index workspace").count == 3)
        #expect(fixture.samples == originalSamples)
    }

    @Test
    func historicalComparisonDisclosesContextAndNormalizesDiskTotals() throws {
        let baseline = historyFixture(
            name: "Before update",
            version: "1.0",
            duration: 3,
            note: "Index the workspace",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let updated = historyFixture(
            name: "After update",
            version: "2.0",
            duration: 5,
            note: "Open the workspace",
            createdAt: Date(timeIntervalSince1970: 90_000)
        )
        let library = HistoryLibrary(tests: [baseline, updated])
        let combined = library.results.filter { $0.scope == .combined }
        let comparison = HistoricalComparison(results: combined)
        let first = try #require(combined.first)

        #expect(comparison.isValid)
        #expect(comparison.contextWarnings.contains("Application versions differ."))
        #expect(
            comparison.contextWarnings.contains(
                "Measured durations differ; totals are paired with per-second rates."
            )
        )
        #expect(comparison.contextWarnings.contains("Workload notes differ."))
        #expect(first.diskReadBytesPerSecond == 100)
        #expect(first.diskWriteBytesPerSecond == 200)
    }

    @Test
    func differentApplicationsDoNotProduceAnApplicationVersionWarning() {
        let editor = historyFixture(
            name: "Editor test",
            version: "1.0",
            duration: 3,
            note: "Idle",
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let browser = historyFixture(
            name: "Browser test",
            version: "99.0",
            duration: 3,
            note: "Idle",
            createdAt: Date(timeIntervalSince1970: 1_000),
            bundleIdentifier: "test.browser",
            bundlePath: "/Applications/Browser.app",
            displayName: "Browser"
        )
        let comparison = HistoricalComparison(
            results: HistoryLibrary(tests: [editor, browser]).results.filter {
                $0.scope == .combined
            }
        )

        #expect(comparison.isValid)
        #expect(
            !comparison.contextWarnings.contains("Application versions differ.")
        )
    }

    private func historyFixture(
        name: String,
        version: String,
        duration: TimeInterval,
        note: String,
        createdAt: Date,
        bundleIdentifier: String = "test.editor",
        bundlePath: String = "/Applications/Editor.app",
        displayName: String = "Editor"
    ) -> ControlledTestResult {
        let application = SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: bundleIdentifier,
                bundleURL: URL(fileURLWithPath: bundlePath)
            ),
            displayName: displayName,
            version: version
        )
        let session = MonitoringSession(
            name: name,
            kind: .controlledTest,
            status: .completed,
            note: note,
            controlledTestMode: .manualGuided,
            manualConfiguration: ControlledTestConfiguration(
                measuredDuration: duration,
                warmUpDuration: 1,
                roundCount: 2
            ),
            applications: [application],
            createdAt: createdAt,
            completedAt: createdAt.addingTimeInterval(duration * 2 + 2)
        )
        let rounds = (1...2).map { number in
            SessionRound(
                sessionID: session.id,
                application: application,
                roundNumber: number,
                sequenceNumber: number,
                status: .completed,
                startedAt: createdAt.addingTimeInterval(
                    Double(number - 1) * (duration + 1)
                ),
                measuredAt: createdAt.addingTimeInterval(
                    Double(number - 1) * (duration + 1) + 1
                ),
                endedAt: createdAt.addingTimeInterval(
                    Double(number) * (duration + 1)
                )
            )
        }
        let samples = rounds.flatMap { round in
            (0..<Int(duration)).map { second in
                SessionMetricSample(
                    sessionID: session.id,
                    roundID: round.id,
                    application: application.identity,
                    capturedAt: round.measuredAt!.addingTimeInterval(
                        Double(second)
                    ),
                    elapsed: Double(second),
                    isWarmUp: false,
                    state: .frontmost,
                    metrics: GroupedProcessMetrics(
                        cpuCoreUsage: 0.5,
                        physicalMemoryBytes: 1_024,
                        diskReadBytesPerSecond: 100,
                        diskWriteBytesPerSecond: 200,
                        wakeupsPerSecond: 2,
                        processCount: 1,
                        threadCount: 2,
                        unavailableProcessCount: 0
                    ),
                    isPartial: false
                )
            }
        }
        let summaries = SessionSummaryCalculator().summarize(
            session: session,
            rounds: rounds,
            samples: samples
        )
        return ControlledTestResult(
            session: session,
            rounds: rounds,
            samples: samples,
            summaries: summaries
        )
    }

    private func timelineFixture() -> ControlledTestResult {
        let application = SessionApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: "test.editor",
                bundleURL: URL(fileURLWithPath: "/Applications/Editor.app")
            ),
            displayName: "Editor",
            version: "1.0"
        )
        let session = MonitoringSession(
            name: "Timeline",
            kind: .controlledTest,
            status: .completed,
            controlledTestMode: .manualGuided,
            manualConfiguration: ControlledTestConfiguration(
                measuredDuration: 3,
                warmUpDuration: 1,
                roundCount: 1
            ),
            applications: [application],
            createdAt: Date(timeIntervalSince1970: 90)
        )
        let round = SessionRound(
            sessionID: session.id,
            application: application,
            roundNumber: 1,
            sequenceNumber: 1,
            status: .completed,
            startedAt: Date(timeIntervalSince1970: 99),
            measuredAt: Date(timeIntervalSince1970: 100),
            endedAt: Date(timeIntervalSince1970: 103)
        )
        let cpuValues: [Double?] = [0.5, 1, nil, 2]
        let samples = cpuValues.enumerated().map { index, cpu in
            SessionMetricSample(
                sessionID: session.id,
                roundID: round.id,
                application: application.identity,
                capturedAt: Date(timeIntervalSince1970: 99 + Double(index)),
                elapsed: index == 0 ? 0 : Double(index - 1),
                isWarmUp: index == 0,
                state: index.isMultiple(of: 2) ? .frontmost : .visible,
                metrics: GroupedProcessMetrics(
                    cpuCoreUsage: cpu,
                    physicalMemoryBytes: UInt64(1_024 * (index + 1)),
                    diskReadBytesPerSecond: Double(10 * (index + 1)),
                    diskWriteBytesPerSecond: Double(10 * (index + 2)),
                    wakeupsPerSecond: Double(index),
                    processCount: index + 1,
                    threadCount: index + 2,
                    unavailableProcessCount: cpu == nil ? 1 : 0
                ),
                isPartial: cpu == nil
            )
        }
        return ControlledTestResult(
            session: session,
            rounds: [round],
            samples: samples,
            summaries: []
        )
    }
}

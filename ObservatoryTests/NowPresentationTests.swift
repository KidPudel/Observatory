import Foundation
import Testing
@testable import ObservatoryDomain

struct NowPresentationTests {
    @Test
    func activityMonitorPercentageIsTheProductDefault() {
        #expect(CPURepresentation.productDefault == .activityMonitorPercentage)
    }

    @Test
    func cpuRepresentationsAreMathematicallyEquivalent() {
        let cores = 1.75
        let processorCount = 10

        #expect(CPURepresentation.cores.value(
            coreUsage: cores,
            logicalProcessorCount: processorCount
        ) == 1.75)
        #expect(CPURepresentation.activityMonitorPercentage.value(
            coreUsage: cores,
            logicalProcessorCount: processorCount
        ) == 175)
        #expect(CPURepresentation.totalCapacityPercentage.value(
            coreUsage: cores,
            logicalProcessorCount: processorCount
        ) == 17.5)
    }

    @Test
    func accumulatorUsesFiveSecondCPUAverageAndKeepsLiveMemoryPeak() throws {
        let fixture = Fixture()
        var accumulator = NowSnapshotAccumulator()
        var final = NowSnapshot.empty

        for second in 1...6 {
            let date = Date(timeIntervalSince1970: TimeInterval(second))
            let cpu = Double(second)
            let memory = UInt64(second == 4 ? 800 : second * 100)
            final = accumulator.ingest(
                grouping: fixture.grouping(cpu: cpu, memory: memory, date: date),
                processes: [fixture.process],
                samples: [fixture.sample(cpu: cpu, memory: memory, date: date)],
                capturedAt: date
            )
        }

        let application = try #require(final.applications.first)
        #expect(application.metrics.cpuCoreUsage == 4)
        #expect(application.metrics.physicalMemoryBytes == 600)
        #expect(application.memoryPeakBytes == 800)
    }

    @Test
    func wallClockRollbackClearsFutureLiveCPUAndTimelinePoints() throws {
        let fixture = Fixture()
        var accumulator = NowSnapshotAccumulator()
        var timeline = NowTimelineAccumulator(windowDuration: 60)
        let future = Date(timeIntervalSince1970: 100)
        let corrected = Date(timeIntervalSince1970: 10)

        timeline.ingest(accumulator.ingest(
            grouping: fixture.grouping(cpu: 9, memory: 900, date: future),
            processes: [fixture.process],
            samples: [fixture.sample(cpu: 9, memory: 900, date: future)],
            capturedAt: future
        ))
        let snapshot = accumulator.ingest(
            grouping: fixture.grouping(cpu: 2, memory: 200, date: corrected),
            processes: [fixture.process],
            samples: [fixture.sample(cpu: 2, memory: 200, date: corrected)],
            capturedAt: corrected
        )
        timeline.ingest(snapshot)

        #expect(try #require(snapshot.applications.first).metrics.cpuCoreUsage == 2)
        #expect(timeline.points.map(\.capturedAt) == [corrected])
    }

    @Test
    func missingMetricsStayUnavailableAndMakeTotalPartial() throws {
        let fixture = Fixture()
        let date = Date(timeIntervalSince1970: 10)
        let unavailable = ProcessSample(
            process: fixture.process.identity,
            capturedAt: date,
            availability: .inaccessible
        )
        let grouping = ApplicationGrouper().group(
            applications: [fixture.application],
            processes: [fixture.process],
            samples: [unavailable]
        )
        var accumulator = NowSnapshotAccumulator()

        let snapshot = accumulator.ingest(
            grouping: grouping,
            processes: [fixture.process],
            samples: [unavailable],
            capturedAt: date
        )
        let application = try #require(snapshot.applications.first)

        #expect(application.metrics.cpuCoreUsage == nil)
        #expect(application.metrics.physicalMemoryBytes == nil)
        #expect(application.metrics.diskReadBytesPerSecond == nil)
        #expect(application.isPartialTotal)
        #expect(application.partialExplanation?.contains("unavailable") == true)
    }

    @Test
    func searchMatchesApplicationBeforeOwnedProcessAndMetricSortPlacesMissingLast() {
        let fixture = Fixture()
        let second = fixture.application(
            name: "Browser",
            bundleIdentifier: "test.browser",
            path: "/Applications/Browser.app",
            pid: 200
        )
        let firstSnapshot = fixture.presentation(
            application: fixture.application,
            processName: "special-helper",
            cpu: nil
        )
        let secondSnapshot = fixture.presentation(
            application: second,
            processName: "renderer",
            cpu: 2
        )
        let snapshot = NowSnapshot(
            capturedAt: Date(),
            applications: [firstSnapshot, secondSnapshot],
            unassignedProcesses: []
        )

        #expect(snapshot.applications(matching: "Editor", sortedBy: .name).map(\.id)
            == [fixture.application.identity])
        #expect(snapshot.applications(matching: "special", sortedBy: .name).map(\.id)
            == [fixture.application.identity])
        #expect(snapshot.applications(matching: "", sortedBy: .cpu).map(\.id)
            == [second.identity, fixture.application.identity])
    }

    @Test
    func liveTimelineIsBoundedAndKeepsLightweightApplicationMetrics() throws {
        let fixture = Fixture()
        var timeline = NowTimelineAccumulator(windowDuration: 2)

        for second in 1...4 {
            let date = Date(timeIntervalSince1970: TimeInterval(second))
            var snapshot = NowSnapshot.empty
            var accumulator = NowSnapshotAccumulator()
            snapshot = accumulator.ingest(
                grouping: fixture.grouping(
                    cpu: Double(second),
                    memory: UInt64(second * 100),
                    date: date
                ),
                processes: [fixture.process],
                samples: [
                    fixture.sample(
                        cpu: Double(second),
                        memory: UInt64(second * 100),
                        date: date
                    )
                ],
                capturedAt: date
            )
            timeline.ingest(snapshot)
        }

        #expect(timeline.points.map(\.capturedAt) == [
            Date(timeIntervalSince1970: 2),
            Date(timeIntervalSince1970: 3),
            Date(timeIntervalSince1970: 4),
        ])
        let application = try #require(timeline.points.last?.applications.first)
        #expect(application.displayName == "Editor")
        #expect(application.metrics.physicalMemoryBytes == 400)
    }

    @Test
    func liveTimelineConvertsAndTotalsEveryMetricWithoutReinterpretingMemoryBits() {
        let fixture = Fixture()
        let browser = fixture.application(
            name: "Browser",
            bundleIdentifier: "test.browser",
            path: "/Applications/Browser.app",
            pid: 200
        )
        let point = NowTimelinePoint(
            snapshot: NowSnapshot(
                capturedAt: Date(timeIntervalSince1970: 20),
                applications: [
                    fixture.presentation(
                        application: fixture.application,
                        processName: "editor",
                        cpu: 2,
                        memory: 3_000_000_000,
                        diskRead: 100,
                        diskWrite: 50,
                        wakeups: 4,
                        processCount: 2
                    ),
                    fixture.presentation(
                        application: browser,
                        processName: "browser",
                        cpu: 0.5,
                        memory: 1_000_000_000,
                        diskRead: 20,
                        diskWrite: 30,
                        wakeups: 6,
                        processCount: 3
                    ),
                ],
                unassignedProcesses: []
            )
        )

        #expect(point.totalValue(
            for: .cpu,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == 250)
        #expect(point.totalValue(
            for: .memory,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == 4_000_000_000)
        #expect(point.totalValue(
            for: .disk,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == 200)
        #expect(point.totalValue(
            for: .wakeups,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == 10)
        #expect(point.totalValue(
            for: .processCount,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == 5)
    }

    @Test
    func liveTimelineAggregateStaysUnavailableWhenAnyApplicationValueIsMissing() {
        let fixture = Fixture()
        let point = NowTimelinePoint(
            snapshot: NowSnapshot(
                capturedAt: Date(timeIntervalSince1970: 21),
                applications: [
                    fixture.presentation(
                        application: fixture.application,
                        processName: "editor",
                        cpu: 1,
                        memory: nil
                    )
                ],
                unassignedProcesses: []
            )
        )

        #expect(point.totalValue(
            for: .memory,
            cpuRepresentation: .activityMonitorPercentage,
            logicalProcessorCount: 10
        ) == nil)
    }

    @Test
    func liveTimelineSystemCapacityUsesInstalledMemoryAndCPURepresentation() {
        let gibibyte = UInt64(1_024 * 1_024 * 1_024)
        let capacity = NowTimelineSystemCapacity(
            logicalProcessorCount: 8,
            physicalMemoryBytes: 16 * gibibyte
        )

        #expect(capacity.value(
            for: .cpu,
            cpuRepresentation: .activityMonitorPercentage
        ) == 800)
        #expect(capacity.value(
            for: .cpu,
            cpuRepresentation: .cores
        ) == 8)
        #expect(capacity.value(
            for: .cpu,
            cpuRepresentation: .totalCapacityPercentage
        ) == 100)
        #expect(capacity.value(
            for: .memory,
            cpuRepresentation: .activityMonitorPercentage
        ) == Double(16 * gibibyte))
        #expect(capacity.value(
            for: .disk,
            cpuRepresentation: .activityMonitorPercentage
        ) == nil)
        #expect(capacity.value(
            for: .wakeups,
            cpuRepresentation: .activityMonitorPercentage
        ) == nil)
        #expect(capacity.value(
            for: .processCount,
            cpuRepresentation: .activityMonitorPercentage
        ) == nil)
    }
}

private struct Fixture {
    let application: DiscoveredApplication
    let process: DiscoveredProcess

    init() {
        application = Self.makeApplication(
            name: "Editor",
            bundleIdentifier: "test.editor",
            path: "/Applications/Editor.app",
            pid: 100
        )
        process = DiscoveredProcess(
            identity: application.primaryProcess!
        )
    }

    func application(
        name: String,
        bundleIdentifier: String,
        path: String,
        pid: Int32
    ) -> DiscoveredApplication {
        Self.makeApplication(
            name: name,
            bundleIdentifier: bundleIdentifier,
            path: path,
            pid: pid
        )
    }

    func sample(
        cpu: Double,
        memory: UInt64,
        date: Date
    ) -> ProcessSample {
        ProcessSample(
            process: process.identity,
            capturedAt: date,
            availability: .available,
            intervalSeconds: 1,
            cpuCoreUsage: cpu,
            physicalMemoryBytes: memory,
            diskReadBytesPerSecond: 0,
            diskWriteBytesPerSecond: 0,
            wakeupsPerSecond: 0,
            threadCount: 2
        )
    }

    func grouping(
        cpu: Double,
        memory: UInt64,
        date: Date
    ) -> GroupingResult {
        ApplicationGrouper().group(
            applications: [application],
            processes: [process],
            samples: [sample(cpu: cpu, memory: memory, date: date)]
        )
    }

    func presentation(
        application: DiscoveredApplication,
        processName: String,
        cpu: Double?,
        memory: UInt64? = 100,
        diskRead: Double? = 0,
        diskWrite: Double? = 0,
        wakeups: Double? = 0,
        processCount: Int = 1
    ) -> NowApplicationSnapshot {
        let discoveredProcess = DiscoveredProcess(
            identity: ProcessIdentity(
                processIdentifier: application.primaryProcessIdentifier,
                startTime: Date(),
                executablePath: "/tmp/\(processName)"
            )
        )
        let ownership = ProcessOwnership(
            process: discoveredProcess.identity,
            application: application.identity,
            confidence: .high,
            evidence: [.primaryProcess]
        )
        return NowApplicationSnapshot(
            application: application,
            state: .visible,
            metrics: GroupedProcessMetrics(
                cpuCoreUsage: cpu,
                physicalMemoryBytes: memory,
                diskReadBytesPerSecond: diskRead,
                diskWriteBytesPerSecond: diskWrite,
                wakeupsPerSecond: wakeups,
                processCount: processCount,
                threadCount: 2,
                unavailableProcessCount: 0
            ),
            memoryPeakBytes: memory,
            members: [
                NowProcessSnapshot(
                    process: discoveredProcess,
                    displayName: processName,
                    sample: nil,
                    ownership: ownership
                )
            ],
            isPartialTotal: false,
            partialExplanation: nil
        )
    }

    private static func makeApplication(
        name: String,
        bundleIdentifier: String,
        path: String,
        pid: Int32
    ) -> DiscoveredApplication {
        let identity = ProcessIdentity(
            processIdentifier: pid,
            startTime: Date(timeIntervalSince1970: Double(pid)),
            executablePath: "\(path)/Contents/MacOS/\(name)"
        )
        return DiscoveredApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: bundleIdentifier,
                bundleURL: URL(fileURLWithPath: path)
            ),
            displayName: name,
            primaryProcessIdentifier: pid,
            primaryProcess: identity,
            state: .visible
        )
    }
}

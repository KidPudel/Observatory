import Foundation
import Testing
@testable import ObservatoryDomain

struct ApplicationGroupingTests {
    @Test
    func groupsNativeElectronAndExternalDescendantsFromStrongestEvidence() throws {
        let native = application(
            name: "Native",
            bundleIdentifier: "test.native",
            bundlePath: "/Applications/Native.app",
            pid: 100
        )
        let electron = application(
            name: "Code",
            bundleIdentifier: "test.code",
            bundlePath: "/Applications/Code.app",
            pid: 200
        )
        let processes = [
            process(pid: 100, path: "/Applications/Native.app/Contents/MacOS/Native"),
            process(
                pid: 101,
                path: "/Applications/Native.app/Contents/XPCServices/Worker.xpc/Contents/MacOS/Worker",
                parent: 1,
                bundleIdentifier: "test.native.worker"
            ),
            process(pid: 200, path: "/Applications/Code.app/Contents/MacOS/Code"),
            process(
                pid: 201,
                path: "/Applications/Code.app/Contents/Frameworks/Code Helper.app/Contents/MacOS/Code Helper",
                parent: 200
            ),
            process(pid: 202, path: "/Library/Application Support/Code/renderer", parent: 201)
        ]

        let result = ApplicationGrouper().group(
            applications: [native, electron],
            processes: processes
        )
        let nativeGroup = try #require(result.groups.first { $0.application.identity == native.identity })
        let electronGroup = try #require(
            result.groups.first { $0.application.identity == electron.identity }
        )
        let nativeHelper = try #require(
            result.ownerships.first { $0.process.processIdentifier == 101 }
        )
        let externalRenderer = try #require(
            result.ownerships.first { $0.process.processIdentifier == 202 }
        )

        #expect(nativeGroup.members.count == 2)
        #expect(electronGroup.members.count == 3)
        #expect(nativeHelper.confidence == .high)
        #expect(nativeHelper.evidence.contains(.executableInsideBundle))
        #expect(externalRenderer.application == electron.identity)
        #expect(externalRenderer.confidence == .medium)
        #expect(externalRenderer.evidence == [.descendantOfPrimary])
        #expect(Set(result.ownerships.compactMap(\.application)).count == 2)
    }

    @Test
    func equalWeakEvidenceStaysUnassignedAndVisibleAsAConflict() throws {
        let first = application(
            name: "Acme",
            bundleIdentifier: "test.acme.one",
            bundlePath: "/Applications/Acme One.app",
            pid: 100
        )
        let second = application(
            name: "Acme",
            bundleIdentifier: "test.acme.two",
            bundlePath: "/Applications/Acme Two.app",
            pid: 200
        )
        let ambiguous = process(pid: 300, path: "/usr/local/bin/acme-helper")

        let result = ApplicationGrouper().group(
            applications: [first, second],
            processes: [ambiguous]
        )
        let ownership = try #require(result.ownerships.first)

        #expect(ownership.application == nil)
        #expect(ownership.confidence == .unassigned)
        #expect(ownership.evidence == [.nameSimilarity])
        #expect(Set(ownership.conflictingApplications) == [first.identity, second.identity])
        #expect(result.groups.allSatisfy { $0.members.isEmpty })
    }

    @Test
    func includeExcludeAndResetRulesRestoreAutomaticGrouping() throws {
        let app = application(
            name: "Editor",
            bundleIdentifier: "test.editor",
            bundlePath: "/Applications/Editor.app",
            pid: 100
        )
        let helper = process(pid: 300, path: "/opt/vendor/mystery-renderer")
        let matcher = ProcessRuleMatcher.executablePath(
            try #require(helper.identity.executablePath)
        )
        var grouper = ApplicationGrouper()

        #expect(
            grouper.group(applications: [app], processes: [helper])
                .ownerships.first?.application == nil
        )

        grouper.setRule(
            GroupingRule(application: app.identity, matcher: matcher, action: .include)
        )
        let included = try #require(
            grouper.group(applications: [app], processes: [helper]).ownerships.first
        )
        #expect(included.application == app.identity)
        #expect(included.confidence == .high)
        #expect(included.evidence == [.manualInclude])

        grouper.setRule(
            GroupingRule(application: app.identity, matcher: matcher, action: .exclude)
        )
        #expect(
            grouper.group(applications: [app], processes: [helper])
                .ownerships.first?.application == nil
        )

        grouper.resetRules(for: app.identity)
        #expect(grouper.rules.isEmpty)
        #expect(
            grouper.group(applications: [app], processes: [helper])
                .ownerships.first?.application == nil
        )
    }

    @Test
    func sessionRuleOnlyAppliesToItsSession() throws {
        let app = application(
            name: "Editor",
            bundleIdentifier: "test.editor",
            bundlePath: "/Applications/Editor.app",
            pid: 100
        )
        let helper = process(pid: 300, path: "/opt/vendor/mystery-renderer")
        let sessionID = UUID()
        let matcher = ProcessRuleMatcher.executablePath(
            try #require(helper.identity.executablePath)
        )
        let grouper = ApplicationGrouper(
            rules: [
                GroupingRule(
                    application: app.identity,
                    matcher: matcher,
                    action: .include,
                    scope: .session(sessionID)
                )
            ]
        )

        #expect(
            grouper.group(
                applications: [app],
                processes: [helper],
                sessionID: sessionID
            ).ownerships.first?.application == app.identity
        )
        #expect(
            grouper.group(
                applications: [app],
                processes: [helper],
                sessionID: UUID()
            ).ownerships.first?.application == nil
        )
    }

    @Test
    func groupedMetricsSumEachOwnedLiveProcessOnce() throws {
        let app = application(
            name: "Browser",
            bundleIdentifier: "test.browser",
            bundlePath: "/Applications/Browser.app",
            pid: 100
        )
        let primary = process(
            pid: 100,
            path: "/Applications/Browser.app/Contents/MacOS/Browser"
        )
        let helper = process(
            pid: 101,
            path: "/Applications/Browser.app/Contents/Frameworks/Helper"
        )
        let exited = process(
            pid: 102,
            path: "/Applications/Browser.app/Contents/Frameworks/Exited"
        )
        let unrelated = process(pid: 900, path: "/usr/bin/unrelated")
        let samples = [
            sample(primary.identity, cpu: 1, memory: 100, read: 10, write: 20, wakeups: 2, threads: 3),
            sample(helper.identity, cpu: 2, memory: 200, read: 30, write: 40, wakeups: 4, threads: 5),
            ProcessSample(
                process: exited.identity,
                capturedAt: Date(),
                availability: .exited
            ),
            sample(unrelated.identity, cpu: 100, memory: 10_000, read: 1_000, write: 2_000, wakeups: 50, threads: 20)
        ]

        let result = ApplicationGrouper().group(
            applications: [app],
            processes: [primary, helper, helper, exited, unrelated],
            samples: samples
        )
        let group = try #require(result.groups.first)

        #expect(group.members.count == 3)
        #expect(group.confidence == .high)
        #expect(group.metrics.cpuCoreUsage == 3)
        #expect(group.metrics.physicalMemoryBytes == 300)
        #expect(group.metrics.diskReadBytesPerSecond == 40)
        #expect(group.metrics.diskWriteBytesPerSecond == 60)
        #expect(group.metrics.wakeupsPerSecond == 6)
        #expect(group.metrics.processCount == 2)
        #expect(group.metrics.threadCount == 8)
        #expect(group.metrics.unavailableProcessCount == 1)
    }

    @Test
    func reusedPIDDoesNotMatchStablePrimaryIdentity() throws {
        let app = application(
            name: "Stable",
            bundleIdentifier: "test.stable",
            bundlePath: "/Applications/Stable.app",
            pid: 100
        )
        let reused = DiscoveredProcess(
            identity: ProcessIdentity(
                processIdentifier: 100,
                startTime: Date(timeIntervalSince1970: 999),
                executablePath: "/tmp/unrelated"
            )
        )

        let ownership = try #require(
            ApplicationGrouper().group(
                applications: [app],
                processes: [reused]
            ).ownerships.first
        )

        #expect(ownership.application == nil)
        #expect(ownership.confidence == .unassigned)
    }

    private func application(
        name: String,
        bundleIdentifier: String,
        bundlePath: String,
        pid: Int32
    ) -> DiscoveredApplication {
        let primary = ProcessIdentity(
            processIdentifier: pid,
            startTime: Date(timeIntervalSince1970: Double(pid)),
            executablePath: "\(bundlePath)/Contents/MacOS/\(name)"
        )
        return DiscoveredApplication(
            identity: ApplicationIdentity(
                bundleIdentifier: bundleIdentifier,
                bundleURL: URL(fileURLWithPath: bundlePath)
            ),
            displayName: name,
            primaryProcessIdentifier: pid,
            primaryProcess: primary,
            state: .visible
        )
    }

    private func process(
        pid: Int32,
        path: String,
        parent: Int32? = nil,
        bundleIdentifier: String? = nil
    ) -> DiscoveredProcess {
        DiscoveredProcess(
            identity: ProcessIdentity(
                processIdentifier: pid,
                startTime: Date(timeIntervalSince1970: Double(pid)),
                executablePath: path
            ),
            parentProcessIdentifier: parent,
            bundleIdentifier: bundleIdentifier
        )
    }

    private func sample(
        _ process: ProcessIdentity,
        cpu: Double,
        memory: UInt64,
        read: Double,
        write: Double,
        wakeups: Double,
        threads: Int
    ) -> ProcessSample {
        ProcessSample(
            process: process,
            capturedAt: Date(),
            availability: .available,
            intervalSeconds: 1,
            cpuCoreUsage: cpu,
            physicalMemoryBytes: memory,
            diskReadBytesPerSecond: read,
            diskWriteBytesPerSecond: write,
            wakeupsPerSecond: wakeups,
            threadCount: threads
        )
    }
}

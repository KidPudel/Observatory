import Combine
import Foundation
import ObservatoryDomain
import ObservatoryPersistence

struct NowCollectionFrame: Sendable {
    let snapshot: NowSnapshot
    let warning: String?
}

actor LiveNowCollector {
    private let applicationDiscovery: any ApplicationDiscovering
    private let processDiscovery: any ProcessDiscovering
    private let processSampler: any ProcessSampling
    private let rulePersistence: (any GroupingRulePersisting)?
    private var grouper = ApplicationGrouper()
    private var accumulator = NowSnapshotAccumulator()
    private var loadedRules = false
    private var persistenceWarning: String?
    private var cachedApplications: [DiscoveredApplication] = []
    private var cachedProcesses: [DiscoveredProcess] = []
    private var cachedOwnership: GroupingResult?
    private var lastInventoryRefresh: Date?
    private var lastFrame: NowCollectionFrame?
    private let inventoryRefreshInterval: TimeInterval = 5
    private let minimumSampleInterval: TimeInterval = 0.75

    init(
        applicationDiscovery: any ApplicationDiscovering,
        processDiscovery: any ProcessDiscovering,
        processSampler: any ProcessSampling,
        rulePersistence: (any GroupingRulePersisting)?
    ) {
        self.applicationDiscovery = applicationDiscovery
        self.processDiscovery = processDiscovery
        self.processSampler = processSampler
        self.rulePersistence = rulePersistence
    }

    func collect(at capturedAt: Date = Date()) async -> NowCollectionFrame {
        if let lastFrame,
           capturedAt.timeIntervalSince(lastFrame.snapshot.capturedAt)
            < minimumSampleInterval {
            return lastFrame
        }
        await loadRulesIfNeeded()
        let shouldRefreshInventory =
            cachedOwnership == nil
            || capturedAt.timeIntervalSince(lastInventoryRefresh ?? .distantPast)
                >= inventoryRefreshInterval

        let ownershipOnly: GroupingResult
        if shouldRefreshInventory {
            cachedApplications = await applicationDiscovery.runningApplications()
            cachedProcesses = await processDiscovery.runningProcesses()
            ownershipOnly = grouper.group(
                applications: cachedApplications,
                processes: cachedProcesses
            )
            cachedOwnership = ownershipOnly
            lastInventoryRefresh = capturedAt
        } else {
            ownershipOnly = cachedOwnership!
        }
        let sampledIdentities = ownershipOnly.ownerships.compactMap { ownership in
            if ownership.application != nil
                || !ownership.evidence.isEmpty
                || !ownership.conflictingApplications.isEmpty {
                return ownership.process
            }
            return nil
        }
        let samples = await processSampler.sample(
            processes: sampledIdentities,
            at: capturedAt
        )
        let grouping = grouper.applying(samples: samples, to: ownershipOnly)
        let frame = NowCollectionFrame(
            snapshot: accumulator.ingest(
                grouping: grouping,
                processes: cachedProcesses,
                samples: samples,
                capturedAt: capturedAt
            ),
            warning: persistenceWarning
        )
        lastFrame = frame
        return frame
    }

    func setRule(
        application: ApplicationIdentity,
        matcher: ProcessRuleMatcher,
        action: GroupingRuleAction
    ) async throws {
        await loadRulesIfNeeded()
        let rule = GroupingRule(
            application: application,
            matcher: matcher,
            action: action
        )
        if let rulePersistence {
            try await rulePersistence.saveGroupingRule(rule)
        }
        grouper.setRule(rule)
        cachedOwnership = nil
        lastFrame = nil
    }

    func resetRules(for application: ApplicationIdentity? = nil) async throws {
        await loadRulesIfNeeded()
        if let rulePersistence {
            try await rulePersistence.resetGroupingRules(for: application)
        }
        grouper.resetRules(for: application)
        cachedOwnership = nil
        lastFrame = nil
    }

    private func loadRulesIfNeeded() async {
        guard !loadedRules else { return }
        loadedRules = true
        guard let rulePersistence else {
            persistenceWarning = "Grouping changes will last only until Observatory quits."
            return
        }
        do {
            grouper = try await ApplicationGrouper(
                rules: rulePersistence.groupingRules()
            )
        } catch {
            persistenceWarning = "Saved grouping decisions could not be loaded."
        }
    }

}

extension LiveNowCollector: SessionMetricSampling {
    func readings(
        for applications: [ApplicationIdentity],
        sessionID: UUID,
        at date: Date
    ) async -> [ApplicationMetricReading] {
        _ = sessionID
        let applicationIDs = Set(applications)
        let frame = await collect(at: date)
        return frame.snapshot.applications.compactMap { snapshot in
            guard applicationIDs.contains(snapshot.id) else { return nil }
            return ApplicationMetricReading(
                application: snapshot.id,
                capturedAt: frame.snapshot.capturedAt,
                state: snapshot.state,
                metrics: snapshot.metrics,
                isPartial: snapshot.isPartialTotal
            )
        }
    }
}

@MainActor
final class NowViewModel: ObservableObject {
    @Published private(set) var snapshot = NowSnapshot.empty
    @Published private(set) var timelinePoints: [NowTimelinePoint] = []
    @Published private(set) var isLoading = true
    @Published private(set) var notice: String?
    @Published private(set) var ruleActionInProgress = false
    @Published var isVisualUpdatesPaused = false {
        didSet {
            publishPendingSnapshotIfPossible()
        }
    }

    private let collector: LiveNowCollector
    private var timelineAccumulator = NowTimelineAccumulator()
    private var pendingSnapshot: NowSnapshot?
    private var isScrollRenderingSuspended = false

    init(collector: LiveNowCollector) {
        self.collector = collector
    }

    func run() async {
        repeat {
            await refresh()
            do {
                try await Task.sleep(for: .seconds(1))
            } catch {
                return
            }
        } while !Task.isCancelled
    }

    func setGroupingRule(
        process: NowProcessSnapshot,
        application: ApplicationIdentity,
        action: GroupingRuleAction
    ) {
        guard let matcher = process.ruleMatcher else {
            notice = "This process has no stable path or bundle identity for a saved rule."
            return
        }
        Task {
            ruleActionInProgress = true
            defer { ruleActionInProgress = false }
            do {
                try await collector.setRule(
                    application: application,
                    matcher: matcher,
                    action: action
                )
                notice = action == .include
                    ? "The process is now included in this application."
                    : "The process is now excluded from this application."
                await refresh()
            } catch {
                notice = "The grouping decision could not be saved."
            }
        }
    }

    func resetGroupingRules(for application: ApplicationIdentity? = nil) {
        Task {
            ruleActionInProgress = true
            defer { ruleActionInProgress = false }
            do {
                try await collector.resetRules(for: application)
                notice = application == nil
                    ? "All grouping decisions were reset."
                    : "Grouping decisions for this application were reset."
                await refresh()
            } catch {
                notice = "Grouping decisions could not be reset."
            }
        }
    }

    func dismissNotice() {
        notice = nil
    }

    func setScrollRenderingSuspended(_ isSuspended: Bool) {
        guard isScrollRenderingSuspended != isSuspended else { return }
        isScrollRenderingSuspended = isSuspended
        publishPendingSnapshotIfPossible()
    }

    private func refresh() async {
        let frame = await collector.collect()
        if let warning = frame.warning, warning != notice {
            notice = warning
        }
        timelineAccumulator.ingest(frame.snapshot)
        pendingSnapshot = frame.snapshot
        publishPendingSnapshotIfPossible()
        if isLoading {
            isLoading = false
        }
    }

    private var canPublishVisualUpdates: Bool {
        !isVisualUpdatesPaused && !isScrollRenderingSuspended
    }

    private func publishPendingSnapshotIfPossible() {
        guard canPublishVisualUpdates, let pendingSnapshot else { return }
        if snapshot != pendingSnapshot {
            snapshot = pendingSnapshot
        }
        if timelinePoints != timelineAccumulator.points {
            timelinePoints = timelineAccumulator.points
        }
        self.pendingSnapshot = nil
    }
}

@MainActor
enum AppServices {
    struct RootModels {
        let now: NowViewModel
        let sessions: SessionsViewModel
        let history: HistoryViewModel
    }

    static func makeRootModels() -> RootModels {
        migrateCPURepresentationDefault()
        let sampler = MacOSProcessSampler()
        let discovery = MacOSApplicationDiscovery(processSampler: sampler)
        let catalog = makeCatalog()
        let collector = LiveNowCollector(
            applicationDiscovery: discovery,
            processDiscovery: sampler,
            processSampler: sampler,
            rulePersistence: catalog
        )
        let storage = LocalSessionStorage(
            recordingsRoot: applicationDirectory().appending(
                path: "Recordings",
                directoryHint: .isDirectory
            )
        )
        let sessionEngine = ControlledTestEngine(
            persistence: catalog,
            sampler: collector,
            storage: storage,
            clock: SystemObservatoryClock(),
            activation: MacOSApplicationActivation()
        )
        return RootModels(
            now: NowViewModel(collector: collector),
            sessions: SessionsViewModel(
                engine: sessionEngine,
                discovery: discovery
            ),
            history: HistoryViewModel(engine: sessionEngine)
        )
    }

    private static func migrateCPURepresentationDefault() {
        let defaults = UserDefaults.standard
        let migrationKey = "preferences.cpuPercentageDefault.v1"
        guard !defaults.bool(forKey: migrationKey) else { return }

        let preferenceKey = "now.cpuRepresentation"
        let existingValue = defaults.string(forKey: preferenceKey)
        if existingValue == nil || existingValue == CPURepresentation.cores.rawValue {
            defaults.set(
                CPURepresentation.productDefault.rawValue,
                forKey: preferenceKey
            )
        }
        defaults.set(true, forKey: migrationKey)
    }

    private static func makeCatalog() -> CatalogDatabase {
        do {
            return try CatalogDatabase(
                path: applicationDirectory().appending(path: "catalog.sqlite").path
            )
        } catch {
            return try! CatalogDatabase(inMemory: true)
        }
    }

    private static func applicationDirectory() -> URL {
        do {
            let applicationSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let directory = applicationSupport.appending(
                path: "Observatory",
                directoryHint: .isDirectory
            )
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        } catch {
            let fallback = FileManager.default.temporaryDirectory.appending(
                path: "Observatory",
                directoryHint: .isDirectory
            )
            try? FileManager.default.createDirectory(
                at: fallback,
                withIntermediateDirectories: true
            )
            return fallback
        }
    }
}

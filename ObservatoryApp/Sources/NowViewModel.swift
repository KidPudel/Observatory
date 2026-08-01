import Combine
import Foundation
import ObservatoryDomain
import ObservatoryPersistence

struct NowCollectionFrame: Sendable {
    let snapshot: NowSnapshot
    let sessionReadings: [ApplicationMetricReading]
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
    private let cadenceClock = ContinuousClock()
    private var lastInventoryRefresh: ContinuousClock.Instant?
    private var lastCollectionInstant: ContinuousClock.Instant?
    private var lastFrame: NowCollectionFrame?
    private let inventoryRefreshInterval = Duration.seconds(5)
    private let minimumSampleInterval = Duration.milliseconds(750)

    init(
        applicationDiscovery: any ApplicationDiscovering,
        processDiscovery: any ProcessDiscovering,
        processSampler: any ProcessSampling,
        rulePersistence: (any GroupingRulePersisting)?,
        persistenceWarning: String? = nil
    ) {
        self.applicationDiscovery = applicationDiscovery
        self.processDiscovery = processDiscovery
        self.processSampler = processSampler
        self.rulePersistence = rulePersistence
        self.persistenceWarning = persistenceWarning
    }

    func collect(at capturedAt: Date = Date()) async -> NowCollectionFrame {
        let collectionInstant = cadenceClock.now
        if let lastFrame, let lastCollectionInstant,
           lastCollectionInstant.duration(to: collectionInstant)
            < minimumSampleInterval {
            return lastFrame
        }
        await loadRulesIfNeeded()
        let discoveredApplications = await applicationDiscovery.runningApplications()
        let shouldRefreshInventory =
            cachedOwnership == nil
            || lastInventoryRefresh.map {
                $0.duration(to: collectionInstant) >= inventoryRefreshInterval
            } ?? true
            || applicationTopologyChanged(
                from: cachedApplications,
                to: discoveredApplications
            )

        let ownershipOnly: GroupingResult
        if shouldRefreshInventory {
            cachedApplications = discoveredApplications
            cachedProcesses = await processDiscovery.runningProcesses()
            ownershipOnly = grouper.group(
                applications: cachedApplications,
                processes: cachedProcesses
            )
            cachedOwnership = ownershipOnly
            lastInventoryRefresh = collectionInstant
        } else {
            cachedApplications = discoveredApplications
            ownershipOnly = replacingApplications(
                in: cachedOwnership!,
                with: discoveredApplications
            )
            cachedOwnership = ownershipOnly
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
        let snapshot = accumulator.ingest(
            grouping: grouping,
            processes: cachedProcesses,
            samples: samples,
            capturedAt: capturedAt
        )
        let presentedApplications = Dictionary(
            uniqueKeysWithValues: snapshot.applications.map { ($0.id, $0) }
        )
        let frame = NowCollectionFrame(
            snapshot: snapshot,
            sessionReadings: grouping.groups.map { group in
                let presented = presentedApplications[group.application.identity]
                return ApplicationMetricReading(
                    application: group.application.identity,
                    capturedAt: capturedAt,
                    state: presented?.state ?? group.application.state,
                    metrics: group.metrics,
                    isPartial: presented?.isPartialTotal ?? true
                )
            },
            warning: persistenceWarning
        )
        lastFrame = frame
        lastCollectionInstant = collectionInstant
        return frame
    }

    func prepareForRound(
        application: ApplicationIdentity,
        sessionID: UUID,
        at date: Date
    ) async {
        _ = sessionID
        _ = date
        await loadRulesIfNeeded()
        let applications = await applicationDiscovery.runningApplications()
        let processes = await processDiscovery.runningProcesses()
        let ownership = grouper.group(
            applications: applications,
            processes: processes
        )
        cachedApplications = applications
        cachedProcesses = processes
        cachedOwnership = ownership
        lastInventoryRefresh = cadenceClock.now

        let identities = ownership.groups
            .first { $0.application.identity == application }?
            .members.map(\.process) ?? []
        await processSampler.resetBaselines(for: identities)
        lastFrame = nil
        lastCollectionInstant = nil
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
        lastCollectionInstant = nil
    }

    func resetRules(for application: ApplicationIdentity? = nil) async throws {
        await loadRulesIfNeeded()
        if let rulePersistence {
            try await rulePersistence.resetGroupingRules(for: application)
        }
        grouper.resetRules(for: application)
        cachedOwnership = nil
        lastFrame = nil
        lastCollectionInstant = nil
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
            if persistenceWarning == nil {
                persistenceWarning = "Saved grouping decisions could not be loaded."
            }
        }
    }

    private func applicationTopologyChanged(
        from previous: [DiscoveredApplication],
        to current: [DiscoveredApplication]
    ) -> Bool {
        guard previous.count == current.count else { return true }
        let previousByIdentity = Dictionary(
            uniqueKeysWithValues: previous.map { ($0.identity, $0) }
        )
        return current.contains { application in
            guard let old = previousByIdentity[application.identity] else {
                return true
            }
            return old.primaryProcessIdentifier != application.primaryProcessIdentifier
                || old.primaryProcess != application.primaryProcess
        }
    }

    private func replacingApplications(
        in result: GroupingResult,
        with applications: [DiscoveredApplication]
    ) -> GroupingResult {
        let applicationsByIdentity = Dictionary(
            uniqueKeysWithValues: applications.map { ($0.identity, $0) }
        )
        return GroupingResult(
            groups: result.groups.compactMap { group in
                guard let application = applicationsByIdentity[
                    group.application.identity
                ] else {
                    return nil
                }
                return ApplicationGroupSnapshot(
                    application: application,
                    members: group.members,
                    confidence: group.confidence,
                    metrics: group.metrics
                )
            },
            ownerships: result.ownerships
        )
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
        return frame.sessionReadings.filter {
            applicationIDs.contains($0.application)
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
        let persistence = makePersistence()
        let collector = LiveNowCollector(
            applicationDiscovery: discovery,
            processDiscovery: sampler,
            processSampler: sampler,
            rulePersistence: persistence.catalog,
            persistenceWarning: persistence.warning
        )
        let sessionEngine = ControlledTestEngine(
            persistence: persistence.catalog,
            sampler: collector,
            storage: persistence.storage,
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

    private static func makePersistence() -> (
        catalog: any GroupingRulePersisting & SessionPersisting,
        storage: any StorageRootAccessing,
        warning: String?
    ) {
        do {
            let directory = try applicationDirectory()
            let catalog = try CatalogDatabase(
                path: directory.appending(path: "catalog.sqlite").path
            )
            let storage = LocalSessionStorage(
                recordingsRoot: directory.appending(
                    path: "Recordings",
                    directoryHint: .isDirectory
                )
            )
            return (catalog, storage, nil)
        } catch {
            let failure = PersistenceUnavailableError(underlyingError: error)
            let unavailableCatalog = UnavailableCatalog(failure: failure)
            return (
                unavailableCatalog,
                UnavailableSessionStorage(failure: failure),
                failure.errorDescription
            )
        }
    }

    private static func applicationDirectory() throws -> URL {
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
    }
}

private struct PersistenceUnavailableError: LocalizedError, Sendable {
    let detail: String

    init(underlyingError: Error) {
        detail = underlyingError.localizedDescription
    }

    var errorDescription: String? {
        "Observatory storage is unavailable. Recording is disabled to protect your results. \(detail)"
    }
}

private actor UnavailableCatalog: GroupingRulePersisting, SessionPersisting {
    let failure: PersistenceUnavailableError

    init(failure: PersistenceUnavailableError) {
        self.failure = failure
    }

    func saveGroupingRule(_ rule: GroupingRule) throws { throw failure }
    func groupingRules() throws -> [GroupingRule] { throw failure }
    func deleteGroupingRule(id: UUID) throws { throw failure }
    func resetGroupingRules(for application: ApplicationIdentity?) throws {
        throw failure
    }

    func createSession(
        _ session: MonitoringSession,
        rounds: [SessionRound]
    ) throws {
        throw failure
    }
    func saveSession(_ session: MonitoringSession) throws { throw failure }
    func session(id: UUID) throws -> MonitoringSession? { throw failure }
    func sessions() throws -> [MonitoringSession] { throw failure }
    func unfinishedControlledSession() throws -> MonitoringSession? {
        throw failure
    }
    func saveRound(_ round: SessionRound) throws { throw failure }
    func rounds(sessionID: UUID) throws -> [SessionRound] { throw failure }
    func saveSample(_ sample: SessionMetricSample) throws { throw failure }
    func samples(sessionID: UUID) throws -> [SessionMetricSample] { throw failure }
    func replaceSummaries(
        _ summaries: [ApplicationResultSummary],
        sessionID: UUID
    ) throws {
        throw failure
    }
    func summaries(sessionID: UUID) throws -> [ApplicationResultSummary] {
        throw failure
    }
    func deleteSamples(roundID: UUID) throws { throw failure }
    func deleteSession(id: UUID) throws { throw failure }
}

private actor UnavailableSessionStorage: StorageRootAccessing {
    let failure: PersistenceUnavailableError

    init(failure: PersistenceUnavailableError) {
        self.failure = failure
    }

    func sessionDirectory(named name: String, createdAt: Date) throws -> URL {
        throw failure
    }

    func writeSummary(_ result: ControlledTestResult, to directory: URL) throws {
        throw failure
    }

    func removeSessionDirectory(_ directory: URL) throws {
        throw failure
    }
}

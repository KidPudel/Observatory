import Combine
import Foundation
import ObservatoryDomain

@MainActor
final class SessionsViewModel: ObservableObject {
    @Published private(set) var engineState = ControlledTestEngineState(
        session: nil,
        rounds: [],
        summaries: [],
        currentRound: nil,
        remainingDuration: nil,
        recoveryRequired: false,
        notice: nil
    )
    @Published private(set) var runningApplications: [SessionApplication] = []
    @Published private(set) var selectedResult: ControlledTestResult?
    @Published private(set) var isLoading = true
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    @Published var sessionName = ""
    @Published var note = ""
    @Published var selectedApplications: Set<ApplicationIdentity> = []
    @Published var controlledTestMode = ControlledTestMode.manualGuided
    @Published var measuredDuration: TimeInterval = 30
    @Published var warmUpDuration: TimeInterval = 0
    @Published var roundCount = 1
    @Published var shortcut = GlobalShortcutChoice.none

    private let engine: ControlledTestEngine
    private let discovery: any ApplicationDiscovering
    private let promptController = RecordingPromptController()
    private let shortcutMonitor = GlobalShortcutMonitor()
    private var configuredShortcut: GlobalShortcutChoice?
    private var configuredSessionID: UUID?
    private var hasLoaded = false

    init(
        engine: ControlledTestEngine,
        discovery: any ApplicationDiscovering
    ) {
        self.engine = engine
        self.discovery = discovery
    }

    deinit {
        shortcutMonitor.unregister()
    }

    func run() async {
        if !hasLoaded {
            hasLoaded = true
            await initialLoad()
        }
        while !Task.isCancelled {
            await refreshState()
            do {
                try await Task.sleep(for: .milliseconds(250))
            } catch {
                return
            }
        }
    }

    func refreshApplications() {
        Task { await loadApplications() }
    }

    func prepareDraft(for snapshot: NowApplicationSnapshot) {
        guard engineState.session == nil else {
            errorMessage = "Finish the active controlled test before creating another."
            return
        }
        let application = SessionApplication(
            identity: snapshot.id,
            displayName: snapshot.application.displayName,
            version: Bundle(url: snapshot.id.bundleURL)?
                .object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        )
        if !runningApplications.contains(where: { $0.identity == application.identity }) {
            runningApplications.append(application)
            runningApplications.sort {
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
        }
        selectedApplications = [application.identity]
        if sessionName.isEmpty {
            sessionName = "\(application.displayName) test"
        }
    }

    func toggleApplication(_ application: SessionApplication) {
        if selectedApplications.contains(application.identity) {
            selectedApplications.remove(application.identity)
        } else if selectedApplications.count < 4 {
            selectedApplications.insert(application.identity)
        } else {
            errorMessage = "A controlled test can include at most four applications."
        }
    }

    func createSession() {
        guard !isWorking else { return }
        let applications = runningApplications.filter {
            selectedApplications.contains($0.identity)
        }
        let configuration = ControlledTestConfiguration(
            measuredDuration: measuredDuration,
            warmUpDuration: warmUpDuration,
            roundCount: roundCount,
            shortcut: shortcut
        )
        let mode = controlledTestMode
        perform {
            _ = try await self.engine.createSession(
                name: self.sessionName,
                note: self.note,
                applications: applications,
                configuration: configuration,
                mode: mode
            )
            if mode == .automaticForegroundIdle {
                try await self.engine.startAutomaticSequence()
            }
        }
    }

    func beginCurrentRound() {
        perform { try await self.engine.startNextRound() }
    }

    func skipCurrentRound() {
        perform { try await self.engine.skipNextRound() }
    }

    func retryRound(_ round: SessionRound) {
        perform { try await self.engine.retryRound(id: round.id) }
    }

    func finishPartial() {
        perform { try await self.engine.finishWithPartialResults() }
    }

    func cancel(preservingPartialResult: Bool) {
        perform {
            try await self.engine.cancel(
                preservingPartialResult: preservingPartialResult
            )
        }
    }

    func acceptRecovery() {
        Task {
            await engine.acceptRecovery()
            let recoveredState = await engine.state()
            if recoveredState.session?.controlledTestMode
                == .automaticForegroundIdle {
                do {
                    try await engine.startAutomaticSequence()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
            await refreshState()
        }
    }

    func discardRecovery() {
        cancel(preservingPartialResult: false)
    }

    func closeResult() {
        Task {
            await engine.closeCurrentSession()
            selectedResult = nil
            resetDraft()
            await refreshState()
        }
    }

    func dismissError() {
        errorMessage = nil
    }

    func dismissNotice() {
        Task {
            await engine.dismissNotice()
            await refreshState()
        }
    }

    private func initialLoad() async {
        do {
            try await engine.restoreUnfinishedSession()
        } catch {
            errorMessage = "The unfinished test could not be restored: \(error.localizedDescription)"
        }
        await loadApplications()
        await refreshState()
        isLoading = false
    }

    private func loadApplications() async {
        let discovered = await discovery.runningApplications()
        runningApplications = discovered
            .filter { $0.state != .terminated }
            .map {
                SessionApplication(
                    identity: $0.identity,
                    displayName: $0.displayName,
                    version: Bundle(url: $0.identity.bundleURL)?
                        .object(forInfoDictionaryKey: "CFBundleShortVersionString")
                        as? String
                )
            }
            .sorted {
                $0.displayName.localizedStandardCompare($1.displayName)
                    == .orderedAscending
            }
        selectedApplications = selectedApplications.intersection(
            Set(runningApplications.map(\.identity))
        )
    }

    private func refreshState() async {
        let newState = await engine.state()
        engineState = newState
        synchronizePrompt(with: newState)
        synchronizeShortcut(with: newState)
        if let session = newState.session,
           [.completed, .cancelled].contains(session.status),
           selectedResult?.session.id != session.id {
            selectedResult = try? await engine.result(sessionID: session.id)
        }
    }

    private func synchronizePrompt(with state: ControlledTestEngineState) {
        promptController.update(state: state) { [weak self] in
            self?.beginCurrentRound()
        }
    }

    private func synchronizeShortcut(with state: ControlledTestEngineState) {
        guard let session = state.session,
              ![.completed, .cancelled, .failed].contains(session.status),
              !state.recoveryRequired,
              session.controlledTestMode == .manualGuided,
              let choice = session.controlledTestConfiguration?.shortcut,
              choice != .none
        else {
            shortcutMonitor.unregister()
            configuredShortcut = nil
            configuredSessionID = nil
            return
        }
        guard configuredShortcut != choice || configuredSessionID != session.id else {
            return
        }
        let registered = shortcutMonitor.configure(choice) { [weak self] in
            guard self?.engineState.currentRound?.status == .pending else { return }
            self?.beginCurrentRound()
        }
        if !registered {
            errorMessage =
                "That global shortcut is already in use. The compact prompt remains available."
        }
        configuredShortcut = choice
        configuredSessionID = session.id
    }

    private func perform(
        _ operation: @escaping @MainActor () async throws -> Void
    ) {
        guard !isWorking else { return }
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try await operation()
            } catch {
                errorMessage = error.localizedDescription
            }
            await refreshState()
        }
    }

    private func resetDraft() {
        sessionName = ""
        note = ""
        selectedApplications = []
        controlledTestMode = .manualGuided
        measuredDuration = 30
        warmUpDuration = 0
        roundCount = 1
        shortcut = .none
    }
}

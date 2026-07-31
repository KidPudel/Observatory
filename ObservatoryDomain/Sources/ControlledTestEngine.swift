import Foundation

public actor ControlledTestEngine {
    private let persistence: any SessionPersisting
    private let sampler: any SessionMetricSampling
    private let storage: any StorageRootAccessing
    private let clock: any ObservatoryClock
    private let activation: (any ApplicationActivating)?
    private let summaryCalculator = SessionSummaryCalculator()

    private var session: MonitoringSession?
    private var rounds: [SessionRound] = []
    private var samples: [SessionMetricSample] = []
    private var summaries: [ApplicationResultSummary] = []
    private var timingTask: Task<Void, Never>?
    private var remainingDuration: TimeInterval?
    private var recoveryRequired = false
    private var notice: String?

    public init(
        persistence: any SessionPersisting,
        sampler: any SessionMetricSampling,
        storage: any StorageRootAccessing,
        clock: any ObservatoryClock,
        activation: (any ApplicationActivating)? = nil
    ) {
        self.persistence = persistence
        self.sampler = sampler
        self.storage = storage
        self.clock = clock
        self.activation = activation
    }

    deinit {
        timingTask?.cancel()
    }

    public func state() -> ControlledTestEngineState {
        ControlledTestEngineState(
            session: session,
            rounds: rounds,
            summaries: summaries,
            currentRound: activeOrNextRound,
            remainingDuration: remainingDuration,
            recoveryRequired: recoveryRequired,
            notice: notice
        )
    }

    public func restoreUnfinishedSession() async throws {
        guard session == nil else { return }
        guard let restored = try await persistence.unfinishedControlledSession()
        else {
            return
        }

        session = restored
        rounds = try await persistence.rounds(sessionID: restored.id)
        samples = try await persistence.samples(sessionID: restored.id)
        summaries = try await persistence.summaries(sessionID: restored.id)

        let now = await clock.now
        for index in rounds.indices
        where [.activating, .warmingUp, .recording].contains(rounds[index].status) {
            rounds[index] = rounds[index].updating(
                status: .interrupted,
                endedAt: now,
                interruptionReason: "Observatory quit before this round finished."
            )
            try await persistence.saveRound(rounds[index])
        }
        if [.activating, .warmingUp, .recording].contains(restored.status) {
            session = restored.updating(status: .paused, at: now)
            try await persistence.saveSession(session!)
        }
        recoveryRequired = true
    }

    public func acceptRecovery() {
        recoveryRequired = false
        notice = "The unfinished test was recovered. Completed samples are intact."
    }

    @discardableResult
    public func createSession(
        name: String,
        note: String,
        applications: [SessionApplication],
        configuration: ControlledTestConfiguration,
        mode: ControlledTestMode = .manualGuided
    ) async throws -> MonitoringSession {
        guard (1...4).contains(applications.count) else {
            throw ControlledTestEngineError.invalidApplicationCount
        }
        guard configuration.isValid else {
            throw ControlledTestEngineError.invalidConfiguration
        }
        guard timingTask == nil, session == nil,
              try await persistence.unfinishedControlledSession() == nil
        else {
            throw ControlledTestEngineError.activeControlledTest
        }

        let createdAt = await clock.now
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedName = trimmedName.isEmpty
            ? applications.map(\.displayName).joined(separator: " vs ")
            : trimmedName
        let directory = try await storage.sessionDirectory(
            named: resolvedName,
            createdAt: createdAt
        )
        let newSession = MonitoringSession(
            name: resolvedName,
            kind: .controlledTest,
            status: .planned,
            context: .metricsOnly,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            controlledTestMode: mode,
            manualConfiguration: configuration,
            applications: applications,
            assetDirectoryPath: directory.path,
            createdAt: createdAt
        )

        do {
            try await persistence.saveSession(newSession)
            var sequence = 0
            var newRounds: [SessionRound] = []
            for roundNumber in 1...configuration.roundCount {
                for application in applications {
                    sequence += 1
                    let round = SessionRound(
                        sessionID: newSession.id,
                        application: application,
                        roundNumber: roundNumber,
                        sequenceNumber: sequence
                    )
                    try await persistence.saveRound(round)
                    newRounds.append(round)
                }
            }
            session = newSession
            rounds = newRounds
            samples = []
            summaries = []
            recoveryRequired = false
            notice = nil
            return newSession
        } catch {
            try? await storage.removeSessionDirectory(directory)
            throw error
        }
    }

    public func startNextRound() async throws {
        guard !recoveryRequired else {
            throw ControlledTestEngineError.recoveryDecisionRequired
        }
        guard let currentSession = session,
              let configuration = currentSession.controlledTestConfiguration
        else {
            throw ControlledTestEngineError.noSession
        }
        guard currentSession.controlledTestMode == .manualGuided else {
            throw ControlledTestEngineError.wrongControlledTestMode
        }
        guard timingTask == nil else {
            throw ControlledTestEngineError.roundAlreadyRunning
        }
        guard let index = nextPendingRoundIndex else {
            throw ControlledTestEngineError.noRoundAvailable
        }

        let now = await clock.now
        let roundStatus: SessionRoundStatus =
            configuration.warmUpDuration > 0 ? .warmingUp : .recording
        let sessionStatus: MonitoringSessionStatus =
            configuration.warmUpDuration > 0 ? .warmingUp : .recording
        rounds[index] = rounds[index].updating(
            status: roundStatus,
            startedAt: now,
            measuredAt: configuration.warmUpDuration == 0 ? now : nil
        )
        session = currentSession.updating(
            status: sessionStatus,
            at: now,
            startedAt: currentSession.startedAt ?? now
        )
        try await persistence.saveRound(rounds[index])
        try await persistence.saveSession(session!)
        remainingDuration = configuration.warmUpDuration
            + configuration.measuredDuration
        let roundID = rounds[index].id
        timingTask = Task { await record(roundID: roundID) }
    }

    public func startAutomaticSequence() async throws {
        guard !recoveryRequired else {
            throw ControlledTestEngineError.recoveryDecisionRequired
        }
        guard let currentSession = session,
              currentSession.controlledTestConfiguration != nil
        else {
            throw ControlledTestEngineError.noSession
        }
        guard currentSession.controlledTestMode == .automaticForegroundIdle else {
            throw ControlledTestEngineError.wrongControlledTestMode
        }
        guard activation != nil else {
            throw ControlledTestEngineError.activationServiceUnavailable
        }
        guard timingTask == nil else {
            throw ControlledTestEngineError.roundAlreadyRunning
        }
        guard nextPendingRoundIndex != nil else {
            throw ControlledTestEngineError.noRoundAvailable
        }

        timingTask = Task { await runAutomaticSequence() }
    }

    public func skipNextRound() async throws {
        guard timingTask == nil else {
            throw ControlledTestEngineError.roundAlreadyRunning
        }
        guard !recoveryRequired else {
            throw ControlledTestEngineError.recoveryDecisionRequired
        }
        guard session != nil else { throw ControlledTestEngineError.noSession }
        guard let index = nextPendingRoundIndex else {
            throw ControlledTestEngineError.noRoundAvailable
        }
        let now = await clock.now
        rounds[index] = rounds[index].updating(status: .skipped, endedAt: now)
        try await persistence.saveRound(rounds[index])
        try await advanceAfterRound(at: now)
    }

    public func retryRound(id: UUID) async throws {
        guard timingTask == nil else {
            throw ControlledTestEngineError.roundAlreadyRunning
        }
        guard let currentSession = session,
              let index = rounds.firstIndex(where: { $0.id == id })
        else {
            throw ControlledTestEngineError.noRoundAvailable
        }
        try await persistence.deleteSamples(roundID: id)
        samples.removeAll { $0.roundID == id }
        let old = rounds[index]
        rounds[index] = SessionRound(
            id: old.id,
            sessionID: old.sessionID,
            application: old.application,
            roundNumber: old.roundNumber,
            sequenceNumber: old.sequenceNumber
        )
        try await persistence.saveRound(rounds[index])
        session = reactivated(currentSession, at: await clock.now)
        try await persistence.saveSession(session!)
        summaries = summaryCalculator.summarize(
            session: session!,
            rounds: rounds,
            samples: samples
        )
        try await persistence.replaceSummaries(summaries, sessionID: currentSession.id)
        notice = "The round is ready to retry."
    }

    public func finishWithPartialResults() async throws {
        guard timingTask == nil else {
            throw ControlledTestEngineError.roundAlreadyRunning
        }
        guard session != nil else { throw ControlledTestEngineError.noSession }
        let now = await clock.now
        for index in rounds.indices where rounds[index].status == .pending {
            rounds[index] = rounds[index].updating(status: .skipped, endedAt: now)
            try await persistence.saveRound(rounds[index])
        }
        try await finalize(at: now)
    }

    public func cancel(preservingPartialResult: Bool) async throws {
        guard let currentSession = session else {
            throw ControlledTestEngineError.noSession
        }
        timingTask?.cancel()
        timingTask = nil
        remainingDuration = nil
        let now = await clock.now

        if preservingPartialResult {
            for index in rounds.indices
            where [.pending, .activating, .warmingUp, .recording]
                .contains(rounds[index].status) {
                rounds[index] = rounds[index].updating(
                    status: .cancelled,
                    endedAt: now
                )
                try await persistence.saveRound(rounds[index])
            }
            let cancelledSession = currentSession.updating(
                status: .cancelled,
                at: now,
                completedAt: now
            )
            let cancelledSummaries = summaryCalculator.summarize(
                session: cancelledSession,
                rounds: rounds,
                samples: samples
            )
            try await persistence.replaceSummaries(
                cancelledSummaries,
                sessionID: currentSession.id
            )
            try await persistence.saveSession(cancelledSession)
            session = cancelledSession
            summaries = cancelledSummaries
            do {
                try await writePortableSummary()
            } catch {
                notice = "The catalog result is complete, but session.json could not be updated."
            }
            notice = "The partial result was preserved."
        } else {
            let directory = currentSession.assetDirectoryPath.map {
                URL(fileURLWithPath: $0)
            }
            try await persistence.deleteSession(id: currentSession.id)
            if let directory {
                try? await storage.removeSessionDirectory(directory)
            }
            clear()
        }
    }

    public func closeCurrentSession() {
        guard timingTask == nil else { return }
        clear()
    }

    public func result(sessionID: UUID) async throws -> ControlledTestResult? {
        guard let loadedSession = try await persistence.session(id: sessionID) else {
            return nil
        }
        return ControlledTestResult(
            session: loadedSession,
            rounds: try await persistence.rounds(sessionID: sessionID),
            samples: try await persistence.samples(sessionID: sessionID),
            summaries: try await persistence.summaries(sessionID: sessionID)
        )
    }

    public func recentSessions() async throws -> [MonitoringSession] {
        try await persistence.sessions()
    }

    public func deleteSavedSession(id: UUID) async throws {
        guard let savedSession = try await persistence.session(id: id) else {
            return
        }
        guard [.completed, .cancelled, .failed].contains(savedSession.status),
              timingTask == nil || session?.id != id else {
            throw ControlledTestEngineError.activeControlledTest
        }

        try await persistence.deleteSession(id: id)
        if let path = savedSession.assetDirectoryPath {
            try await storage.removeSessionDirectory(URL(fileURLWithPath: path))
        }
        if session?.id == id {
            clear()
        }
    }

    public func dismissNotice() {
        notice = nil
    }

    private var nextPendingRoundIndex: Int? {
        rounds.indices.first { rounds[$0].status == .pending }
    }

    private var activeOrNextRound: SessionRound? {
        rounds.first {
            [.activating, .warmingUp, .recording].contains($0.status)
        } ?? nextPendingRoundIndex.map { rounds[$0] }
    }

    private func runAutomaticSequence() async {
        do {
            while !Task.isCancelled, let index = nextPendingRoundIndex {
                let activated = try await activateRound(at: index)
                guard !Task.isCancelled else { return }
                guard activated else { continue }

                let roundID = try await beginAutomaticRound(at: index)
                await record(roundID: roundID, automaticSequence: true)

                guard !Task.isCancelled else { return }
                guard timingTask != nil, session?.status != .failed else { return }
            }
            guard !Task.isCancelled else { return }
            try await finalize(at: await clock.now)
        } catch is CancellationError {
            return
        } catch {
            await pauseForFailure(error, roundID: activeOrNextRound?.id)
        }
    }

    private func activateRound(at index: Int) async throws -> Bool {
        guard let currentSession = session, let activation else {
            throw ControlledTestEngineError.activationServiceUnavailable
        }
        let application = rounds[index].application
        let startedAt = await clock.now
        rounds[index] = rounds[index].updating(
            status: .activating,
            startedAt: startedAt
        )
        session = currentSession.updating(
            status: .activating,
            at: startedAt,
            startedAt: currentSession.startedAt ?? startedAt
        )
        try await persistence.saveRound(rounds[index])
        try await persistence.saveSession(session!)
        notice = "Bringing \(application.displayName) to the foreground…"

        var lastFailure = "macOS did not confirm it as frontmost."
        for attempt in 1...3 {
            do {
                try await activation.activate(application.identity)
            } catch {
                lastFailure = error.localizedDescription
            }

            for _ in 0..<15 {
                if await activation.isFrontmost(application.identity) {
                    notice = nil
                    return true
                }
                try await clock.sleep(for: .milliseconds(100))
            }
            if attempt < 3 {
                notice =
                    "Activation was not confirmed for \(application.displayName). Retrying \(attempt + 1) of 3…"
            }
        }

        let endedAt = await clock.now
        let reason =
            "Could not bring \(application.displayName) to the foreground after 3 attempts: \(lastFailure)"
        rounds[index] = rounds[index].updating(
            status: .failed,
            endedAt: endedAt,
            interruptionReason: reason
        )
        try await persistence.saveRound(rounds[index])
        session = session?.updating(status: .paused, at: endedAt)
        if let session {
            try await persistence.saveSession(session)
        }
        notice = "\(reason) Observatory continued with the next application."
        return false
    }

    private func beginAutomaticRound(at index: Int) async throws -> UUID {
        guard let currentSession = session,
              let configuration = currentSession.controlledTestConfiguration
        else {
            throw ControlledTestEngineError.noSession
        }
        let now = await clock.now
        let roundStatus: SessionRoundStatus =
            configuration.warmUpDuration > 0 ? .warmingUp : .recording
        let sessionStatus: MonitoringSessionStatus =
            configuration.warmUpDuration > 0 ? .warmingUp : .recording
        rounds[index] = rounds[index].updating(
            status: roundStatus,
            measuredAt: configuration.warmUpDuration == 0 ? now : nil
        )
        session = currentSession.updating(
            status: sessionStatus,
            at: now,
            startedAt: currentSession.startedAt ?? now
        )
        try await persistence.saveRound(rounds[index])
        try await persistence.saveSession(session!)
        remainingDuration =
            configuration.warmUpDuration + configuration.measuredDuration
        return rounds[index].id
    }

    private func record(
        roundID: UUID,
        automaticSequence: Bool = false
    ) async {
        guard let currentSession = session,
              let configuration = currentSession.controlledTestConfiguration,
              let initialIndex = rounds.firstIndex(where: { $0.id == roundID })
        else {
            timingTask = nil
            return
        }
        let application = rounds[initialIndex].application
        let totalDuration =
            configuration.warmUpDuration + configuration.measuredDuration
        let startedAt = await clock.now
        var lastTick = startedAt
        var nextTickAt = startedAt
        var excludedDiscontinuity: TimeInterval = 0

        do {
            while !Task.isCancelled {
                let capturedAt = await clock.now
                let gap = capturedAt.timeIntervalSince(lastTick)
                if gap > 2.5 {
                    excludedDiscontinuity += max(0, gap - 1)
                    nextTickAt = capturedAt
                    notice = "Timing paused across a sleep or clock discontinuity."
                }
                lastTick = capturedAt
                let elapsed = max(
                    0,
                    capturedAt.timeIntervalSince(startedAt) - excludedDiscontinuity
                )
                if elapsed >= totalDuration {
                    break
                }

                let isWarmUp = elapsed < configuration.warmUpDuration
                try await updatePhaseIfNeeded(
                    roundID: roundID,
                    isWarmUp: isWarmUp,
                    at: capturedAt
                )
                remainingDuration = max(0, totalDuration - elapsed)

                let readings = await sampler.readings(
                    for: [application.identity],
                    sessionID: currentSession.id,
                    at: capturedAt
                )
                guard let reading = readings.first(where: {
                    $0.application == application.identity
                }) else {
                    try await interruptRound(
                        id: roundID,
                        reason: "\(application.displayName) is no longer running.",
                        at: capturedAt,
                        automaticSequence: automaticSequence
                    )
                    return
                }
                let sample = SessionMetricSample(
                    sessionID: currentSession.id,
                    roundID: roundID,
                    application: application.identity,
                    capturedAt: reading.capturedAt,
                    elapsed: max(0, elapsed - configuration.warmUpDuration),
                    isWarmUp: isWarmUp,
                    state: reading.state,
                    metrics: reading.metrics,
                    isPartial: reading.isPartial
                )
                try await persistence.saveSample(sample)
                samples.append(sample)

                nextTickAt = nextTickAt.addingTimeInterval(1)
                let workFinishedAt = await clock.now
                let delay = nextTickAt.timeIntervalSince(workFinishedAt)
                if delay > 0 {
                    try await clock.sleep(for: .seconds(delay))
                } else {
                    nextTickAt = workFinishedAt
                }
            }
            guard !Task.isCancelled else { return }
            try await completeRound(
                id: roundID,
                at: await clock.now,
                automaticSequence: automaticSequence
            )
        } catch is CancellationError {
            return
        } catch {
            await pauseForFailure(error, roundID: roundID)
        }
    }

    private func updatePhaseIfNeeded(
        roundID: UUID,
        isWarmUp: Bool,
        at date: Date
    ) async throws {
        guard !isWarmUp,
              let index = rounds.firstIndex(where: { $0.id == roundID }),
              rounds[index].status == .warmingUp,
              let currentSession = session
        else {
            return
        }
        rounds[index] = rounds[index].updating(
            status: .recording,
            measuredAt: date
        )
        session = currentSession.updating(status: .recording, at: date)
        try await persistence.saveRound(rounds[index])
        try await persistence.saveSession(session!)
    }

    private func completeRound(
        id: UUID,
        at date: Date,
        automaticSequence: Bool
    ) async throws {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index] = rounds[index].updating(status: .completed, endedAt: date)
        try await persistence.saveRound(rounds[index])
        remainingDuration = nil
        if !automaticSequence {
            timingTask = nil
            try await advanceAfterRound(at: date)
        }
    }

    private func interruptRound(
        id: UUID,
        reason: String,
        at date: Date,
        automaticSequence: Bool
    ) async throws {
        guard let index = rounds.firstIndex(where: { $0.id == id }) else { return }
        rounds[index] = rounds[index].updating(
            status: .interrupted,
            endedAt: date,
            interruptionReason: reason
        )
        try await persistence.saveRound(rounds[index])
        remainingDuration = nil
        notice = reason
        if !automaticSequence {
            timingTask = nil
            try await advanceAfterRound(at: date)
        }
    }

    private func advanceAfterRound(at date: Date) async throws {
        guard let currentSession = session else { return }
        if nextPendingRoundIndex == nil {
            try await finalize(at: date)
        } else {
            session = currentSession.updating(status: .paused, at: date)
            try await persistence.saveSession(session!)
        }
    }

    private func finalize(at date: Date) async throws {
        guard let currentSession = session else { return }
        let completedSession = currentSession.updating(
            status: .completed,
            at: date,
            completedAt: date
        )
        let completedSummaries = summaryCalculator.summarize(
            session: completedSession,
            rounds: rounds,
            samples: samples
        )
        try await persistence.replaceSummaries(
            completedSummaries,
            sessionID: currentSession.id
        )
        try await persistence.saveSession(completedSession)
        session = completedSession
        summaries = completedSummaries
        do {
            try await writePortableSummary()
        } catch {
            notice = "The catalog result is complete, but session.json could not be updated."
        }
        timingTask = nil
        remainingDuration = nil
    }

    private func writePortableSummary() async throws {
        guard let currentSession = session,
              let path = currentSession.assetDirectoryPath
        else {
            return
        }
        try await storage.writeSummary(
            ControlledTestResult(
                session: currentSession,
                rounds: rounds,
                samples: [],
                summaries: summaries
            ),
            to: URL(fileURLWithPath: path)
        )
    }

    private func pauseForFailure(_ error: Error, roundID: UUID) async {
        timingTask = nil
        remainingDuration = nil
        let now = await clock.now
        if let index = rounds.firstIndex(where: { $0.id == roundID }) {
            rounds[index] = rounds[index].updating(
                status: .interrupted,
                endedAt: now,
                interruptionReason: "Recording paused because data could not be saved."
            )
            try? await persistence.saveRound(rounds[index])
        }
        if let currentSession = session {
            session = currentSession.updating(status: .paused, at: now)
            try? await persistence.saveSession(session!)
        }
        notice = "Recording paused because data could not be saved: \(error.localizedDescription)"
    }

    private func pauseForFailure(_ error: Error, roundID: UUID?) async {
        guard let roundID else {
            timingTask = nil
            remainingDuration = nil
            let now = await clock.now
            if let currentSession = session {
                session = currentSession.updating(status: .failed, at: now)
                try? await persistence.saveSession(session!)
            }
            notice = "The automatic test stopped: \(error.localizedDescription)"
            return
        }
        await pauseForFailure(error, roundID: roundID)
    }

    private func reactivated(
        _ currentSession: MonitoringSession,
        at date: Date
    ) -> MonitoringSession {
        MonitoringSession(
            id: currentSession.id,
            name: currentSession.name,
            kind: currentSession.kind,
            status: .paused,
            context: currentSession.context,
            note: currentSession.note,
            controlledTestMode: currentSession.controlledTestMode,
            manualConfiguration: currentSession.controlledTestConfiguration,
            applications: currentSession.applications,
            assetDirectoryPath: currentSession.assetDirectoryPath,
            systemVersion: currentSession.systemVersion,
            createdAt: currentSession.createdAt,
            updatedAt: date,
            startedAt: currentSession.startedAt,
            completedAt: nil
        )
    }

    private func clear() {
        session = nil
        rounds = []
        samples = []
        summaries = []
        timingTask = nil
        remainingDuration = nil
        recoveryRequired = false
        notice = nil
    }
}

import AppKit
import Foundation
import ObservatoryDomain

struct SystemObservatoryClock: ObservatoryClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    init() {
        origin = clock.now
    }

    var now: Date {
        get async { Date() }
    }

    var monotonicNow: Duration {
        get async { origin.duration(to: clock.now) }
    }

    func sleep(for duration: Duration) async throws {
        try await Task.sleep(for: duration)
    }
}

enum ApplicationActivationError: LocalizedError {
    case notRunning
    case requestRejected

    var errorDescription: String? {
        switch self {
        case .notRunning:
            "The application is no longer running."
        case .requestRejected:
            "macOS rejected the activation request."
        }
    }
}

actor MacOSApplicationActivation: ApplicationActivating {
    func activate(_ application: ApplicationIdentity) async throws {
        try await Self.requestActivation(for: application)
    }

    @MainActor
    private static func requestActivation(
        for application: ApplicationIdentity
    ) async throws {
        guard let runningApplication = runningApplication(for: application) else {
            throw ApplicationActivationError.notRunning
        }
        if runningApplication.activate(options: [.activateAllWindows]) {
            return
        }

        try await requestWorkspaceActivation(at: application.bundleURL)
    }

    private nonisolated static func requestWorkspaceActivation(
        at applicationURL: URL
    ) async throws {
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            configuration.addsToRecentItems = false
            NSWorkspace.shared.openApplication(
                at: applicationURL,
                configuration: configuration
            ) { reopenedApplication, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if reopenedApplication == nil {
                    continuation.resume(
                        throwing: ApplicationActivationError.requestRejected
                    )
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func isFrontmost(_ application: ApplicationIdentity) async -> Bool {
        await MainActor.run {
            guard let frontmost = NSWorkspace.shared.frontmostApplication else {
                return false
            }
            return Self.matches(frontmost, identity: application)
        }
    }

    @MainActor
    private static func runningApplication(
        for identity: ApplicationIdentity
    ) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first {
            matches($0, identity: identity)
        }
    }

    @MainActor
    private static func matches(
        _ application: NSRunningApplication,
        identity: ApplicationIdentity
    ) -> Bool {
        application.bundleIdentifier == identity.bundleIdentifier
            && application.bundleURL?.standardizedFileURL
                == identity.bundleURL.standardizedFileURL
    }
}

actor LocalSessionStorage: StorageRootAccessing {
    private let recordingsRoot: URL
    private let fileManager: FileManager

    init(recordingsRoot: URL, fileManager: FileManager = .default) {
        self.recordingsRoot = recordingsRoot
        self.fileManager = fileManager
    }

    func sessionDirectory(named name: String, createdAt: Date) throws -> URL {
        let sessionsRoot = recordingsRoot.appending(
            path: "Sessions",
            directoryHint: .isDirectory
        )
        try fileManager.createDirectory(
            at: sessionsRoot,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        let timestamp = formatter.string(from: createdAt)
        let baseName = "\(timestamp) — \(sanitize(name))"
        var candidate = sessionsRoot.appending(
            path: baseName,
            directoryHint: .isDirectory
        )
        var suffix = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = sessionsRoot.appending(
                path: "\(baseName) \(suffix)",
                directoryHint: .isDirectory
            )
            suffix += 1
        }

        try fileManager.createDirectory(
            at: candidate,
            withIntermediateDirectories: false
        )
        return candidate
    }

    func writeSummary(_ result: ControlledTestResult, to directory: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let destination = directory.appending(path: "session.json")
        let temporary = directory.appending(path: ".session-\(UUID().uuidString).json")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    func removeSessionDirectory(_ directory: URL) throws {
        guard directory.deletingLastPathComponent().lastPathComponent == "Sessions"
        else {
            return
        }
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    private func sanitize(_ name: String) -> String {
        let forbidden = CharacterSet(charactersIn: "/:\\?%*|\"<>")
            .union(.controlCharacters)
        let components = name.components(separatedBy: forbidden)
        let cleaned = components
            .joined(separator: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(cleaned.prefix(80)).isEmpty
            ? "Untitled test"
            : String(cleaned.prefix(80))
    }
}

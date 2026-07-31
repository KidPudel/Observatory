import Foundation

public struct ApplicationIdentity: Codable, Hashable, Sendable {
    public let bundleIdentifier: String
    public let bundleURL: URL

    public init(bundleIdentifier: String, bundleURL: URL) {
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
    }
}

public struct DiscoveredApplication: Codable, Equatable, Sendable {
    public let identity: ApplicationIdentity
    public let displayName: String
    public let primaryProcessIdentifier: Int32
    public let primaryProcess: ProcessIdentity?
    public let state: ApplicationState

    public init(
        identity: ApplicationIdentity,
        displayName: String,
        primaryProcessIdentifier: Int32,
        primaryProcess: ProcessIdentity? = nil,
        state: ApplicationState
    ) {
        self.identity = identity
        self.displayName = displayName
        self.primaryProcessIdentifier = primaryProcessIdentifier
        self.primaryProcess = primaryProcess
        self.state = state
    }
}

public enum ApplicationState: String, Codable, CaseIterable, Sendable {
    case frontmost
    case visible
    case hidden
    case idle
    case terminated
}

public struct ProcessIdentity: Codable, Hashable, Sendable {
    public let processIdentifier: Int32
    public let startTime: Date
    public let executablePath: String?

    public init(
        processIdentifier: Int32,
        startTime: Date,
        executablePath: String? = nil
    ) {
        self.processIdentifier = processIdentifier
        self.startTime = startTime
        self.executablePath = executablePath
    }
}

public enum SampleAvailability: String, Codable, Sendable {
    case available
    case inaccessible
    case exited
    case reusedIdentifier
}

public struct DiskCounters: Codable, Equatable, Sendable {
    public let bytesRead: UInt64
    public let bytesWritten: UInt64

    public init(bytesRead: UInt64, bytesWritten: UInt64) {
        self.bytesRead = bytesRead
        self.bytesWritten = bytesWritten
    }
}

public struct ProcessCounters: Codable, Equatable, Sendable {
    public let cpuTimeNanoseconds: UInt64
    public let physicalMemoryBytes: UInt64
    public let disk: DiskCounters
    public let wakeups: UInt64
    public let threadCount: Int?

    public init(
        cpuTimeNanoseconds: UInt64,
        physicalMemoryBytes: UInt64,
        disk: DiskCounters,
        wakeups: UInt64,
        threadCount: Int?
    ) {
        self.cpuTimeNanoseconds = cpuTimeNanoseconds
        self.physicalMemoryBytes = physicalMemoryBytes
        self.disk = disk
        self.wakeups = wakeups
        self.threadCount = threadCount
    }
}

public struct RawProcessSample: Codable, Equatable, Sendable {
    public let process: ProcessIdentity
    public let capturedAt: Date
    public let monotonicTimeNanoseconds: UInt64
    public let availability: SampleAvailability
    public let counters: ProcessCounters?

    public init(
        process: ProcessIdentity,
        capturedAt: Date,
        monotonicTimeNanoseconds: UInt64,
        availability: SampleAvailability,
        counters: ProcessCounters? = nil
    ) {
        self.process = process
        self.capturedAt = capturedAt
        self.monotonicTimeNanoseconds = monotonicTimeNanoseconds
        self.availability = availability
        self.counters = counters
    }
}

public struct ProcessSample: Codable, Equatable, Sendable {
    public let process: ProcessIdentity
    public let capturedAt: Date
    public let availability: SampleAvailability
    public let intervalSeconds: Double?
    public let cpuCoreUsage: Double?
    public let physicalMemoryBytes: UInt64?
    public let disk: DiskCounters?
    public let diskReadBytesPerSecond: Double?
    public let diskWriteBytesPerSecond: Double?
    public let wakeups: UInt64?
    public let wakeupsPerSecond: Double?
    public let threadCount: Int?

    public init(
        process: ProcessIdentity,
        capturedAt: Date,
        availability: SampleAvailability,
        intervalSeconds: Double? = nil,
        cpuCoreUsage: Double? = nil,
        physicalMemoryBytes: UInt64? = nil,
        disk: DiskCounters? = nil,
        diskReadBytesPerSecond: Double? = nil,
        diskWriteBytesPerSecond: Double? = nil,
        wakeups: UInt64? = nil,
        wakeupsPerSecond: Double? = nil,
        threadCount: Int? = nil
    ) {
        self.process = process
        self.capturedAt = capturedAt
        self.availability = availability
        self.intervalSeconds = intervalSeconds
        self.cpuCoreUsage = cpuCoreUsage
        self.physicalMemoryBytes = physicalMemoryBytes
        self.disk = disk
        self.diskReadBytesPerSecond = diskReadBytesPerSecond
        self.diskWriteBytesPerSecond = diskWriteBytesPerSecond
        self.wakeups = wakeups
        self.wakeupsPerSecond = wakeupsPerSecond
        self.threadCount = threadCount
    }
}

public enum MonitoringSessionKind: String, Codable, CaseIterable, Sendable {
    case controlledTest
    case backgroundObservation
}

public enum MonitoringSessionStatus: String, Codable, CaseIterable, Sendable {
    case planned
    case activating
    case warmingUp
    case recording
    case paused
    case completed
    case cancelled
    case failed
}

public enum ControlledTestContext: String, Codable, CaseIterable, Sendable {
    case metricsOnly
}

public struct MonitoringSession: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let kind: MonitoringSessionKind
    public let status: MonitoringSessionStatus
    public let context: ControlledTestContext
    public let note: String
    public let controlledTestMode: ControlledTestMode?
    public let manualConfiguration: ControlledTestConfiguration?
    public let applications: [SessionApplication]
    public let assetDirectoryPath: String?
    public let systemVersion: String
    public let createdAt: Date
    public let updatedAt: Date
    public let startedAt: Date?
    public let completedAt: Date?

    public var controlledTestConfiguration: ControlledTestConfiguration? {
        manualConfiguration
    }

    public init(
        id: UUID = UUID(),
        name: String,
        kind: MonitoringSessionKind,
        status: MonitoringSessionStatus = .planned,
        context: ControlledTestContext = .metricsOnly,
        note: String = "",
        controlledTestMode: ControlledTestMode? = nil,
        manualConfiguration: ControlledTestConfiguration? = nil,
        applications: [SessionApplication] = [],
        assetDirectoryPath: String? = nil,
        systemVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        createdAt: Date,
        updatedAt: Date? = nil,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.status = status
        self.context = context
        self.note = note
        self.controlledTestMode = controlledTestMode
        self.manualConfiguration = manualConfiguration
        self.applications = applications
        self.assetDirectoryPath = assetDirectoryPath
        self.systemVersion = systemVersion
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
    }

    public func updating(
        status: MonitoringSessionStatus,
        at date: Date,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) -> MonitoringSession {
        MonitoringSession(
            id: id,
            name: name,
            kind: kind,
            status: status,
            context: context,
            note: note,
            controlledTestMode: controlledTestMode,
            manualConfiguration: manualConfiguration,
            applications: applications,
            assetDirectoryPath: assetDirectoryPath,
            systemVersion: systemVersion,
            createdAt: createdAt,
            updatedAt: date,
            startedAt: startedAt ?? self.startedAt,
            completedAt: completedAt ?? self.completedAt
        )
    }
}

public enum RedactedInputActivity: Codable, Equatable, Sendable {
    case typedCharacterCount(count: Int, occurredAt: Date)
    case shortcut(modifiers: [String], key: String, occurredAt: Date)
    case namedKey(name: String, occurredAt: Date)
}

public struct CaptureRequest: Codable, Equatable, Sendable {
    public let sessionID: UUID
    public let application: ApplicationIdentity
    public let spikeID: UUID

    public init(sessionID: UUID, application: ApplicationIdentity, spikeID: UUID) {
        self.sessionID = sessionID
        self.application = application
        self.spikeID = spikeID
    }
}

public struct CapturedAsset: Codable, Equatable, Sendable {
    public let relativePath: String
    public let capturedAt: Date

    public init(relativePath: String, capturedAt: Date) {
        self.relativePath = relativePath
        self.capturedAt = capturedAt
    }
}

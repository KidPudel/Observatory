import Foundation

public struct DiscoveredProcess: Codable, Equatable, Sendable {
    public let identity: ProcessIdentity
    public let parentProcessIdentifier: Int32?
    public let responsibleProcessIdentifier: Int32?
    public let bundleIdentifier: String?

    public init(
        identity: ProcessIdentity,
        parentProcessIdentifier: Int32? = nil,
        responsibleProcessIdentifier: Int32? = nil,
        bundleIdentifier: String? = nil
    ) {
        self.identity = identity
        self.parentProcessIdentifier = parentProcessIdentifier
        self.responsibleProcessIdentifier = responsibleProcessIdentifier
        self.bundleIdentifier = bundleIdentifier
    }
}

public enum GroupingConfidence: Int, Codable, Comparable, Sendable {
    case unassigned = 0
    case low = 1
    case medium = 2
    case high = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

public enum OwnershipEvidence: Codable, Equatable, Hashable, Sendable {
    case manualInclude
    case primaryProcess
    case executableInsideBundle
    case responsibleProcess
    case descendantOfPrimary
    case relatedBundleIdentifier
    case nameSimilarity
}

public enum ProcessRuleMatcher: Codable, Equatable, Hashable, Sendable {
    case executablePath(String)
    case bundleIdentifier(String)
}

public enum GroupingRuleAction: String, Codable, Sendable {
    case include
    case exclude
}

public enum GroupingRuleScope: Codable, Equatable, Sendable {
    case persistent
    case session(UUID)
}

public struct GroupingRule: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let application: ApplicationIdentity
    public let matcher: ProcessRuleMatcher
    public let action: GroupingRuleAction
    public let scope: GroupingRuleScope

    public init(
        id: UUID = UUID(),
        application: ApplicationIdentity,
        matcher: ProcessRuleMatcher,
        action: GroupingRuleAction,
        scope: GroupingRuleScope = .persistent
    ) {
        self.id = id
        self.application = application
        self.matcher = matcher
        self.action = action
        self.scope = scope
    }
}

public struct ProcessOwnership: Codable, Equatable, Sendable {
    public let process: ProcessIdentity
    public let application: ApplicationIdentity?
    public let confidence: GroupingConfidence
    public let evidence: [OwnershipEvidence]
    public let conflictingApplications: [ApplicationIdentity]

    public init(
        process: ProcessIdentity,
        application: ApplicationIdentity?,
        confidence: GroupingConfidence,
        evidence: [OwnershipEvidence],
        conflictingApplications: [ApplicationIdentity] = []
    ) {
        self.process = process
        self.application = application
        self.confidence = confidence
        self.evidence = evidence
        self.conflictingApplications = conflictingApplications
    }
}

public struct GroupedProcessMetrics: Codable, Equatable, Sendable {
    public let cpuCoreUsage: Double?
    public let physicalMemoryBytes: UInt64?
    public let diskReadBytesPerSecond: Double?
    public let diskWriteBytesPerSecond: Double?
    public let wakeupsPerSecond: Double?
    public let processCount: Int
    public let threadCount: Int?
    public let unavailableProcessCount: Int

    public init(
        cpuCoreUsage: Double?,
        physicalMemoryBytes: UInt64?,
        diskReadBytesPerSecond: Double?,
        diskWriteBytesPerSecond: Double?,
        wakeupsPerSecond: Double?,
        processCount: Int,
        threadCount: Int?,
        unavailableProcessCount: Int
    ) {
        self.cpuCoreUsage = cpuCoreUsage
        self.physicalMemoryBytes = physicalMemoryBytes
        self.diskReadBytesPerSecond = diskReadBytesPerSecond
        self.diskWriteBytesPerSecond = diskWriteBytesPerSecond
        self.wakeupsPerSecond = wakeupsPerSecond
        self.processCount = processCount
        self.threadCount = threadCount
        self.unavailableProcessCount = unavailableProcessCount
    }
}

public struct ApplicationGroupSnapshot: Codable, Equatable, Sendable {
    public let application: DiscoveredApplication
    public let members: [ProcessOwnership]
    public let confidence: GroupingConfidence
    public let metrics: GroupedProcessMetrics

    public init(
        application: DiscoveredApplication,
        members: [ProcessOwnership],
        confidence: GroupingConfidence,
        metrics: GroupedProcessMetrics
    ) {
        self.application = application
        self.members = members
        self.confidence = confidence
        self.metrics = metrics
    }
}

public struct GroupingResult: Codable, Equatable, Sendable {
    public let groups: [ApplicationGroupSnapshot]
    public let ownerships: [ProcessOwnership]

    public init(groups: [ApplicationGroupSnapshot], ownerships: [ProcessOwnership]) {
        self.groups = groups
        self.ownerships = ownerships
    }
}

public struct ApplicationGrouper: Sendable {
    public private(set) var rules: [GroupingRule]

    public init(rules: [GroupingRule] = []) {
        self.rules = rules
    }

    public mutating func setRule(_ rule: GroupingRule) {
        rules.removeAll {
            $0.application == rule.application
                && $0.matcher == rule.matcher
                && $0.scope == rule.scope
        }
        rules.append(rule)
    }

    public mutating func removeRule(id: UUID) {
        rules.removeAll { $0.id == id }
    }

    public mutating func resetRules(for application: ApplicationIdentity? = nil) {
        if let application {
            rules.removeAll { $0.application == application }
        } else {
            rules.removeAll()
        }
    }

    public func group(
        applications: [DiscoveredApplication],
        processes: [DiscoveredProcess],
        samples: [ProcessSample] = [],
        sessionID: UUID? = nil
    ) -> GroupingResult {
        let uniqueProcesses = Dictionary(
            processes.map { ($0.identity.processIdentifier, $0) }
        ) { first, second in
            first.identity.startTime >= second.identity.startTime ? first : second
        }.values.sorted {
            $0.identity.processIdentifier < $1.identity.processIdentifier
        }
        let applicableRules = rules.filter { rule in
            switch rule.scope {
            case .persistent:
                true
            case let .session(ruleSessionID):
                ruleSessionID == sessionID
            }
        }
        let processByPID = Dictionary(
            uniqueProcesses.map { ($0.identity.processIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let applicationsByPrimaryPID = Dictionary(
            applications.map { ($0.primaryProcessIdentifier, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let normalizedBundlePaths = Dictionary(
            uniqueKeysWithValues: applications.map {
                (
                    $0.identity,
                    $0.identity.bundleURL
                        .resolvingSymlinksInPath()
                        .standardizedFileURL.path
                )
            }
        )
        let normalizedExecutablePaths = Dictionary(
            uniqueKeysWithValues: uniqueProcesses.map {
                (
                    $0.identity,
                    $0.identity.executablePath
                )
            }
        )
        let normalizedApplicationNames = Dictionary(
            uniqueKeysWithValues: applications.map {
                ($0.identity, normalizeName($0.displayName))
            }
        )
        let normalizedProcessNames = Dictionary(
            uniqueKeysWithValues: uniqueProcesses.map {
                (
                    $0.identity,
                    $0.identity.executablePath.map {
                        normalizeName($0.split(separator: "/").last.map(String.init) ?? $0)
                    }
                )
            }
        )
        let descendantApplications = Dictionary(
            uniqueKeysWithValues: uniqueProcesses.compactMap { process in
                nearestAncestorApplication(
                    for: process,
                    processByPID: processByPID,
                    applicationsByPrimaryPID: applicationsByPrimaryPID
                ).map { (process.identity, $0) }
            }
        )

        let ownerships = uniqueProcesses.map { process in
            ownership(
                for: process,
                applications: applications,
                applicationsByPrimaryPID: applicationsByPrimaryPID,
                rules: applicableRules,
                normalizedBundlePaths: normalizedBundlePaths,
                normalizedExecutablePaths: normalizedExecutablePaths,
                normalizedApplicationNames: normalizedApplicationNames,
                normalizedProcessNames: normalizedProcessNames,
                descendantApplication: descendantApplications[process.identity]
            )
        }
        let latestSamples = latestSamplesByProcess(samples)
        let groups = applications.map { application in
            let members = ownerships.filter { $0.application == application.identity }
            return ApplicationGroupSnapshot(
                application: application,
                members: members,
                confidence: members.map(\.confidence).min() ?? .unassigned,
                metrics: aggregate(members: members, samples: latestSamples)
            )
        }

        return GroupingResult(groups: groups, ownerships: ownerships)
    }

    public func applying(
        samples: [ProcessSample],
        to result: GroupingResult
    ) -> GroupingResult {
        let latestSamples = latestSamplesByProcess(samples)
        return GroupingResult(
            groups: result.groups.map { group in
                ApplicationGroupSnapshot(
                    application: group.application,
                    members: group.members,
                    confidence: group.confidence,
                    metrics: aggregate(
                        members: group.members,
                        samples: latestSamples
                    )
                )
            },
            ownerships: result.ownerships
        )
    }

    private func ownership(
        for process: DiscoveredProcess,
        applications: [DiscoveredApplication],
        applicationsByPrimaryPID: [Int32: DiscoveredApplication],
        rules: [GroupingRule],
        normalizedBundlePaths: [ApplicationIdentity: String],
        normalizedExecutablePaths: [ProcessIdentity: String?],
        normalizedApplicationNames: [ApplicationIdentity: String],
        normalizedProcessNames: [ProcessIdentity: String?],
        descendantApplication: ApplicationIdentity?
    ) -> ProcessOwnership {
        let matchingRules = rules.filter { matches($0.matcher, process: process) }
        let excluded = Set(
            matchingRules
                .filter { $0.action == .exclude }
                .map(\.application)
        )
        let included = Set(
            matchingRules
                .filter { $0.action == .include && !excluded.contains($0.application) }
                .map(\.application)
        )

        if !included.isEmpty {
            if included.count == 1, let application = included.first {
                return ProcessOwnership(
                    process: process.identity,
                    application: application,
                    confidence: .high,
                    evidence: [.manualInclude]
                )
            }
            return ProcessOwnership(
                process: process.identity,
                application: nil,
                confidence: .unassigned,
                evidence: [.manualInclude],
                conflictingApplications: sortedIdentities(included)
            )
        }

        var candidates: [ApplicationIdentity: Candidate] = [:]
        for application in applications where !excluded.contains(application.identity) {
            collectAutomaticEvidence(
                process: process,
                application: application,
                applicationsByPrimaryPID: applicationsByPrimaryPID,
                normalizedBundlePath: normalizedBundlePaths[application.identity],
                normalizedExecutablePath: normalizedExecutablePaths[process.identity] ?? nil,
                normalizedApplicationName: normalizedApplicationNames[application.identity],
                normalizedProcessName: normalizedProcessNames[process.identity] ?? nil,
                descendantApplication: descendantApplication,
                into: &candidates
            )
        }

        guard let highestScore = candidates.values.map(\.score).max() else {
            return ProcessOwnership(
                process: process.identity,
                application: nil,
                confidence: .unassigned,
                evidence: []
            )
        }

        let winners = candidates.filter { $0.value.score == highestScore }
        guard winners.count == 1, let winner = winners.first else {
            return ProcessOwnership(
                process: process.identity,
                application: nil,
                confidence: .unassigned,
                evidence: winnerEvidence(winners),
                conflictingApplications: sortedIdentities(Set(winners.keys))
            )
        }

        return ProcessOwnership(
            process: process.identity,
            application: winner.key,
            confidence: winner.value.confidence,
            evidence: winner.value.evidence.sorted(by: evidenceOrder)
        )
    }

    private func collectAutomaticEvidence(
        process: DiscoveredProcess,
        application: DiscoveredApplication,
        applicationsByPrimaryPID: [Int32: DiscoveredApplication],
        normalizedBundlePath: String?,
        normalizedExecutablePath: String?,
        normalizedApplicationName: String?,
        normalizedProcessName: String?,
        descendantApplication: ApplicationIdentity?,
        into candidates: inout [ApplicationIdentity: Candidate]
    ) {
        let isPrimaryProcess: Bool
        if let primaryProcess = application.primaryProcess {
            isPrimaryProcess = process.identity == primaryProcess
        } else {
            isPrimaryProcess =
                process.identity.processIdentifier == application.primaryProcessIdentifier
        }
        if isPrimaryProcess {
            add(
                application.identity,
                evidence: .primaryProcess,
                confidence: .high,
                score: 90,
                to: &candidates
            )
        }

        if executable(
            normalizedExecutablePath,
            isInsideBundlePath: normalizedBundlePath
        ) {
            add(
                application.identity,
                evidence: .executableInsideBundle,
                confidence: .high,
                score: 80,
                to: &candidates
            )
        }

        if let responsiblePID = process.responsibleProcessIdentifier,
           applicationsByPrimaryPID[responsiblePID]?.identity == application.identity {
            add(
                application.identity,
                evidence: .responsibleProcess,
                confidence: .medium,
                score: 60,
                to: &candidates
            )
        }

        if descendantApplication == application.identity {
            add(
                application.identity,
                evidence: .descendantOfPrimary,
                confidence: .medium,
                score: 50,
                to: &candidates
            )
        }

        if let processBundleIdentifier = process.bundleIdentifier {
            if processBundleIdentifier == application.identity.bundleIdentifier {
                add(
                    application.identity,
                    evidence: .relatedBundleIdentifier,
                    confidence: .high,
                    score: 75,
                    to: &candidates
                )
            } else if processBundleIdentifier.hasPrefix(
                application.identity.bundleIdentifier + "."
            ) {
                add(
                    application.identity,
                    evidence: .relatedBundleIdentifier,
                    confidence: .medium,
                    score: 40,
                    to: &candidates
                )
            }
        }

        if namesAreSimilar(
            processName: normalizedProcessName,
            applicationName: normalizedApplicationName
        ) {
            add(
                application.identity,
                evidence: .nameSimilarity,
                confidence: .low,
                score: 10,
                to: &candidates
            )
        }
    }

    private func add(
        _ application: ApplicationIdentity,
        evidence: OwnershipEvidence,
        confidence: GroupingConfidence,
        score: Int,
        to candidates: inout [ApplicationIdentity: Candidate]
    ) {
        var candidate = candidates[application] ?? Candidate()
        candidate.evidence.insert(evidence)
        if score > candidate.score {
            candidate.score = score
            candidate.confidence = confidence
        }
        candidates[application] = candidate
    }

    private func matches(_ matcher: ProcessRuleMatcher, process: DiscoveredProcess) -> Bool {
        switch matcher {
        case let .executablePath(path):
            process.identity.executablePath == path
        case let .bundleIdentifier(bundleIdentifier):
            process.bundleIdentifier == bundleIdentifier
        }
    }

    private func executable(
        _ executablePath: String?,
        isInsideBundlePath bundlePath: String?
    ) -> Bool {
        guard let executablePath, let bundlePath else { return false }
        return executablePath.hasPrefix(bundlePath + "/")
    }

    private func nearestAncestorApplication(
        for process: DiscoveredProcess,
        processByPID: [Int32: DiscoveredProcess],
        applicationsByPrimaryPID: [Int32: DiscoveredApplication]
    ) -> ApplicationIdentity? {
        var visited: Set<Int32> = [process.identity.processIdentifier]
        var parentPID = process.parentProcessIdentifier

        while let currentPID = parentPID, visited.insert(currentPID).inserted {
            if let application = applicationsByPrimaryPID[currentPID] {
                return application.identity
            }
            parentPID = processByPID[currentPID]?.parentProcessIdentifier
        }
        return nil
    }

    private func namesAreSimilar(
        processName: String?,
        applicationName: String?
    ) -> Bool {
        guard let processName, let applicationName else { return false }
        guard processName.count >= 3, applicationName.count >= 3 else { return false }
        return processName.contains(applicationName) || applicationName.contains(processName)
    }

    private func normalizeName(_ name: String) -> String {
        String(name.lowercased().unicodeScalars.filter(CharacterSet.alphanumerics.contains))
    }

    private func latestSamplesByProcess(
        _ samples: [ProcessSample]
    ) -> [ProcessIdentity: ProcessSample] {
        Dictionary(samples.map { ($0.process, $0) }) { first, second in
            first.capturedAt >= second.capturedAt ? first : second
        }
    }

    private func aggregate(
        members: [ProcessOwnership],
        samples: [ProcessIdentity: ProcessSample]
    ) -> GroupedProcessMetrics {
        let memberSamples = members.compactMap { samples[$0.process] }
        let available = memberSamples.filter { $0.availability == .available }
        let explicitlyNotLive = Set(
            memberSamples
                .filter { $0.availability == .exited || $0.availability == .reusedIdentifier }
                .map(\.process)
        )

        return GroupedProcessMetrics(
            cpuCoreUsage: sumDoubles(available.compactMap(\.cpuCoreUsage)),
            physicalMemoryBytes: sumUnsigned(available.compactMap(\.physicalMemoryBytes)),
            diskReadBytesPerSecond: sumDoubles(
                available.compactMap(\.diskReadBytesPerSecond)
            ),
            diskWriteBytesPerSecond: sumDoubles(
                available.compactMap(\.diskWriteBytesPerSecond)
            ),
            wakeupsPerSecond: sumDoubles(available.compactMap(\.wakeupsPerSecond)),
            processCount: members.count - explicitlyNotLive.count,
            threadCount: sumIntegers(available.compactMap(\.threadCount)),
            unavailableProcessCount: memberSamples.count - available.count
        )
    }

    private func sumDoubles(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +)
    }

    private func sumUnsigned(_ values: [UInt64]) -> UInt64? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0) { result, value in
            let (sum, overflow) = result.addingReportingOverflow(value)
            return overflow ? .max : sum
        }
    }

    private func sumIntegers(_ values: [Int]) -> Int? {
        values.isEmpty ? nil : values.reduce(0, +)
    }

    private func evidenceOrder(_ lhs: OwnershipEvidence, _ rhs: OwnershipEvidence) -> Bool {
        evidenceRank(lhs) > evidenceRank(rhs)
    }

    private func evidenceRank(_ evidence: OwnershipEvidence) -> Int {
        switch evidence {
        case .manualInclude: 7
        case .primaryProcess: 6
        case .executableInsideBundle: 5
        case .responsibleProcess: 4
        case .descendantOfPrimary: 3
        case .relatedBundleIdentifier: 2
        case .nameSimilarity: 1
        }
    }

    private func winnerEvidence(
        _ winners: [ApplicationIdentity: Candidate]
    ) -> [OwnershipEvidence] {
        Array(winners.values.reduce(into: Set<OwnershipEvidence>()) {
            $0.formUnion($1.evidence)
        }).sorted(by: evidenceOrder)
    }

    private func sortedIdentities(
        _ identities: Set<ApplicationIdentity>
    ) -> [ApplicationIdentity] {
        identities.sorted {
            if $0.bundleIdentifier == $1.bundleIdentifier {
                return $0.bundleURL.path < $1.bundleURL.path
            }
            return $0.bundleIdentifier < $1.bundleIdentifier
        }
    }
}

private struct Candidate {
    var score = 0
    var confidence = GroupingConfidence.unassigned
    var evidence: Set<OwnershipEvidence> = []
}

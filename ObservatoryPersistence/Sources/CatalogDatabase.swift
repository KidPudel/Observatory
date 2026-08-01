import Foundation
internal import GRDB
import ObservatoryDomain

public actor CatalogDatabase: GroupingRulePersisting, SessionPersisting {
    private let databaseQueue: DatabaseQueue

    public init(path: String) throws {
        databaseQueue = try DatabaseQueue(path: path)
        try Self.makeMigrator().migrate(databaseQueue)
    }

    public init(inMemory: Bool) throws {
        databaseQueue = try DatabaseQueue()
        try Self.makeMigrator().migrate(databaseQueue)
    }

    public func createSession(
        _ session: MonitoringSession,
        rounds: [SessionRound]
    ) throws {
        try databaseQueue.write { database in
            let terminalStatuses = [
                MonitoringSessionStatus.completed.rawValue,
                MonitoringSessionStatus.cancelled.rawValue,
                MonitoringSessionStatus.failed.rawValue
            ]
            let unfinishedExists = try SessionRecord
                .filter(
                    SessionRecord.Columns.kind
                        == MonitoringSessionKind.controlledTest.rawValue
                )
                .filter(!terminalStatuses.contains(SessionRecord.Columns.status))
                .fetchCount(database) > 0
            guard !unfinishedExists else {
                throw ControlledTestEngineError.activeControlledTest
            }

            try SessionRecord(session: session).save(database)
            try SessionPayloadRecord(session: session).save(database)
            for round in rounds {
                try SessionRoundRecord(round: round).save(database)
            }
        }
    }

    public func saveSession(_ session: MonitoringSession) throws {
        try databaseQueue.write { database in
            try SessionRecord(session: session).save(database)
            try SessionPayloadRecord(session: session).save(database)
        }
    }

    public func session(id: UUID) throws -> MonitoringSession? {
        try databaseQueue.read { database in
            if let payload = try SessionPayloadRecord.fetchOne(
                database,
                key: id.uuidString
            ) {
                return try payload.domainValue()
            }
            return try SessionRecord.fetchOne(database, key: id.uuidString)?.domainValue
        }
    }

    public func sessions() throws -> [MonitoringSession] {
        try databaseQueue.read { database in
            let records = try SessionRecord
                .order(SessionRecord.Columns.createdAt.desc)
                .fetchAll(database)
            return try records.map { record in
                if let payload = try SessionPayloadRecord.fetchOne(
                    database,
                    key: record.id
                ) {
                    return try payload.domainValue()
                }
                return record.domainValue
            }
        }
    }

    public func unfinishedControlledSession() throws -> MonitoringSession? {
        try databaseQueue.read { database in
            let terminalStatuses = [
                MonitoringSessionStatus.completed.rawValue,
                MonitoringSessionStatus.cancelled.rawValue,
                MonitoringSessionStatus.failed.rawValue
            ]
            guard let record = try SessionRecord
                .filter(SessionRecord.Columns.kind == MonitoringSessionKind.controlledTest.rawValue)
                .filter(!terminalStatuses.contains(SessionRecord.Columns.status))
                .order(SessionRecord.Columns.updatedAt.desc)
                .fetchOne(database)
            else {
                return nil
            }
            if let payload = try SessionPayloadRecord.fetchOne(
                database,
                key: record.id
            ) {
                return try payload.domainValue()
            }
            return record.domainValue
        }
    }

    public func saveRound(_ round: SessionRound) throws {
        try databaseQueue.write { database in
            try SessionRoundRecord(round: round).save(database)
        }
    }

    public func rounds(sessionID: UUID) throws -> [SessionRound] {
        try databaseQueue.read { database in
            try SessionRoundRecord
                .filter(SessionRoundRecord.Columns.sessionID == sessionID.uuidString)
                .order(SessionRoundRecord.Columns.sequenceNumber)
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    public func saveSample(_ sample: SessionMetricSample) throws {
        try databaseQueue.write { database in
            try SessionMetricSampleRecord(sample: sample).insert(database)
        }
    }

    public func samples(sessionID: UUID) throws -> [SessionMetricSample] {
        try databaseQueue.read { database in
            let roundOrder = Dictionary(
                uniqueKeysWithValues: try SessionRoundRecord
                    .filter(SessionRoundRecord.Columns.sessionID == sessionID.uuidString)
                    .fetchAll(database)
                    .map { record in
                        let round = try record.domainValue()
                        return (round.id, round.sequenceNumber)
                    }
            )
            return try SessionMetricSampleRecord
                .filter(
                    SessionMetricSampleRecord.Columns.sessionID
                        == sessionID.uuidString
                )
                .fetchAll(database)
                .map { try $0.domainValue() }
                .sorted { lhs, rhs in
                    let lhsRound = roundOrder[lhs.roundID] ?? .max
                    let rhsRound = roundOrder[rhs.roundID] ?? .max
                    if lhsRound != rhsRound {
                        return lhsRound < rhsRound
                    }
                    if lhs.elapsed != rhs.elapsed {
                        return lhs.elapsed < rhs.elapsed
                    }
                    if lhs.application != rhs.application {
                        return lhs.application.bundleIdentifier
                            < rhs.application.bundleIdentifier
                    }
                    return lhs.capturedAt < rhs.capturedAt
                }
        }
    }

    public func replaceSummaries(
        _ summaries: [ApplicationResultSummary],
        sessionID: UUID
    ) throws {
        try databaseQueue.write { database in
            _ = try SessionSummaryRecord
                .filter(SessionSummaryRecord.Columns.sessionID == sessionID.uuidString)
                .deleteAll(database)
            for summary in summaries {
                try SessionSummaryRecord(summary: summary).insert(database)
            }
        }
    }

    public func summaries(sessionID: UUID) throws -> [ApplicationResultSummary] {
        try databaseQueue.read { database in
            try SessionSummaryRecord
                .filter(SessionSummaryRecord.Columns.sessionID == sessionID.uuidString)
                .order(SessionSummaryRecord.Columns.applicationName)
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    public func deleteSamples(roundID: UUID) throws {
        try databaseQueue.write { database in
            _ = try SessionMetricSampleRecord
                .filter(SessionMetricSampleRecord.Columns.roundID == roundID.uuidString)
                .deleteAll(database)
        }
    }

    public func deleteSession(id: UUID) throws {
        try databaseQueue.write { database in
            let sessionID = id.uuidString
            _ = try SessionMetricSampleRecord
                .filter(SessionMetricSampleRecord.Columns.sessionID == sessionID)
                .deleteAll(database)
            _ = try SessionSummaryRecord
                .filter(SessionSummaryRecord.Columns.sessionID == sessionID)
                .deleteAll(database)
            _ = try SessionRoundRecord
                .filter(SessionRoundRecord.Columns.sessionID == sessionID)
                .deleteAll(database)
            _ = try SessionPayloadRecord.deleteOne(database, key: sessionID)
            _ = try SessionRecord.deleteOne(database, key: sessionID)
        }
    }

    public func saveGroupingRule(_ rule: GroupingRule) throws {
        try databaseQueue.write { database in
            try GroupingRuleRecord(rule: rule).save(database)
        }
    }

    public func groupingRules() throws -> [GroupingRule] {
        try databaseQueue.read { database in
            try GroupingRuleRecord
                .order(GroupingRuleRecord.Columns.id)
                .fetchAll(database)
                .map { try $0.domainValue() }
        }
    }

    public func deleteGroupingRule(id: UUID) throws {
        try databaseQueue.write { database in
            _ = try GroupingRuleRecord.deleteOne(database, key: id.uuidString)
        }
    }

    public func resetGroupingRules(for application: ApplicationIdentity?) throws {
        try databaseQueue.write { database in
            if let application {
                _ = try GroupingRuleRecord
                    .filter(
                        GroupingRuleRecord.Columns.applicationBundleIdentifier
                            == application.bundleIdentifier
                    )
                    .filter(
                        GroupingRuleRecord.Columns.applicationBundleURL
                            == application.bundleURL.absoluteString
                    )
                    .deleteAll(database)
            } else {
                _ = try GroupingRuleRecord.deleteAll(database)
            }
        }
    }

    public func appliedMigrations() throws -> [String] {
        let migrator = Self.makeMigrator()
        return try databaseQueue.read { database in
            try migrator.appliedMigrations(database)
        }
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1_create_session_catalog") { database in
            try database.create(table: SessionRecord.databaseTableName) { table in
                table.column(SessionRecord.Columns.id.name, .text).primaryKey()
                table.column(SessionRecord.Columns.name.name, .text).notNull()
                table.column(SessionRecord.Columns.kind.name, .text).notNull()
                table.column(SessionRecord.Columns.status.name, .text).notNull()
                table.column(SessionRecord.Columns.context.name, .text).notNull()
                table.column(SessionRecord.Columns.createdAt.name, .datetime).notNull()
            }
        }

        migrator.registerMigration("v2_create_grouping_rule_catalog") { database in
            try database.create(table: GroupingRuleRecord.databaseTableName) { table in
                table.column(GroupingRuleRecord.Columns.id.name, .text).primaryKey()
                table.column(
                    GroupingRuleRecord.Columns.applicationBundleIdentifier.name,
                    .text
                ).notNull()
                table.column(
                    GroupingRuleRecord.Columns.applicationBundleURL.name,
                    .text
                ).notNull()
                table.column(GroupingRuleRecord.Columns.payload.name, .blob).notNull()
            }
        }

        migrator.registerMigration("v3_create_manual_session_records") { database in
            try database.alter(table: SessionRecord.databaseTableName) { table in
                table.add(
                    column: SessionRecord.Columns.updatedAt.name,
                    .datetime
                ).notNull().defaults(to: Date(timeIntervalSince1970: 0))
            }

            try database.create(table: SessionPayloadRecord.databaseTableName) { table in
                table.column(SessionPayloadRecord.Columns.id.name, .text).primaryKey()
                table.column(SessionPayloadRecord.Columns.payload.name, .blob).notNull()
            }

            try database.create(table: SessionRoundRecord.databaseTableName) { table in
                table.column(SessionRoundRecord.Columns.id.name, .text).primaryKey()
                table.column(SessionRoundRecord.Columns.sessionID.name, .text).notNull()
                    .indexed()
                table.column(SessionRoundRecord.Columns.sequenceNumber.name, .integer)
                    .notNull()
                table.column(SessionRoundRecord.Columns.payload.name, .blob).notNull()
            }

            try database.create(
                table: SessionMetricSampleRecord.databaseTableName
            ) { table in
                table.column(SessionMetricSampleRecord.Columns.id.name, .text)
                    .primaryKey()
                table.column(SessionMetricSampleRecord.Columns.sessionID.name, .text)
                    .notNull().indexed()
                table.column(SessionMetricSampleRecord.Columns.roundID.name, .text)
                    .notNull().indexed()
                table.column(SessionMetricSampleRecord.Columns.capturedAt.name, .datetime)
                    .notNull()
                table.column(SessionMetricSampleRecord.Columns.payload.name, .blob)
                    .notNull()
            }

            try database.create(table: SessionSummaryRecord.databaseTableName) { table in
                table.column(SessionSummaryRecord.Columns.id.name, .text).primaryKey()
                table.column(SessionSummaryRecord.Columns.sessionID.name, .text)
                    .notNull().indexed()
                table.column(SessionSummaryRecord.Columns.applicationName.name, .text)
                    .notNull()
                table.column(SessionSummaryRecord.Columns.payload.name, .blob).notNull()
            }
        }

        return migrator
    }
}

private struct GroupingRuleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "groupingRule"

    enum Columns: String, ColumnExpression {
        case id
        case applicationBundleIdentifier
        case applicationBundleURL
        case payload
    }

    let id: String
    let applicationBundleIdentifier: String
    let applicationBundleURL: String
    let payload: Data

    init(rule: GroupingRule) throws {
        id = rule.id.uuidString
        applicationBundleIdentifier = rule.application.bundleIdentifier
        applicationBundleURL = rule.application.bundleURL.absoluteString
        payload = try JSONEncoder().encode(rule)
    }

    func domainValue() throws -> GroupingRule {
        try JSONDecoder().decode(GroupingRule.self, from: payload)
    }
}

private struct SessionRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "monitoringSession"

    enum Columns: String, ColumnExpression {
        case id
        case name
        case kind
        case status
        case context
        case createdAt
        case updatedAt
    }

    let id: String
    let name: String
    let kind: MonitoringSessionKind
    let status: MonitoringSessionStatus
    let context: ControlledTestContext
    let createdAt: Date
    let updatedAt: Date

    init(session: MonitoringSession) {
        id = session.id.uuidString
        name = session.name
        kind = session.kind
        status = session.status
        context = session.context
        createdAt = session.createdAt
        updatedAt = session.updatedAt
    }

    var domainValue: MonitoringSession {
        MonitoringSession(
            id: UUID(uuidString: id) ?? UUID(),
            name: name,
            kind: kind,
            status: status,
            context: context,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

private struct SessionPayloadRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "monitoringSessionPayload"

    enum Columns: String, ColumnExpression {
        case id
        case payload
    }

    let id: String
    let payload: Data

    init(session: MonitoringSession) throws {
        id = session.id.uuidString
        payload = try JSONEncoder.observatory.encode(session)
    }

    func domainValue() throws -> MonitoringSession {
        try JSONDecoder.observatory.decode(MonitoringSession.self, from: payload)
    }
}

private struct SessionRoundRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "monitoringSessionRound"

    enum Columns: String, ColumnExpression {
        case id
        case sessionID
        case sequenceNumber
        case payload
    }

    let id: String
    let sessionID: String
    let sequenceNumber: Int
    let payload: Data

    init(round: SessionRound) throws {
        id = round.id.uuidString
        sessionID = round.sessionID.uuidString
        sequenceNumber = round.sequenceNumber
        payload = try JSONEncoder.observatory.encode(round)
    }

    func domainValue() throws -> SessionRound {
        try JSONDecoder.observatory.decode(SessionRound.self, from: payload)
    }
}

private struct SessionMetricSampleRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "monitoringSessionMetricSample"

    enum Columns: String, ColumnExpression {
        case id
        case sessionID
        case roundID
        case capturedAt
        case payload
    }

    let id: String
    let sessionID: String
    let roundID: String
    let capturedAt: Date
    let payload: Data

    init(sample: SessionMetricSample) throws {
        id = sample.id.uuidString
        sessionID = sample.sessionID.uuidString
        roundID = sample.roundID.uuidString
        capturedAt = sample.capturedAt
        payload = try JSONEncoder.observatory.encode(sample)
    }

    func domainValue() throws -> SessionMetricSample {
        try JSONDecoder.observatory.decode(SessionMetricSample.self, from: payload)
    }
}

private struct SessionSummaryRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "monitoringSessionSummary"

    enum Columns: String, ColumnExpression {
        case id
        case sessionID
        case applicationName
        case payload
    }

    let id: String
    let sessionID: String
    let applicationName: String
    let payload: Data

    init(summary: ApplicationResultSummary) throws {
        id = summary.id.uuidString
        sessionID = summary.sessionID.uuidString
        applicationName = summary.application.displayName
        payload = try JSONEncoder.observatory.encode(summary)
    }

    func domainValue() throws -> ApplicationResultSummary {
        try JSONDecoder.observatory.decode(ApplicationResultSummary.self, from: payload)
    }
}

private extension JSONEncoder {
    static var observatory: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension JSONDecoder {
    static var observatory: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

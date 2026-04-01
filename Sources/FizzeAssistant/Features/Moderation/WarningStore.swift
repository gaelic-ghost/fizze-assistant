import Foundation
import GRDB

struct WarningRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    // MARK: Stored Properties

    var id: String
    var guild_id: String
    var user_id: String
    var moderator_user_id: String
    var reason: String
    var created_at: Date

    // MARK: Columns

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let guild_id = Column(CodingKeys.guild_id)
        static let user_id = Column(CodingKeys.user_id)
        static let created_at = Column(CodingKeys.created_at)
    }
}

actor WarningStore {
    // MARK: Stored Properties

    private let dbQueue: DatabaseQueue
    private let configuredGuildID: String?

    // MARK: Lifecycle

    init(path: String, configuredGuildID: String? = nil) throws {
        let directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        self.configuredGuildID = configuredGuildID?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty
        self.dbQueue = try DatabaseQueue(path: path)
        try Self.makeMigrator(configuredGuildID: self.configuredGuildID).migrate(dbQueue)
    }

    // MARK: Public API

    func createWarning(guild_id: String, user_id: String, moderator_user_id: String, reason: String) throws -> WarningRecord {
        let warning = WarningRecord(
            id: UUID().uuidString,
            guild_id: guild_id,
            user_id: user_id,
            moderator_user_id: moderator_user_id,
            reason: reason,
            created_at: Date()
        )

        try dbQueue.write { db in
            try warning.insert(db)
        }

        return warning
    }

    func warnings(for user_id: String, guild_id: String) throws -> [WarningRecord] {
        try dbQueue.read { db in
            try WarningRecord
                .filter(WarningRecord.Columns.user_id == user_id && WarningRecord.Columns.guild_id == guild_id)
                .order(WarningRecord.Columns.created_at.desc)
                .fetchAll(db)
        }
    }

    func deleteWarning(id: String) throws -> Bool {
        try dbQueue.write { db in
            try WarningRecord.deleteOne(db, key: id)
        }
    }

    func deleteWarnings(for user_id: String, guild_id: String) throws -> Int {
        try dbQueue.write { db in
            try WarningRecord
                .filter(WarningRecord.Columns.user_id == user_id && WarningRecord.Columns.guild_id == guild_id)
                .deleteAll(db)
        }
    }

    // MARK: Private Helpers

    private static func makeMigrator(configuredGuildID: String?) -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createWarnings") { db in
            try db.create(table: "warningRecord") { table in
                table.column("id", .text).primaryKey()
                table.column("guild_id", .text).notNull()
                table.column("user_id", .text).notNull()
                table.column("moderator_user_id", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }
        }
        migrator.registerMigration("addGuildIDToWarnings") { db in
            let columnNames = try db.columns(in: "warningRecord").map(\.name)
            guard !columnNames.contains("guild_id") else { return }

            let guildID = configuredGuildID ?? ""
            try db.alter(table: "warningRecord") { table in
                table.add(column: "guild_id", .text).notNull().defaults(to: guildID)
            }
        }
        return migrator
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

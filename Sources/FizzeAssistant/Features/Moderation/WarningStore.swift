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

struct IconicWizardDraft: Codable, FetchableRecord, PersistableRecord, Sendable {
    // MARK: Stored Properties

    var session_id: String
    var trigger: String
    var user_id: String
    var created_at: Date

    // MARK: Columns

    enum Columns {
        static let session_id = Column(CodingKeys.session_id)
        static let user_id = Column(CodingKeys.user_id)
        static let created_at = Column(CodingKeys.created_at)
    }
}

actor WarningStore {
    // MARK: Stored Properties

    private let dbQueue: DatabaseQueue
    private let configuredGuildID: String?
    private let iconicWizardDraftLifetime: TimeInterval = 15 * 60

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

    func saveIconicWizardDraft(trigger: String, userID: String, now: Date = Date()) throws -> String {
        let draft = IconicWizardDraft(
            session_id: UUID().uuidString.lowercased(),
            trigger: trigger,
            user_id: userID,
            created_at: now
        )

        try dbQueue.write { db in
            try purgeExpiredIconicWizardDrafts(in: db, now: now)
            try draft.insert(db)
        }

        return draft.session_id
    }

    func iconicWizardDraft(sessionID: String, userID: String, now: Date = Date()) throws -> IconicWizardDraft {
        try dbQueue.write { db in
            try purgeExpiredIconicWizardDrafts(in: db, now: now)

            guard let draft = try IconicWizardDraft.fetchOne(db, key: sessionID) else {
                throw UserFacingError("WarningStore.iconicWizardDraft: this `this-is-iconic` draft has expired or is missing, so the bot cannot continue the wizard. The most likely cause is that too much time passed between steps, or the bot process restarted before the next wizard step arrived; start `/this-is-iconic` again.")
            }

            guard draft.user_id == userID else {
                throw UserFacingError("WarningStore.iconicWizardDraft: only the person who started this `this-is-iconic` draft can continue it. The most likely cause is that someone else clicked the button for a private wizard step.")
            }

            return draft
        }
    }

    func removeIconicWizardDraft(sessionID: String, now: Date = Date()) throws {
        try dbQueue.write { db in
            try purgeExpiredIconicWizardDrafts(in: db, now: now)
            _ = try IconicWizardDraft.deleteOne(db, key: sessionID)
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
        migrator.registerMigration("createIconicWizardDrafts") { db in
            try db.create(table: "iconicWizardDraft") { table in
                table.column("session_id", .text).primaryKey()
                table.column("trigger", .text).notNull()
                table.column("user_id", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }
        }
        return migrator
    }

    private func purgeExpiredIconicWizardDrafts(in db: Database, now: Date) throws {
        let cutoff = now.addingTimeInterval(-iconicWizardDraftLifetime)
        try IconicWizardDraft
            .filter(IconicWizardDraft.Columns.created_at <= cutoff)
            .deleteAll(db)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

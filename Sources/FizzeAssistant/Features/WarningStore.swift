import Foundation
import GRDB

struct WarningRecord: Codable, FetchableRecord, PersistableRecord, Sendable {
    var id: String
    var guildID: String
    var userID: String
    var moderatorUserID: String
    var reason: String
    var createdAt: Date

    enum Columns {
        static let id = Column(CodingKeys.id)
        static let guildID = Column(CodingKeys.guildID)
        static let userID = Column(CodingKeys.userID)
        static let createdAt = Column(CodingKeys.createdAt)
    }
}

actor WarningStore {
    private let dbQueue: DatabaseQueue

    init(path: String) throws {
        let directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        self.dbQueue = try DatabaseQueue(path: path)
        try Self.makeMigrator().migrate(dbQueue)
    }

    func createWarning(guildID: String, userID: String, moderatorUserID: String, reason: String) throws -> WarningRecord {
        let warning = WarningRecord(
            id: UUID().uuidString,
            guildID: guildID,
            userID: userID,
            moderatorUserID: moderatorUserID,
            reason: reason,
            createdAt: Date()
        )

        try dbQueue.write { db in
            try warning.insert(db)
        }

        return warning
    }

    func warnings(for userID: String, guildID: String) throws -> [WarningRecord] {
        try dbQueue.read { db in
            try WarningRecord
                .filter(WarningRecord.Columns.userID == userID && WarningRecord.Columns.guildID == guildID)
                .order(WarningRecord.Columns.createdAt.desc)
                .fetchAll(db)
        }
    }

    func deleteWarning(id: String) throws -> Bool {
        try dbQueue.write { db in
            try WarningRecord.deleteOne(db, key: id)
        }
    }

    func deleteWarnings(for userID: String, guildID: String) throws -> Int {
        try dbQueue.write { db in
            try WarningRecord
                .filter(WarningRecord.Columns.userID == userID && WarningRecord.Columns.guildID == guildID)
                .deleteAll(db)
        }
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("createWarnings") { db in
            try db.create(table: "warningRecord") { table in
                table.column("id", .text).primaryKey()
                table.column("guildID", .text).notNull()
                table.column("userID", .text).notNull()
                table.column("moderatorUserID", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("createdAt", .datetime).notNull()
            }
        }
        return migrator
    }
}

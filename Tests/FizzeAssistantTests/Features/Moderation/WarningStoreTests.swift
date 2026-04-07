import Foundation
import Testing
import GRDB
@testable import FizzeAssistant

struct WarningStoreTests {
    // MARK: Tests

    @Test
    func createAndDeleteWarnings() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try WarningStore(path: databaseURL.path)
        let warning = try await store.createWarning(
            guild_id: "guild",
            user_id: "user",
            moderator_user_id: "mod",
            reason: "Reason"
        )

        let warnings = try await store.warnings(for: "user", guild_id: "guild")
        #expect(warnings.count == 1)
        #expect(warnings.first?.id == warning.id)

        let deleted = try await store.deleteWarning(id: warning.id)
        #expect(deleted)
    }

    @Test
    func migratesLegacyWarningTableAndBackfillsConfiguredGuildID() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let dbQueue = try DatabaseQueue(path: databaseURL.path)
        try await dbQueue.write { db in
            try db.create(table: "warningRecord") { table in
                table.column("id", .text).primaryKey()
                table.column("user_id", .text).notNull()
                table.column("moderator_user_id", .text).notNull()
                table.column("reason", .text).notNull()
                table.column("created_at", .datetime).notNull()
            }

            try db.execute(
                sql: """
                    INSERT INTO warningRecord (id, user_id, moderator_user_id, reason, created_at)
                    VALUES (?, ?, ?, ?, ?)
                    """,
                arguments: [
                    "legacy-warning",
                    "user",
                    "mod",
                    "Legacy reason",
                    Date(),
                ]
            )

            try db.create(table: "grdb_migrations") { table in
                table.column("identifier", .text).primaryKey()
            }
            try db.execute(
                sql: "INSERT INTO grdb_migrations (identifier) VALUES (?)",
                arguments: ["createWarnings"]
            )
        }

        let store = try WarningStore(path: databaseURL.path, configuredGuildID: "guild")
        let warnings = try await store.warnings(for: "user", guild_id: "guild")

        #expect(warnings.count == 1)
        #expect(warnings.first?.id == "legacy-warning")
        #expect(warnings.first?.reason == "Legacy reason")

        let created = try await store.createWarning(
            guild_id: "guild",
            user_id: "fresh-user",
            moderator_user_id: "mod",
            reason: "Fresh reason"
        )
        #expect(created.guild_id == "guild")
    }

    @Test
    func iconicWizardDraftPersistsAcrossStoreRecreation() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let firstStore = try WarningStore(path: databaseURL.path)
        let sessionID = try await firstStore.saveIconicWizardDraft(trigger: "fizze time", userID: "user-1")

        let restartedStore = try WarningStore(path: databaseURL.path)
        let draft = try await restartedStore.iconicWizardDraft(sessionID: sessionID, userID: "user-1")

        #expect(draft.trigger == "fizze time")
        #expect(draft.user_id == "user-1")
    }

    @Test
    func iconicWizardDraftRejectsDifferentUser() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try WarningStore(path: databaseURL.path)
        let sessionID = try await store.saveIconicWizardDraft(trigger: "fizze time", userID: "user-1")

        let error = await #expect(throws: UserFacingError.self, performing: {
            _ = try await store.iconicWizardDraft(sessionID: sessionID, userID: "user-2")
        })
        #expect(error?.localizedDescription.contains("only the person who started") == true)
    }

    @Test
    func iconicWizardDraftIsPurgedAfterLifetimeExpires() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try WarningStore(path: databaseURL.path)
        let createdAt = Date(timeIntervalSince1970: 0)
        let sessionID = try await store.saveIconicWizardDraft(trigger: "fizze time", userID: "user-1", now: createdAt)

        let error = await #expect(throws: UserFacingError.self, performing: {
            _ = try await store.iconicWizardDraft(
                sessionID: sessionID,
                userID: "user-1",
                now: createdAt.addingTimeInterval((15 * 60) + 1)
            )
        })
        #expect(error?.localizedDescription.contains("bot process restarted") == true)
    }

    @Test
    func removeIconicWizardDraftDeletesPersistedDraft() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try WarningStore(path: databaseURL.path)
        let sessionID = try await store.saveIconicWizardDraft(trigger: "fizze time", userID: "user-1")

        try await store.removeIconicWizardDraft(sessionID: sessionID)

        await #expect(throws: UserFacingError.self, performing: {
            _ = try await store.iconicWizardDraft(sessionID: sessionID, userID: "user-1")
        })
    }
}

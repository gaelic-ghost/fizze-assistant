import Foundation
import Testing
@testable import FizzeAssistant

struct WarningStoreTests {
    @Test
    func createAndDeleteWarnings() async throws {
        let databaseURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")

        let store = try WarningStore(path: databaseURL.path)
        let warning = try await store.createWarning(
            guildID: "guild",
            userID: "user",
            moderatorUserID: "mod",
            reason: "Reason"
        )

        let warnings = try await store.warnings(for: "user", guildID: "guild")
        #expect(warnings.count == 1)
        #expect(warnings.first?.id == warning.id)

        let deleted = try await store.deleteWarning(id: warning.id)
        #expect(deleted)
    }
}

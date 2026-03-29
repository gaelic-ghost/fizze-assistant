import Foundation
import Testing
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
}

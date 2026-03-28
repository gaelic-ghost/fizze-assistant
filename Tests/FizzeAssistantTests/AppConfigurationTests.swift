import Foundation
import Testing
@testable import FizzeAssistant

struct AppConfigurationTests {
    @Test
    func configurationStoreParsesRoleListsAndDefaults() async throws {
        let environment = [
            "DISCORD_BOT_TOKEN": "token",
            "DISCORD_APPLICATION_ID": "app",
            "DISCORD_GUILD_ID": "guild",
            "DISCORD_DEFAULT_MEMBER_ROLE_ID": "member",
            "DISCORD_ALLOWED_STAFF_ROLE_IDS": "staff-a, staff-b",
            "DISCORD_ALLOWED_CONFIG_ROLE_IDS": "owner-a, owner-b",
        ]

        let store = try ConfigurationStore.load(from: nil, environment: environment)
        let configuration = try await store.readyConfiguration()

        #expect(configuration.allowedStaffRoleIDs == ["staff-a", "staff-b"])
        #expect(configuration.allowedConfigRoleIDs == ["owner-a", "owner-b"])
        #expect(configuration.databasePath == ".data/fizze-assistant.sqlite")
        #expect(configuration.runtimeConfigPath == ".data/runtime-config.json")
    }
}

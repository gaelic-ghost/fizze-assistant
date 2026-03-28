import Foundation
import Testing
@testable import FizzeAssistant

struct AppConfigurationTests {
    @Test
    func environmentOverlayParsesStaffRoles() throws {
        let environment = [
            "DISCORD_BOT_TOKEN": "token",
            "DISCORD_APPLICATION_ID": "app",
            "DISCORD_GUILD_ID": "guild",
            "DISCORD_WELCOME_CHANNEL_ID": "welcome",
            "DISCORD_LEAVE_CHANNEL_ID": "leave",
            "DISCORD_MOD_LOG_CHANNEL_ID": "mod",
            "DISCORD_DEFAULT_MEMBER_ROLE_ID": "member",
            "DISCORD_ALLOWED_STAFF_ROLE_IDS": "staff-a, staff-b",
        ]

        let configuration = try AppConfiguration.load(from: nil, environment: environment)
        #expect(configuration.allowedStaffRoleIDs == ["staff-a", "staff-b"])
        #expect(configuration.databasePath == ".data/fizze-assistant.sqlite")
    }
}

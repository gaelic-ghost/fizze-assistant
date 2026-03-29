import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordInteractionAuthorizationTests {
    // MARK: Tests

    @Test
    func interactionMemberDecodesPermissionsAndRoles() throws {
        let data = """
        {
          "user": {
            "id": "user-1",
            "username": "gale",
            "global_name": "Gale"
          },
          "roles": ["staff-role"],
          "permissions": "40"
        }
        """.data(using: .utf8)!

        let member = try JSONDecoder().decode(DiscordInteractionMember.self, from: data)

        #expect(member.roles == ["staff-role"])
        #expect(member.permissionSet.contains(.administrator))
        #expect(member.permissionSet.contains(.manageGuild))
    }

    @Test
    func configAuthorizationAcceptsConfiguredRole() {
        var file = BotConfigurationFile.defaults
        file.allowed_staff_role_ids = ["staff-role"]
        file.allowed_config_role_ids = ["config-role"]
        let configuration = AppConfiguration(
            botToken: "token",
            file: file
        )
        let member = DiscordInteractionMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: ["config-role"],
            permissions: "0"
        )

        #expect(member.isConfigAuthorized(for: configuration))
        #expect(!member.isStaffAuthorized(for: configuration))
    }

    @Test
    func staffAuthorizationAcceptsManageGuildPermission() {
        var file = BotConfigurationFile.defaults
        file.allowed_staff_role_ids = ["staff-role"]
        file.allowed_config_role_ids = ["config-role"]
        let configuration = AppConfiguration(
            botToken: "token",
            file: file
        )
        let member = DiscordInteractionMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: [],
            permissions: String(DiscordPermission.manageGuild.rawValue)
        )

        #expect(member.isStaffAuthorized(for: configuration))
        #expect(member.isConfigAuthorized(for: configuration))
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct PermissionCalculatorTests {
    // MARK: Tests

    @Test
    func guildPermissionsCombineRoleBitsets() {
        let roles = [
            DiscordRole(id: "everyone", name: "@everyone", permissions: String(DiscordPermission.viewChannel.rawValue), position: 0),
            DiscordRole(id: "bot", name: "Bot", permissions: String(DiscordPermission.sendMessages.rawValue), position: 1),
        ]

        let permissions = PermissionCalculator.guildPermissions(memberRoleIDs: ["everyone", "bot"], roles: roles)
        #expect(permissions.contains(.viewChannel))
        #expect(permissions.contains(.sendMessages))
    }

    @Test
    func channelPermissionsApplyOverwritesInDiscordOrder() {
        let member = DiscordMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: ["everyone", "bot-role"]
        )
        let roles = [
            DiscordRole(id: "everyone", name: "@everyone", permissions: String(DiscordPermission.viewChannel.rawValue), position: 0),
            DiscordRole(id: "bot-role", name: "Bot", permissions: String(DiscordPermission.sendMessages.rawValue), position: 1),
        ]
        let overwrites = [
            DiscordPermissionOverwrite(id: "guild", type: 0, allow: "0", deny: String(DiscordPermission.sendMessages.rawValue)),
            DiscordPermissionOverwrite(id: "bot-role", type: 0, allow: String(DiscordPermission.sendMessages.rawValue), deny: "0"),
            DiscordPermissionOverwrite(id: "user-1", type: 1, allow: "0", deny: String(DiscordPermission.viewChannel.rawValue)),
        ]

        let permissions = PermissionCalculator.channelPermissions(
            member: member,
            roles: roles,
            overwrites: overwrites,
            everyoneID: "guild"
        )

        #expect(!permissions.contains(.viewChannel))
        #expect(permissions.contains(.sendMessages))
    }
}

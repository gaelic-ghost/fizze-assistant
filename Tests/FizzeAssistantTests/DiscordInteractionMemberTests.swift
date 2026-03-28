import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordInteractionMemberTests {
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
}

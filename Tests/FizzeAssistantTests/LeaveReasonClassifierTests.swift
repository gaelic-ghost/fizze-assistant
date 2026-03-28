import Foundation
import Testing
@testable import FizzeAssistant

struct LeaveReasonClassifierTests {
    @Test
    func recentBanCacheReturnsBanned() async throws {
        let cache = ModerationEventCache()
        await cache.recordBan(for: "user-1")

        let configuration = AppConfiguration(
            botToken: "token",
            file: BotConfigurationFile(
                applicationID: "app",
                guildID: "guild",
                defaultMemberRoleID: "member",
                allowedStaffRoleIDs: ["staff"],
                allowedConfigRoleIDs: ["owner"],
                databasePath: ".data/test.sqlite",
                welcomeChannelID: nil,
                leaveChannelID: nil,
                modLogChannelID: nil,
                suggestionsChannelID: nil,
                warnUsersViaDM: false,
                welcomeMessage: "Welcome",
                voluntaryLeaveMessage: "Leave",
                kickMessage: "Kick",
                banMessage: "Ban",
                unknownRemovalMessage: "Unknown",
                roleAssignmentFailureMessage: "Role failure",
                warningDMTemplate: "Warn",
                triggerCooldownSeconds: 30,
                leaveAuditLogLookbackSeconds: 30,
                iconicTriggers: []
            ),
        )

        let restClient = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let classifier = LeaveReasonClassifier(restClient: restClient, configuration: configuration, banCache: cache)

        let banned = await cache.recentBan(for: "user-1", within: 30)
        #expect(banned)
        _ = classifier
    }
}

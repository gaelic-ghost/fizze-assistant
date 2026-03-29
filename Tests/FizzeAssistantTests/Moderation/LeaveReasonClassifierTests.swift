import Foundation
import Testing
@testable import FizzeAssistant

struct LeaveReasonClassifierTests {
    // MARK: Tests

    @Test
    func recentBanCacheReturnsBanned() async throws {
        let cache = ModerationEventCache()
        await cache.recordBan(for: "user-1")

        let configuration = AppConfiguration(
            botToken: "token",
            file: BotConfigurationFile(
                application_id: "app",
                guild_id: "guild",
                default_member_role_id: "member",
                allowed_staff_role_ids: ["staff"],
                allowed_config_role_ids: ["owner"],
                database_path: ".data/test.sqlite",
                welcome_channel_id: nil,
                leave_channel_id: nil,
                mod_log_channel_id: nil,
                suggestions_channel_id: nil,
                warn_users_via_dm: false,
                welcome_message: "Welcome",
                voluntary_leave_message: "Leave",
                kick_message: "Kick",
                ban_message: "Ban",
                unknown_removal_message: "Unknown",
                role_assignment_failure_message: "Role failure",
                warning_dm_template: "Warn",
                trigger_cooldown_seconds: 30,
                leave_audit_log_lookback_seconds: 30,
                iconic_triggers: []
            ),
        )

        let restClient = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let classifier = LeaveReasonClassifier(restClient: restClient, configuration: configuration, banCache: cache)

        let banned = await cache.recentBan(for: "user-1", within: 30)
        #expect(banned)
        _ = classifier
    }
}

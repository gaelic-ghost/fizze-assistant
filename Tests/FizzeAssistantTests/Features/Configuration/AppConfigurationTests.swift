import Foundation
import Testing
@testable import FizzeAssistant

struct AppConfigurationTests {
    // MARK: Tests

    @Test
    func accessorsReflectUnderlyingConfigurationFile() {
        let configuration = AppConfiguration(
            botToken: "token",
            file: BotConfigurationFile(
                application_id: "app",
                guild_id: "guild",
                default_member_role_id: "member",
                allowed_staff_role_ids: ["staff-a", "staff-b"],
                allowed_config_role_ids: ["owner-a", "owner-b"],
                database_path: ".data/fizze-assistant.sqlite",
                welcome_channel_id: "welcome",
                leave_channel_id: "leave",
                mod_log_channel_id: "mod-log",
                suggestions_channel_id: "suggestions",
                warn_users_via_dm: false,
                welcome_message: "hi",
                voluntary_leave_message: "bye",
                kick_message: "kick",
                ban_message: "ban",
                unknown_removal_message: "unknown",
                role_assignment_failure_message: "role failure",
                warning_dm_template: "warn",
                bot_mention_responses: ["hello {user_mention}"],
                trigger_cooldown_seconds: 30,
                leave_audit_log_lookback_seconds: 30,
                trigger_matching_mode: .exact,
                iconic_messages: [:]
            )
        )

        #expect(configuration.botToken == "token")
        #expect(configuration.allowed_staff_role_ids == ["staff-a", "staff-b"])
        #expect(configuration.allowed_config_role_ids == ["owner-a", "owner-b"])
        #expect(configuration.database_path == ".data/fizze-assistant.sqlite")
        #expect(configuration.suggestions_channel_id == "suggestions")
        #expect(configuration.trigger_matching_mode == .exact)
        #expect(configuration.iconic_messages.isEmpty)
        #expect(configuration.bot_mention_responses == ["hello {user_mention}"])
    }

    @Test
    func installURLUsesApplicationIDAndRequiredPermissionInteger() {
        let configuration = AppConfiguration(
            botToken: "token",
            file: BotConfigurationFile.defaults
        )

        let withApplicationID = AppConfiguration(
            botToken: configuration.botToken,
            file: {
                var file = configuration.file
                file.application_id = "1234567890"
                return file
            }()
        )

        #expect(AppConfiguration.required_permission_integer == 268_438_656)
        #expect(withApplicationID.install_url == "https://discord.com/oauth2/authorize?client_id=1234567890&scope=bot%20applications.commands&permissions=268438656")
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct BotConfigurationFileTests {
    // MARK: Tests

    @Test
    func warningsMentionMissingOptionalChannels() {
        let configuration = BotConfigurationFile.defaults
        #expect(configuration.warnings.contains("Welcome channel is not configured yet. New-member welcome messages will be skipped."))
        #expect(configuration.warnings.contains("No config owner role IDs are configured yet."))
    }

    @Test
    func prettyPrintedJSONIncludesMatchingModeField() throws {
        let json = try BotConfigurationFile.defaults.prettyPrintedJSON()
        #expect(json.contains("\"trigger_matching_mode\""))
        #expect(json.contains("\"exact\""))
    }

    @Test
    func runtimeValidationNormalizesBotMentionResponses() throws {
        var configuration = BotConfigurationFile.defaults
        configuration.application_id = "app"
        configuration.guild_id = "guild"
        configuration.default_member_role_id = "member-role"
        configuration.allowed_staff_role_ids = ["staff-role"]
        configuration.allowed_config_role_ids = ["config-role"]
        configuration.bot_mention_responses = ["  Fizze Assistant, at your service, {user_mention}.  ", "   "]

        let runtime = try configuration.readyForRuntime(botToken: "token")
        #expect(runtime.bot_mention_responses == ["Fizze Assistant, at your service, {user_mention}."])
    }

    @Test
    func decodingOlderConfigWithoutBotMentionResponsesUsesDefaults() throws {
        let json = """
        {
          "allowed_config_role_ids": ["config-role"],
          "allowed_staff_role_ids": ["staff-role"],
          "application_id": "app",
          "ban_message": "ban",
          "database_path": ".data/fizze-assistant.sqlite",
          "default_member_role_id": "member-role",
          "guild_id": "guild",
          "iconic_messages": {},
          "kick_message": "kick",
          "leave_audit_log_lookback_seconds": 30,
          "leave_channel_id": null,
          "mod_log_channel_id": null,
          "role_assignment_failure_message": "role failure",
          "suggestions_channel_id": null,
          "trigger_cooldown_seconds": 30,
          "trigger_matching_mode": "exact",
          "unknown_removal_message": "unknown",
          "voluntary_leave_message": "bye",
          "warn_users_via_dm": false,
          "warning_dm_template": "warn",
          "welcome_channel_id": null,
          "welcome_message": "hi"
        }
        """

        let configuration = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(json.utf8))
        #expect(configuration.bot_mention_responses == BotConfigurationFile.defaults.bot_mention_responses)
    }
}

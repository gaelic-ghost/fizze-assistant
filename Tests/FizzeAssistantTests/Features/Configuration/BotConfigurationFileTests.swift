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
}

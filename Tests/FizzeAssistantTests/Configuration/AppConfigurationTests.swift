import Foundation
import Testing
@testable import FizzeAssistant

struct AppConfigurationTests {
    // MARK: Tests

    @Test
    func configurationStoreParsesSingleConfigFile() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let configurationFile = BotConfigurationFile(
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
            trigger_cooldown_seconds: 30,
            leave_audit_log_lookback_seconds: 30,
            iconic_triggers: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: configURL)

        let store = try ConfigurationStore.load(from: configURL, environment: [
            "DISCORD_BOT_TOKEN": "token",
        ])
        let configuration = try await store.readyConfiguration()

        #expect(configuration.allowed_staff_role_ids == ["staff-a", "staff-b"])
        #expect(configuration.allowed_config_role_ids == ["owner-a", "owner-b"])
        #expect(configuration.database_path == ".data/fizze-assistant.sqlite")
        #expect(configuration.suggestions_channel_id == "suggestions")
    }
}

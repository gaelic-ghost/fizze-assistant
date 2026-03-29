import Foundation
import Testing
@testable import FizzeAssistant

struct ConfigurationStoreTests {
    // MARK: Tests

    @Test
    func runtimeUpdatesPersistToDisk() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")

        let configurationFile = BotConfigurationFile(
            application_id: "app",
            guild_id: "guild",
            default_member_role_id: "member",
            allowed_staff_role_ids: ["staff"],
            allowed_config_role_ids: ["owner"],
            database_path: rootURL.appendingPathComponent("warnings.sqlite").path,
            welcome_channel_id: nil,
            leave_channel_id: nil,
            mod_log_channel_id: nil,
            suggestions_channel_id: nil,
            warn_users_via_dm: false,
            welcome_message: "Welcome",
            voluntary_leave_message: "Bye",
            kick_message: "Kick",
            ban_message: "Ban",
            unknown_removal_message: "Unknown",
            role_assignment_failure_message: "Role failure",
            warning_dm_template: "Warn",
            trigger_cooldown_seconds: 30,
            leave_audit_log_lookback_seconds: 30,
            iconic_triggers: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: configURL)

        let store = try ConfigurationStore.load(
            from: configURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        _ = try await store.update(setting: .welcome_channel_id, value: "123456")
        _ = try await store.update(setting: .suggestions_channel_id, value: "654321")
        _ = try await store.addTrigger(trigger: "fizze time", response: "sparkle")

        let data = try Data(contentsOf: configURL)
        let runtime = try JSONDecoder().decode(BotConfigurationFile.self, from: data)
        #expect(runtime.welcome_channel_id == "123456")
        #expect(runtime.suggestions_channel_id == "654321")
        #expect(runtime.iconic_triggers.count == 1)
    }
}

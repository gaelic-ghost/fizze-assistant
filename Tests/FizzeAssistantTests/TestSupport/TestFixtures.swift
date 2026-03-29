import Foundation
import Logging
@testable import FizzeAssistant

func makeTemporaryTestDirectory() throws -> URL {
    let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
    return rootURL
}

func makeConfigurationFile(rootURL: URL, overrides: (inout BotConfigurationFile) -> Void = { _ in }) -> BotConfigurationFile {
    var configuration = BotConfigurationFile(
        application_id: "app",
        guild_id: "guild",
        default_member_role_id: "member-role",
        allowed_staff_role_ids: ["staff-role"],
        allowed_config_role_ids: ["config-role"],
        database_path: rootURL.appendingPathComponent("warnings.sqlite").path,
        welcome_channel_id: "welcome-channel",
        leave_channel_id: "leave-channel",
        mod_log_channel_id: "mod-log-channel",
        suggestions_channel_id: "suggestions-channel",
        warn_users_via_dm: false,
        welcome_message: "Welcome, {user_mention}!",
        voluntary_leave_message: "{username} left.",
        kick_message: "{username} was kicked.",
        ban_message: "{username} was banned.",
        unknown_removal_message: "{username} left or was removed.",
        role_assignment_failure_message: "Could not assign role to {user_mention}.",
        warning_dm_template: "Warning in {guild_name}: {reason}",
        trigger_cooldown_seconds: 30,
        leave_audit_log_lookback_seconds: 30,
        trigger_matching_mode: .exact,
        iconic_messages: [:]
    )
    overrides(&configuration)
    return configuration
}

func writeConfigurationFile(_ configuration: BotConfigurationFile, to configURL: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(configuration).write(to: configURL)
}

func makeConfigurationStore(
    rootURL: URL,
    environment: [String: String] = ["DISCORD_BOT_TOKEN": "token"],
    overrides: (inout BotConfigurationFile) -> Void = { _ in }
) throws -> ConfigurationStore {
    let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
    try writeConfigurationFile(makeConfigurationFile(rootURL: rootURL, overrides: overrides), to: configURL)
    return try ConfigurationStore.load(from: configURL, environment: environment)
}

func makeRouter(
    rootURL: URL,
    restClient: DiscordRESTClient,
    overrides: (inout BotConfigurationFile) -> Void = { _ in }
) async throws -> DiscordInteractionRouter {
    let configuration = makeConfigurationFile(rootURL: rootURL, overrides: overrides)
    let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
    try writeConfigurationFile(configuration, to: configURL)
    let configurationStore = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
    let warningStore = try WarningStore(path: configuration.database_path)
    return DiscordInteractionRouter(
        restClient: restClient,
        configurationStore: configurationStore,
        warningStore: warningStore,
        logger: .init(label: "test")
    )
}

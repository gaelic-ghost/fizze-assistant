import Foundation
import Testing
@testable import FizzeAssistant

struct ConfigurationStoreTests {
    // MARK: Tests

    @Test
    func defaultLoaderPrefersLocalConfigurationWhenPresent() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")

        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "baseline-app"),
            to: baselineURL
        )
        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "local-app"),
            to: localURL
        )

        let store = try ConfigurationStore.load(
            from: nil,
            environment: ["DISCORD_BOT_TOKEN": "token", "PWD": rootURL.path]
        )
        let runtime = await store.configurationFileContents()

        #expect(runtime.application_id == "local-app")
        let resolvedURL = await store.configurationURL()
        #expect(resolvedURL.lastPathComponent == "fizze-assistant-local.json")
    }

    @Test
    func defaultLoaderFallsBackToTrackedBaselineWhenLocalOverrideIsMissing() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "baseline-app"),
            to: baselineURL
        )

        let store = try ConfigurationStore.load(
            from: nil,
            environment: ["DISCORD_BOT_TOKEN": "token", "PWD": rootURL.path]
        )
        let runtime = await store.configurationFileContents()

        #expect(runtime.application_id == "baseline-app")
        let resolvedURL = await store.configurationURL()
        #expect(resolvedURL.lastPathComponent == "fizze-assistant.json")
    }

    @Test
    func defaultLoaderCreatesLocalConfigurationWhenNeitherFileExists() async throws {
        let rootURL = try makeTemporaryRootURL()

        let store = try ConfigurationStore.load(
            from: nil,
            environment: ["DISCORD_BOT_TOKEN": "token", "PWD": rootURL.path]
        )
        let configurationURL = try await store.initializeConfigurationFileIfNeeded()

        #expect(configurationURL.lastPathComponent == "fizze-assistant-local.json")
        #expect(FileManager.default.fileExists(atPath: configurationURL.path))
    }

    @Test
    func runtimeUpdatesPersistToDisk() async throws {
        let rootURL = try makeTemporaryRootURL()

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfiguration(makeConfiguration(rootURL: rootURL), to: configURL)

        let store = try ConfigurationStore.load(
            from: configURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        _ = try await store.update(setting: .welcome_channel_id, value: "123456")
        _ = try await store.update(setting: .suggestions_channel_id, value: "654321")
        _ = try await store.update(setting: .trigger_matching_mode, value: "fuzze")
        _ = try await store.addTrigger(trigger: "FIZZE TIME", response: "sparkle")

        let data = try Data(contentsOf: configURL)
        let runtime = try JSONDecoder().decode(BotConfigurationFile.self, from: data)
        #expect(runtime.welcome_channel_id == "123456")
        #expect(runtime.suggestions_channel_id == "654321")
        #expect(runtime.trigger_matching_mode == .fuzze)
        #expect(runtime.iconic_messages["fizze time"]?.content == "sparkle")
    }

    @Test
    func runtimeUpdatesPersistToSelectedLocalOverride() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")

        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "baseline-app"),
            to: baselineURL
        )
        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "local-app"),
            to: localURL
        )

        let store = try ConfigurationStore.load(
            from: nil,
            environment: ["DISCORD_BOT_TOKEN": "token", "PWD": rootURL.path]
        )
        _ = try await store.update(setting: .welcome_channel_id, value: "123456")

        let localRuntime = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: localURL))
        let baselineRuntime = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: baselineURL))

        #expect(localRuntime.welcome_channel_id == "123456")
        #expect(baselineRuntime.welcome_channel_id == nil)
    }

    @Test
    func runtimeValidationNormalizesAndValidatesIconicMessages() throws {
        let runtime = try BotConfigurationFile(
            application_id: "app",
            guild_id: "guild",
            default_member_role_id: "member",
            allowed_staff_role_ids: ["staff"],
            allowed_config_role_ids: ["owner"],
            database_path: ".data/fizze-assistant.sqlite",
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
            bot_mention_responses: ["hello"],
            trigger_cooldown_seconds: 30,
            leave_audit_log_lookback_seconds: 30,
            trigger_matching_mode: .exact,
            iconic_messages: [
                "  FIZZE TIME  ": IconicMessageConfiguration(content: "sparkle", embeds: nil),
            ]
        ).readyForRuntime(botToken: "token")

        #expect(runtime.iconic_messages["fizze time"]?.content == "sparkle")
    }

    @Test
    func runtimeValidationRejectsEmptyIconicMessagePayload() {
        #expect(throws: UserFacingError.self) {
            _ = try BotConfigurationFile(
                application_id: "app",
                guild_id: "guild",
                default_member_role_id: "member",
                allowed_staff_role_ids: ["staff"],
                allowed_config_role_ids: ["owner"],
                database_path: ".data/fizze-assistant.sqlite",
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
                bot_mention_responses: ["hello"],
                trigger_cooldown_seconds: 30,
                leave_audit_log_lookback_seconds: 30,
                trigger_matching_mode: .exact,
                iconic_messages: [
                    "fizze void": IconicMessageConfiguration(content: nil, embeds: nil),
                ]
            ).readyForRuntime(botToken: "token")
        }
    }

    // MARK: Helpers

    private func makeTemporaryRootURL() throws -> URL {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return rootURL
    }

    private func makeConfiguration(rootURL: URL, applicationID: String = "app") -> BotConfigurationFile {
        BotConfigurationFile(
            application_id: applicationID,
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
            bot_mention_responses: ["hello"],
            trigger_cooldown_seconds: 30,
            leave_audit_log_lookback_seconds: 30,
            trigger_matching_mode: .exact,
            iconic_messages: [:]
        )
    }

    private func writeConfiguration(_ configurationFile: BotConfigurationFile, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: url)
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

private final class TestDateSource: @unchecked Sendable {
    var current: Date

    init(current: Date) {
        self.current = current
    }
}

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
    func defaultLoaderSeedsLocalConfigurationFromBaselineWhenLocalOverrideIsMissing() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")
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
        #expect(resolvedURL.lastPathComponent == "fizze-assistant-local.json")
        #expect(FileManager.default.fileExists(atPath: localURL.path))
        let localRuntime = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: localURL))
        #expect(localRuntime.application_id == "baseline-app")
    }

    @Test
    func defaultLoaderCreatesLocalConfigurationWhenNeitherFileExists() async throws {
        let rootURL = try makeTemporaryRootURL()

        let store = try ConfigurationStore.load(
            from: nil,
            environment: ["DISCORD_BOT_TOKEN": "token", "PWD": rootURL.path]
        )
        let configurationURL = await store.configurationURL()

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

        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")
        let data = try Data(contentsOf: localURL)
        let runtime = try JSONDecoder().decode(BotConfigurationFile.self, from: data)
        #expect(runtime.welcome_channel_id == "123456")
        #expect(runtime.suggestions_channel_id == "654321")
        #expect(runtime.trigger_matching_mode == .fuzze)
        #expect(runtime.iconic_messages["fizze time"]?.content == "sparkle")

        let baselineRuntime = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: configURL))
        #expect(baselineRuntime.welcome_channel_id == nil)
        #expect(baselineRuntime.suggestions_channel_id == nil)
        #expect(baselineRuntime.trigger_matching_mode == .exact)
        #expect(baselineRuntime.iconic_messages["fizze time"] == nil)
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
    func explicitBaselinePathRedirectsToLocalOverride() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")
        try writeConfiguration(
            makeConfiguration(rootURL: rootURL, applicationID: "baseline-app"),
            to: baselineURL
        )

        let store = try ConfigurationStore.load(
            from: baselineURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        let resolvedURL = await store.configurationURL()
        #expect(resolvedURL.lastPathComponent == "fizze-assistant-local.json")
        #expect(FileManager.default.fileExists(atPath: localURL.path))
        let runtime = await store.configurationFileContents()
        #expect(runtime.application_id == "baseline-app")
    }

    @Test
    func explicitMissingBaselinePathCreatesBaselineThenSeedsLocalOverride() async throws {
        let rootURL = try makeTemporaryRootURL()
        let baselineURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")

        let store = try ConfigurationStore.load(
            from: baselineURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        let resolvedURL = await store.configurationURL()
        #expect(resolvedURL.lastPathComponent == "fizze-assistant-local.json")
        #expect(FileManager.default.fileExists(atPath: baselineURL.path))
        #expect(FileManager.default.fileExists(atPath: localURL.path))

        let baseline = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: baselineURL))
        let local = try JSONDecoder().decode(BotConfigurationFile.self, from: Data(contentsOf: localURL))
        #expect(baseline.application_id == BotConfigurationFile.defaults.application_id)
        #expect(local.application_id == baseline.application_id)
    }

    @Test
    func runtimeUpdatesCreateOneHourlyBackupForLocalConfig() async throws {
        let rootURL = try makeTemporaryRootURL()
        let localURL = rootURL.appendingPathComponent("fizze-assistant-local.json")
        try writeConfiguration(makeConfiguration(rootURL: rootURL), to: localURL)

        let dateSource = TestDateSource(current: Date(timeIntervalSince1970: 1_700_000_000))
        let store = ConfigurationStore(
            botToken: "token",
            configURL: localURL,
            baselineTemplateURL: nil,
            configurationFile: makeConfiguration(rootURL: rootURL),
            now: { dateSource.current }
        )

        _ = try await store.update(setting: .welcome_channel_id, value: "123456")
        _ = try await store.update(setting: .leave_channel_id, value: "654321")

        let backupDirectoryURL = rootURL.appendingPathComponent(".data/config-backups", isDirectory: true)
        let firstHourFiles = try FileManager.default.contentsOfDirectory(atPath: backupDirectoryURL.path)
        #expect(firstHourFiles.count == 1)

        dateSource.current = dateSource.current.addingTimeInterval(3600)
        _ = try await store.update(setting: .mod_log_channel_id, value: "mod-log")

        let secondHourFiles = try FileManager.default.contentsOfDirectory(atPath: backupDirectoryURL.path)
        #expect(secondHourFiles.count == 2)
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

import Foundation

struct BotConfigurationFile: Codable, Sendable {
    // MARK: Stored Properties

    var application_id: String
    var guild_id: String
    var default_member_role_id: String
    var allowed_staff_role_ids: [String]
    var allowed_config_role_ids: [String]
    var database_path: String
    var welcome_channel_id: String?
    var leave_channel_id: String?
    var mod_log_channel_id: String?
    var suggestions_channel_id: String?
    var warn_users_via_dm: Bool
    var welcome_message: String
    var voluntary_leave_message: String
    var kick_message: String
    var ban_message: String
    var unknown_removal_message: String
    var role_assignment_failure_message: String
    var warning_dm_template: String
    var trigger_cooldown_seconds: Double
    var leave_audit_log_lookback_seconds: Double
    var iconic_triggers: [IconicTriggerConfiguration]

    // MARK: Defaults

    static let defaults = BotConfigurationFile(
        application_id: "",
        guild_id: "",
        default_member_role_id: "",
        allowed_staff_role_ids: [],
        allowed_config_role_ids: [],
        database_path: ".data/fizze-assistant.sqlite",
        welcome_channel_id: nil,
        leave_channel_id: nil,
        mod_log_channel_id: nil,
        suggestions_channel_id: nil,
        warn_users_via_dm: false,
        welcome_message: "Welcome to the server, {user_mention}!",
        voluntary_leave_message: "{username} left the server.",
        kick_message: "{username} was kicked from the server.",
        ban_message: "{username} was banned from the server.",
        unknown_removal_message: "{username} left or was removed from the server.",
        role_assignment_failure_message: "I couldn't assign the default member role to {user_mention}. Please check role hierarchy and `Manage Roles` permissions.",
        warning_dm_template: "You have been warned in {guild_name}: {reason}",
        trigger_cooldown_seconds: 30,
        leave_audit_log_lookback_seconds: 30,
        iconic_triggers: []
    )

    // MARK: Validation

    func readyForRuntime(botToken: String) throws -> BotConfigurationFile {
        let requiredValues: [(String, String)] = [
            ("DISCORD_BOT_TOKEN", botToken),
            ("application_id", application_id),
            ("guild_id", guild_id),
            ("default_member_role_id", default_member_role_id),
        ]

        let missing = requiredValues
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.0)

        guard missing.isEmpty else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: the bot cannot start until these required values are filled in: \(missing.joined(separator: ", ")). The most likely cause is that `fizze-assistant.json` or `DISCORD_BOT_TOKEN` is still incomplete.")
        }

        guard !allowed_staff_role_ids.isEmpty else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `allowed_staff_role_ids` is empty in `fizze-assistant.json`, so staff commands would have no authorized roles. Add at least one staff role ID and try again.")
        }

        guard !allowed_config_role_ids.isEmpty else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `allowed_config_role_ids` is empty in `fizze-assistant.json`, so `/config` would have no authorized owners. Add at least one config-owner role ID and try again.")
        }

        guard trigger_cooldown_seconds > 0 else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `trigger_cooldown_seconds` in `fizze-assistant.json` must be greater than zero. The most likely cause is a zero or negative number in the config file.")
        }

        guard leave_audit_log_lookback_seconds > 0 else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `leave_audit_log_lookback_seconds` in `fizze-assistant.json` must be greater than zero. The most likely cause is a zero or negative number in the config file.")
        }

        return BotConfigurationFile(
            application_id: application_id.trimmingCharacters(in: .whitespacesAndNewlines),
            guild_id: guild_id.trimmingCharacters(in: .whitespacesAndNewlines),
            default_member_role_id: default_member_role_id.trimmingCharacters(in: .whitespacesAndNewlines),
            allowed_staff_role_ids: allowed_staff_role_ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            allowed_config_role_ids: allowed_config_role_ids.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            database_path: database_path.trimmingCharacters(in: .whitespacesAndNewlines),
            welcome_channel_id: Self.normalizedSnowflake(welcome_channel_id),
            leave_channel_id: Self.normalizedSnowflake(leave_channel_id),
            mod_log_channel_id: Self.normalizedSnowflake(mod_log_channel_id),
            suggestions_channel_id: Self.normalizedSnowflake(suggestions_channel_id),
            warn_users_via_dm: warn_users_via_dm,
            welcome_message: welcome_message,
            voluntary_leave_message: voluntary_leave_message,
            kick_message: kick_message,
            ban_message: ban_message,
            unknown_removal_message: unknown_removal_message,
            role_assignment_failure_message: role_assignment_failure_message,
            warning_dm_template: warning_dm_template,
            trigger_cooldown_seconds: trigger_cooldown_seconds,
            leave_audit_log_lookback_seconds: leave_audit_log_lookback_seconds,
            iconic_triggers: iconic_triggers
        )
    }

    var warnings: [String] {
        var messages: [String] = []
        if application_id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Application ID is not configured yet.")
        }
        if guild_id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Guild ID is not configured yet.")
        }
        if default_member_role_id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Default member role ID is not configured yet.")
        }
        if allowed_staff_role_ids.isEmpty {
            messages.append("No staff role IDs are configured yet.")
        }
        if allowed_config_role_ids.isEmpty {
            messages.append("No config owner role IDs are configured yet.")
        }
        if welcome_channel_id == nil {
            messages.append("Welcome channel is not configured yet. New-member welcome messages will be skipped.")
        }
        if leave_channel_id == nil {
            messages.append("Leave channel is not configured yet. Departure announcements will be skipped.")
        }
        if mod_log_channel_id == nil {
            messages.append("Mod log channel is not configured yet. Warning logging and some onboarding failure messages will be skipped.")
        }
        if suggestions_channel_id == nil {
            messages.append("Suggestions channel is not configured yet. Suggestions workflow will be unavailable until it is set.")
        }
        return messages
    }

    func prettyPrintedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw UserFacingError("BotConfigurationFile.prettyPrintedJSON: the bot could not turn the current config into UTF-8 text for display. The most likely cause is unexpected encoded data in memory.")
        }
        return string
    }

    private static func normalizedSnowflake(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }
}

struct AppConfiguration: Sendable {
    // MARK: Stored Properties

    var botToken: String
    var file: BotConfigurationFile

    // MARK: Accessors

    var application_id: String { file.application_id }
    var guild_id: String { file.guild_id }
    var default_member_role_id: String { file.default_member_role_id }
    var allowed_staff_role_ids: [String] { file.allowed_staff_role_ids }
    var allowed_config_role_ids: [String] { file.allowed_config_role_ids }
    var database_path: String { file.database_path }
    var welcome_channel_id: String? { file.welcome_channel_id }
    var leave_channel_id: String? { file.leave_channel_id }
    var mod_log_channel_id: String? { file.mod_log_channel_id }
    var suggestions_channel_id: String? { file.suggestions_channel_id }
    var warn_users_via_dm: Bool { file.warn_users_via_dm }
    var welcome_message: String { file.welcome_message }
    var voluntary_leave_message: String { file.voluntary_leave_message }
    var kick_message: String { file.kick_message }
    var ban_message: String { file.ban_message }
    var unknown_removal_message: String { file.unknown_removal_message }
    var role_assignment_failure_message: String { file.role_assignment_failure_message }
    var warning_dm_template: String { file.warning_dm_template }
    var trigger_cooldown_seconds: Double { file.trigger_cooldown_seconds }
    var leave_audit_log_lookback_seconds: Double { file.leave_audit_log_lookback_seconds }
    var iconic_triggers: [IconicTriggerConfiguration] { file.iconic_triggers }

    var say_success_message: String { "Sent." }

    static let required_permission_integer = 268_438_656

    var install_url: String {
        "https://discord.com/oauth2/authorize?client_id=\(application_id)&scope=bot%20applications.commands&permissions=\(Self.required_permission_integer)"
    }
}

enum RuntimeConfigSetting: String, CaseIterable, Sendable {
    case welcome_channel_id = "welcome_channel_id"
    case leave_channel_id = "leave_channel_id"
    case mod_log_channel_id = "mod_log_channel_id"
    case suggestions_channel_id = "suggestions_channel_id"
    case warn_users_via_dm = "warn_users_via_dm"
    case welcome_message = "welcome_message"
    case voluntary_leave_message = "voluntary_leave_message"
    case kick_message = "kick_message"
    case ban_message = "ban_message"
    case unknown_removal_message = "unknown_removal_message"
    case role_assignment_failure_message = "role_assignment_failure_message"
    case warning_dm_template = "warning_dm_template"
    case trigger_cooldown_seconds = "trigger_cooldown_seconds"
    case leave_audit_log_lookback_seconds = "leave_audit_log_lookback_seconds"

    static var allowedKeysText: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

actor ConfigurationStore {
    // MARK: Stored Properties

    private let botToken: String
    private let configURL: URL
    private var configurationFile: BotConfigurationFile

    // MARK: Lifecycle

    init(botToken: String, configURL: URL, configurationFile: BotConfigurationFile) {
        self.botToken = botToken
        self.configURL = configURL
        self.configurationFile = configurationFile
    }

    // MARK: Loading

    static func load(from localConfigURL: URL?, environment: [String: String]) throws -> ConfigurationStore {
        let botToken = environment["DISCORD_BOT_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let configURL = localConfigURL ?? URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("fizze-assistant.json")

        let configurationFile: BotConfigurationFile
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            configurationFile = try decoder.decode(BotConfigurationFile.self, from: data)
        } else {
            configurationFile = .defaults
        }

        return ConfigurationStore(botToken: botToken, configURL: configURL, configurationFile: configurationFile)
    }

    // MARK: Accessors

    func currentConfiguration() -> AppConfiguration {
        AppConfiguration(botToken: botToken, file: configurationFile)
    }

    func readyConfiguration() throws -> AppConfiguration {
        AppConfiguration(
            botToken: botToken,
            file: try configurationFile.readyForRuntime(botToken: botToken)
        )
    }

    func configurationFileContents() -> BotConfigurationFile {
        configurationFile
    }

    // MARK: File Management

    @discardableResult
    func initializeConfigurationFileIfNeeded() throws -> URL {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return configURL
        }

        try persist(configurationFile: configurationFile)
        return configURL
    }

    func update(setting: RuntimeConfigSetting, value: String) throws -> BotConfigurationFile {
        var next = configurationFile
        switch setting {
        case .welcome_channel_id:
            next.welcome_channel_id = normalizeOptionalString(value)
        case .leave_channel_id:
            next.leave_channel_id = normalizeOptionalString(value)
        case .mod_log_channel_id:
            next.mod_log_channel_id = normalizeOptionalString(value)
        case .suggestions_channel_id:
            next.suggestions_channel_id = normalizeOptionalString(value)
        case .warn_users_via_dm:
            guard let parsed = Bool(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("ConfigurationStore.update: `\(setting.rawValue)` expects `true` or `false` in `/config set`. The most likely cause is that the value was typed as something else.")
            }
            next.warn_users_via_dm = parsed
        case .welcome_message:
            next.welcome_message = value
        case .voluntary_leave_message:
            next.voluntary_leave_message = value
        case .kick_message:
            next.kick_message = value
        case .ban_message:
            next.ban_message = value
        case .unknown_removal_message:
            next.unknown_removal_message = value
        case .role_assignment_failure_message:
            next.role_assignment_failure_message = value
        case .warning_dm_template:
            next.warning_dm_template = value
        case .trigger_cooldown_seconds:
            guard let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("ConfigurationStore.update: `\(setting.rawValue)` expects a number in `/config set`. The most likely cause is that the value was typed as text instead of digits.")
            }
            next.trigger_cooldown_seconds = parsed
        case .leave_audit_log_lookback_seconds:
            guard let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("ConfigurationStore.update: `\(setting.rawValue)` expects a number in `/config set`. The most likely cause is that the value was typed as text instead of digits.")
            }
            next.leave_audit_log_lookback_seconds = parsed
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func addTrigger(trigger: String, response: String) throws -> BotConfigurationFile {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        let normalizedResponse = try normalizedRequiredString(response, name: "response")

        var next = configurationFile
        if let index = next.iconic_triggers.firstIndex(where: { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }) {
            next.iconic_triggers[index] = IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse)
        } else {
            next.iconic_triggers.append(IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse))
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func removeTrigger(trigger: String) throws -> Bool {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        var next = configurationFile
        let originalCount = next.iconic_triggers.count
        next.iconic_triggers.removeAll { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }

        guard next.iconic_triggers.count != originalCount else {
            return false
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return true
    }

    // MARK: Helpers

    private func persist(configurationFile: BotConfigurationFile) throws {
        let directoryURL = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configurationFile)

        let temporaryURL = directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)

        if FileManager.default.fileExists(atPath: configURL.path) {
            try FileManager.default.removeItem(at: configURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: configURL)
    }

    private func normalizedRequiredString(_ value: String, name: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw UserFacingError("ConfigurationStore.normalizedRequiredString: `\(name)` cannot be empty. The most likely cause is that the command was submitted with a blank value.")
        }
        return trimmed
    }

    private func normalizeOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct IconicTriggerConfiguration: Codable, Hashable, Sendable {
    var trigger: String
    var response: String
}

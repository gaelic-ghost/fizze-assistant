import Foundation

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
        case .trigger_matching_mode:
            guard let parsed = IconicTriggerMatchingMode(rawValue: value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()) else {
                throw UserFacingError("ConfigurationStore.update: `\(setting.rawValue)` expects either `exact` or `fuzze` in `/config set`. The most likely cause is that the value was typed as something else.")
            }
            next.trigger_matching_mode = parsed
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func addTrigger(trigger: String, response: String) throws -> BotConfigurationFile {
        let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(trigger)
        let normalizedResponse = try normalizedRequiredString(response, name: "response")

        return try saveIconicMessage(
            trigger: normalizedTrigger,
            message: IconicMessageConfiguration(content: normalizedResponse, embeds: nil)
        )
    }

    func saveIconicMessage(trigger: String, message: IconicMessageConfiguration) throws -> BotConfigurationFile {
        let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(trigger)
        let normalizedMessage = try message.readyForRuntime(trigger: normalizedTrigger)

        var next = configurationFile
        next.iconic_messages[normalizedTrigger] = normalizedMessage

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func removeTrigger(trigger: String) throws -> Bool {
        let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(trigger)
        var next = configurationFile
        let removed = next.iconic_messages.removeValue(forKey: normalizedTrigger) != nil

        guard removed else {
            return false
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return true
    }

    // MARK: Private Helpers

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

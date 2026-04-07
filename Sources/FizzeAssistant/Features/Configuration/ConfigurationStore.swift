import Foundation

actor ConfigurationStore {
    // MARK: Constants

    static let baselineConfigurationFileName = "fizze-assistant.json"
    static let localConfigurationFileName = "fizze-assistant-local.json"
    static let localBackupDirectoryName = "config-backups"

    // MARK: Stored Properties

    private let botToken: String
    private let configURL: URL
    private let baselineTemplateURL: URL?
    private var configurationFile: BotConfigurationFile
    private let now: @Sendable () -> Date

    // MARK: Lifecycle

    init(
        botToken: String,
        configURL: URL,
        baselineTemplateURL: URL?,
        configurationFile: BotConfigurationFile,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.botToken = botToken
        self.configURL = configURL
        self.baselineTemplateURL = baselineTemplateURL
        self.configurationFile = configurationFile
        self.now = now
    }

    // MARK: Loading

    static func load(from localConfigURL: URL?, environment: [String: String]) throws -> ConfigurationStore {
        let botToken = environment["DISCORD_BOT_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolution = try resolveConfiguration(
            from: localConfigURL,
            environment: environment,
            fileManager: .default
        )
        if !FileManager.default.fileExists(atPath: resolution.activeURL.path) {
            if let baselineTemplateURL = resolution.baselineTemplateURL {
                try seedLocalConfigurationIfNeeded(from: baselineTemplateURL, to: resolution.activeURL, fileManager: .default)
            } else if resolution.activeURL.lastPathComponent == localConfigurationFileName {
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                let directoryURL = resolution.activeURL.deletingLastPathComponent()
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
                try encoder.encode(BotConfigurationFile.defaults).write(to: resolution.activeURL)
            }
        }
        let configurationFile = try loadConfigurationFile(from: resolution.activeURL)

        return ConfigurationStore(
            botToken: botToken,
            configURL: resolution.activeURL,
            baselineTemplateURL: resolution.baselineTemplateURL,
            configurationFile: configurationFile
        )
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

    func configurationURL() -> URL {
        configURL
    }

    // MARK: File Management

    @discardableResult
    func initializeConfigurationFileIfNeeded() throws -> URL {
        if FileManager.default.fileExists(atPath: configURL.path) {
            return configURL
        }

        if let baselineTemplateURL {
            try Self.seedLocalConfigurationIfNeeded(from: baselineTemplateURL, to: configURL, fileManager: .default)
            if FileManager.default.fileExists(atPath: configURL.path) {
                let data = try Data(contentsOf: configURL)
                let decoder = JSONDecoder()
                configurationFile = try decoder.decode(BotConfigurationFile.self, from: data)
                return configURL
            }
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

    private static func resolveConfiguration(
        from explicitConfigURL: URL?,
        environment: [String: String],
        fileManager: FileManager
    ) throws -> (activeURL: URL, baselineTemplateURL: URL?) {
        if let explicitConfigURL {
            return try resolveExplicitConfiguration(explicitConfigURL, fileManager: fileManager)
        }

        let rootURL = rootURL(environment: environment, fileManager: fileManager)
        let localURL = rootURL.appendingPathComponent(localConfigurationFileName)
        let baselineURL = rootURL.appendingPathComponent(baselineConfigurationFileName)

        if fileManager.fileExists(atPath: localURL.path) {
            return (activeURL: localURL, baselineTemplateURL: fileManager.fileExists(atPath: baselineURL.path) ? baselineURL : nil)
        }

        if fileManager.fileExists(atPath: baselineURL.path) {
            try seedLocalConfigurationIfNeeded(from: baselineURL, to: localURL, fileManager: fileManager)
            return (activeURL: localURL, baselineTemplateURL: baselineURL)
        }

        return (activeURL: localURL, baselineTemplateURL: nil)
    }

    private static func resolveExplicitConfiguration(_ explicitConfigURL: URL, fileManager: FileManager) throws -> (activeURL: URL, baselineTemplateURL: URL?) {
        let explicitName = explicitConfigURL.lastPathComponent
        if explicitName == localConfigurationFileName {
            let baselineURL = explicitConfigURL.deletingLastPathComponent().appendingPathComponent(baselineConfigurationFileName)
            return (activeURL: explicitConfigURL, baselineTemplateURL: fileManager.fileExists(atPath: baselineURL.path) ? baselineURL : nil)
        }

        if explicitName == baselineConfigurationFileName {
            let localURL = explicitConfigURL.deletingLastPathComponent().appendingPathComponent(localConfigurationFileName)
            try seedLocalConfigurationIfNeeded(from: explicitConfigURL, to: localURL, fileManager: fileManager)
            return (activeURL: localURL, baselineTemplateURL: explicitConfigURL)
        }

        return (activeURL: explicitConfigURL, baselineTemplateURL: nil)
    }

    private static func rootURL(environment: [String: String], fileManager: FileManager) -> URL {
        let configuredWorkingDirectory = environment["PWD"]?.trimmingCharacters(in: .whitespacesAndNewlines)
        let workingDirectoryPath = configuredWorkingDirectory?.isEmpty == false
            ? configuredWorkingDirectory!
            : fileManager.currentDirectoryPath
        return URL(fileURLWithPath: workingDirectoryPath, isDirectory: true)
    }

    private static func loadConfigurationFile(from configURL: URL) throws -> BotConfigurationFile {
        if FileManager.default.fileExists(atPath: configURL.path) {
            let data = try Data(contentsOf: configURL)
            let decoder = JSONDecoder()
            return try decoder.decode(BotConfigurationFile.self, from: data)
        }

        return .defaults
    }

    private static func seedLocalConfigurationIfNeeded(from baselineURL: URL, to localURL: URL, fileManager: FileManager) throws {
        guard !fileManager.fileExists(atPath: localURL.path) else {
            return
        }

        guard fileManager.fileExists(atPath: baselineURL.path) else {
            return
        }

        try fileManager.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fileManager.copyItem(at: baselineURL, to: localURL)
    }

    private func persist(configurationFile: BotConfigurationFile) throws {
        let directoryURL = configURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configurationFile)

        try maybeCreateHourlyBackup(fileManager: .default, now: now())

        let temporaryURL = directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)

        if FileManager.default.fileExists(atPath: configURL.path) {
            try FileManager.default.removeItem(at: configURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: configURL)
    }

    private func maybeCreateHourlyBackup(fileManager: FileManager, now: Date) throws {
        guard configURL.lastPathComponent == Self.localConfigurationFileName else {
            return
        }

        guard fileManager.fileExists(atPath: configURL.path) else {
            return
        }

        let backupDirectoryURL = configURL
            .deletingLastPathComponent()
            .appendingPathComponent(".data", isDirectory: true)
            .appendingPathComponent(Self.localBackupDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: backupDirectoryURL, withIntermediateDirectories: true)

        let backupURL = backupDirectoryURL.appendingPathComponent(hourlyBackupFileName(now: now))
        guard !fileManager.fileExists(atPath: backupURL.path) else {
            return
        }

        try fileManager.copyItem(at: configURL, to: backupURL)
    }

    private func hourlyBackupFileName(now: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd-HH"
        return "fizze-assistant-local-\(formatter.string(from: now)).json"
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

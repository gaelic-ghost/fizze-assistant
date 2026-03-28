import Foundation

struct BotConfigurationFile: Codable, Sendable {
    // MARK: Stored Properties

    var applicationID: String
    var guildID: String
    var defaultMemberRoleID: String
    var allowedStaffRoleIDs: [String]
    var allowedConfigRoleIDs: [String]
    var databasePath: String
    var welcomeChannelID: String?
    var leaveChannelID: String?
    var modLogChannelID: String?
    var suggestionsChannelID: String?
    var warnUsersViaDM: Bool
    var welcomeMessage: String
    var voluntaryLeaveMessage: String
    var kickMessage: String
    var banMessage: String
    var unknownRemovalMessage: String
    var roleAssignmentFailureMessage: String
    var warningDMTemplate: String
    var triggerCooldownSeconds: Double
    var leaveAuditLogLookbackSeconds: Double
    var iconicTriggers: [IconicTriggerConfiguration]

    // MARK: Defaults

    static let defaults = BotConfigurationFile(
        applicationID: "",
        guildID: "",
        defaultMemberRoleID: "",
        allowedStaffRoleIDs: [],
        allowedConfigRoleIDs: [],
        databasePath: ".data/fizze-assistant.sqlite",
        welcomeChannelID: nil,
        leaveChannelID: nil,
        modLogChannelID: nil,
        suggestionsChannelID: nil,
        warnUsersViaDM: false,
        welcomeMessage: "Welcome to the server, {user_mention}!",
        voluntaryLeaveMessage: "{username} left the server.",
        kickMessage: "{username} was kicked from the server.",
        banMessage: "{username} was banned from the server.",
        unknownRemovalMessage: "{username} left or was removed from the server.",
        roleAssignmentFailureMessage: "I couldn't assign the default member role to {user_mention}. Please check role hierarchy and `Manage Roles` permissions.",
        warningDMTemplate: "You have been warned in {guild_name}: {reason}",
        triggerCooldownSeconds: 30,
        leaveAuditLogLookbackSeconds: 30,
        iconicTriggers: []
    )

    // MARK: Validation

    func readyForRuntime(botToken: String) throws -> BotConfigurationFile {
        let requiredValues: [(String, String)] = [
            ("DISCORD_BOT_TOKEN", botToken),
            ("applicationID", applicationID),
            ("guildID", guildID),
            ("defaultMemberRoleID", defaultMemberRoleID),
        ]

        let missing = requiredValues
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.0)

        guard missing.isEmpty else {
            throw UserFacingError("Missing required configuration: \(missing.joined(separator: ", "))")
        }

        guard !allowedStaffRoleIDs.isEmpty else {
            throw UserFacingError("Configure at least one staff role ID in the JSON config.")
        }

        guard !allowedConfigRoleIDs.isEmpty else {
            throw UserFacingError("Configure at least one config owner role ID in the JSON config.")
        }

        guard triggerCooldownSeconds > 0 else {
            throw UserFacingError("`triggerCooldownSeconds` must be greater than zero.")
        }

        guard leaveAuditLogLookbackSeconds > 0 else {
            throw UserFacingError("`leaveAuditLogLookbackSeconds` must be greater than zero.")
        }

        return BotConfigurationFile(
            applicationID: applicationID.trimmingCharacters(in: .whitespacesAndNewlines),
            guildID: guildID.trimmingCharacters(in: .whitespacesAndNewlines),
            defaultMemberRoleID: defaultMemberRoleID.trimmingCharacters(in: .whitespacesAndNewlines),
            allowedStaffRoleIDs: allowedStaffRoleIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            allowedConfigRoleIDs: allowedConfigRoleIDs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty },
            databasePath: databasePath.trimmingCharacters(in: .whitespacesAndNewlines),
            welcomeChannelID: Self.normalizedSnowflake(welcomeChannelID),
            leaveChannelID: Self.normalizedSnowflake(leaveChannelID),
            modLogChannelID: Self.normalizedSnowflake(modLogChannelID),
            suggestionsChannelID: Self.normalizedSnowflake(suggestionsChannelID),
            warnUsersViaDM: warnUsersViaDM,
            welcomeMessage: welcomeMessage,
            voluntaryLeaveMessage: voluntaryLeaveMessage,
            kickMessage: kickMessage,
            banMessage: banMessage,
            unknownRemovalMessage: unknownRemovalMessage,
            roleAssignmentFailureMessage: roleAssignmentFailureMessage,
            warningDMTemplate: warningDMTemplate,
            triggerCooldownSeconds: triggerCooldownSeconds,
            leaveAuditLogLookbackSeconds: leaveAuditLogLookbackSeconds,
            iconicTriggers: iconicTriggers
        )
    }

    var warnings: [String] {
        var messages: [String] = []
        if applicationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Application ID is not configured yet.")
        }
        if guildID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Guild ID is not configured yet.")
        }
        if defaultMemberRoleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            messages.append("Default member role ID is not configured yet.")
        }
        if allowedStaffRoleIDs.isEmpty {
            messages.append("No staff role IDs are configured yet.")
        }
        if allowedConfigRoleIDs.isEmpty {
            messages.append("No config owner role IDs are configured yet.")
        }
        if welcomeChannelID == nil {
            messages.append("Welcome channel is not configured yet. New-member welcome messages will be skipped.")
        }
        if leaveChannelID == nil {
            messages.append("Leave channel is not configured yet. Departure announcements will be skipped.")
        }
        if modLogChannelID == nil {
            messages.append("Mod log channel is not configured yet. Warning logging and some onboarding failure messages will be skipped.")
        }
        if suggestionsChannelID == nil {
            messages.append("Suggestions channel is not configured yet. Suggestions workflow will be unavailable until it is set.")
        }
        return messages
    }

    func prettyPrintedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw UserFacingError("Failed to render configuration.")
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

    var applicationID: String { file.applicationID }
    var guildID: String { file.guildID }
    var defaultMemberRoleID: String { file.defaultMemberRoleID }
    var allowedStaffRoleIDs: [String] { file.allowedStaffRoleIDs }
    var allowedConfigRoleIDs: [String] { file.allowedConfigRoleIDs }
    var databasePath: String { file.databasePath }
    var welcomeChannelID: String? { file.welcomeChannelID }
    var leaveChannelID: String? { file.leaveChannelID }
    var modLogChannelID: String? { file.modLogChannelID }
    var suggestionsChannelID: String? { file.suggestionsChannelID }
    var warnUsersViaDM: Bool { file.warnUsersViaDM }
    var welcomeMessage: String { file.welcomeMessage }
    var voluntaryLeaveMessage: String { file.voluntaryLeaveMessage }
    var kickMessage: String { file.kickMessage }
    var banMessage: String { file.banMessage }
    var unknownRemovalMessage: String { file.unknownRemovalMessage }
    var roleAssignmentFailureMessage: String { file.roleAssignmentFailureMessage }
    var warningDMTemplate: String { file.warningDMTemplate }
    var triggerCooldownSeconds: Double { file.triggerCooldownSeconds }
    var leaveAuditLogLookbackSeconds: Double { file.leaveAuditLogLookbackSeconds }
    var iconicTriggers: [IconicTriggerConfiguration] { file.iconicTriggers }

    var saySuccessMessage: String { "Sent." }

    static let requiredPermissionInteger = 268_438_656

    var installURL: String {
        "https://discord.com/oauth2/authorize?client_id=\(applicationID)&scope=bot%20applications.commands&permissions=\(Self.requiredPermissionInteger)"
    }
}

enum RuntimeConfigSetting: String, CaseIterable, Sendable {
    case welcomeChannelID = "welcome-channel-id"
    case leaveChannelID = "leave-channel-id"
    case modLogChannelID = "mod-log-channel-id"
    case suggestionsChannelID = "suggestions-channel-id"
    case warnUsersViaDM = "warn-users-via-dm"
    case welcomeMessage = "welcome-message"
    case voluntaryLeaveMessage = "voluntary-leave-message"
    case kickMessage = "kick-message"
    case banMessage = "ban-message"
    case unknownRemovalMessage = "unknown-removal-message"
    case roleAssignmentFailureMessage = "role-assignment-failure-message"
    case warningDMTemplate = "warning-dm-template"
    case triggerCooldownSeconds = "trigger-cooldown-seconds"
    case leaveAuditLogLookbackSeconds = "leave-audit-log-lookback-seconds"

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
            decoder.keyDecodingStrategy = .convertFromSnakeCase
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
        case .welcomeChannelID:
            next.welcomeChannelID = normalizeOptionalString(value)
        case .leaveChannelID:
            next.leaveChannelID = normalizeOptionalString(value)
        case .modLogChannelID:
            next.modLogChannelID = normalizeOptionalString(value)
        case .suggestionsChannelID:
            next.suggestionsChannelID = normalizeOptionalString(value)
        case .warnUsersViaDM:
            guard let parsed = Bool(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("`\(setting.rawValue)` expects `true` or `false`.")
            }
            next.warnUsersViaDM = parsed
        case .welcomeMessage:
            next.welcomeMessage = value
        case .voluntaryLeaveMessage:
            next.voluntaryLeaveMessage = value
        case .kickMessage:
            next.kickMessage = value
        case .banMessage:
            next.banMessage = value
        case .unknownRemovalMessage:
            next.unknownRemovalMessage = value
        case .roleAssignmentFailureMessage:
            next.roleAssignmentFailureMessage = value
        case .warningDMTemplate:
            next.warningDMTemplate = value
        case .triggerCooldownSeconds:
            guard let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("`\(setting.rawValue)` expects a number.")
            }
            next.triggerCooldownSeconds = parsed
        case .leaveAuditLogLookbackSeconds:
            guard let parsed = Double(value.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                throw UserFacingError("`\(setting.rawValue)` expects a number.")
            }
            next.leaveAuditLogLookbackSeconds = parsed
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func addTrigger(trigger: String, response: String) throws -> BotConfigurationFile {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        let normalizedResponse = try normalizedRequiredString(response, name: "response")

        var next = configurationFile
        if let index = next.iconicTriggers.firstIndex(where: { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }) {
            next.iconicTriggers[index] = IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse)
        } else {
            next.iconicTriggers.append(IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse))
        }

        configurationFile = try next.readyForRuntime(botToken: botToken.isEmpty ? "placeholder-token" : botToken)
        try persist(configurationFile: configurationFile)
        return configurationFile
    }

    func removeTrigger(trigger: String) throws -> Bool {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        var next = configurationFile
        let originalCount = next.iconicTriggers.count
        next.iconicTriggers.removeAll { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }

        guard next.iconicTriggers.count != originalCount else {
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
            throw UserFacingError("`\(name)` cannot be empty.")
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

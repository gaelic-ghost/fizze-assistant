import Foundation

struct InstallConfiguration: Codable, Sendable {
    // MARK: Stored Properties

    var applicationID: String
    var guildID: String
    var defaultMemberRoleID: String
    var allowedStaffRoleIDs: [String]
    var allowedConfigRoleIDs: [String]
    var databasePath: String
    var runtimeConfigPath: String

    // MARK: Defaults

    static let defaults = InstallConfiguration(
        applicationID: "",
        guildID: "",
        defaultMemberRoleID: "",
        allowedStaffRoleIDs: [],
        allowedConfigRoleIDs: [],
        databasePath: ".data/fizze-assistant.sqlite",
        runtimeConfigPath: ".data/runtime-config.json"
    )

    // MARK: Validation

    func readyForRuntime(botToken: String) throws -> InstallConfiguration {
        let requiredValues: [(String, String)] = [
            ("DISCORD_BOT_TOKEN", botToken),
            ("DISCORD_APPLICATION_ID", applicationID),
            ("DISCORD_GUILD_ID", guildID),
            ("DISCORD_DEFAULT_MEMBER_ROLE_ID", defaultMemberRoleID),
        ]

        let missing = requiredValues
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.0)

        guard missing.isEmpty else {
            throw UserFacingError("Missing required configuration: \(missing.joined(separator: ", "))")
        }

        guard !allowedStaffRoleIDs.isEmpty else {
            throw UserFacingError("Configure at least one staff role ID via `DISCORD_ALLOWED_STAFF_ROLE_IDS` or the local config file.")
        }

        guard !allowedConfigRoleIDs.isEmpty else {
            throw UserFacingError("Configure at least one config owner role ID via `DISCORD_ALLOWED_CONFIG_ROLE_IDS` or the local config file.")
        }

        return self
    }

    var setupWarnings: [String] {
        var warnings: [String] = []
        if applicationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Application ID is not configured yet.")
        }
        if guildID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Guild ID is not configured yet.")
        }
        if defaultMemberRoleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            warnings.append("Default member role ID is not configured yet.")
        }
        if allowedStaffRoleIDs.isEmpty {
            warnings.append("No staff role IDs are configured yet.")
        }
        if allowedConfigRoleIDs.isEmpty {
            warnings.append("No config owner role IDs are configured yet.")
        }
        return warnings
    }
}

struct RuntimeConfiguration: Codable, Sendable {
    // MARK: Stored Properties

    var welcomeChannelID: String?
    var leaveChannelID: String?
    var modLogChannelID: String?
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

    static let defaults = RuntimeConfiguration(
        welcomeChannelID: nil,
        leaveChannelID: nil,
        modLogChannelID: nil,
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

    func validated() throws -> RuntimeConfiguration {
        guard triggerCooldownSeconds > 0 else {
            throw UserFacingError("`triggerCooldownSeconds` must be greater than zero.")
        }

        guard leaveAuditLogLookbackSeconds > 0 else {
            throw UserFacingError("`leaveAuditLogLookbackSeconds` must be greater than zero.")
        }

        return RuntimeConfiguration(
            welcomeChannelID: Self.normalizedSnowflake(welcomeChannelID),
            leaveChannelID: Self.normalizedSnowflake(leaveChannelID),
            modLogChannelID: Self.normalizedSnowflake(modLogChannelID),
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
        if welcomeChannelID == nil {
            messages.append("Welcome channel is not configured yet. New-member welcome messages will be skipped.")
        }
        if leaveChannelID == nil {
            messages.append("Leave channel is not configured yet. Departure announcements will be skipped.")
        }
        if modLogChannelID == nil {
            messages.append("Mod log channel is not configured yet. Warning logging and some onboarding failure messages will be skipped.")
        }
        return messages
    }

    func prettyPrintedJSON() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard let string = String(data: data, encoding: .utf8) else {
            throw UserFacingError("Failed to render runtime configuration.")
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
    var install: InstallConfiguration
    var runtime: RuntimeConfiguration

    // MARK: Accessors

    var applicationID: String { install.applicationID }
    var guildID: String { install.guildID }
    var defaultMemberRoleID: String { install.defaultMemberRoleID }
    var allowedStaffRoleIDs: [String] { install.allowedStaffRoleIDs }
    var allowedConfigRoleIDs: [String] { install.allowedConfigRoleIDs }
    var databasePath: String { install.databasePath }
    var runtimeConfigPath: String { install.runtimeConfigPath }

    var welcomeChannelID: String? { runtime.welcomeChannelID }
    var leaveChannelID: String? { runtime.leaveChannelID }
    var modLogChannelID: String? { runtime.modLogChannelID }
    var warnUsersViaDM: Bool { runtime.warnUsersViaDM }
    var welcomeMessage: String { runtime.welcomeMessage }
    var voluntaryLeaveMessage: String { runtime.voluntaryLeaveMessage }
    var kickMessage: String { runtime.kickMessage }
    var banMessage: String { runtime.banMessage }
    var unknownRemovalMessage: String { runtime.unknownRemovalMessage }
    var roleAssignmentFailureMessage: String { runtime.roleAssignmentFailureMessage }
    var warningDMTemplate: String { runtime.warningDMTemplate }
    var triggerCooldownSeconds: Double { runtime.triggerCooldownSeconds }
    var leaveAuditLogLookbackSeconds: Double { runtime.leaveAuditLogLookbackSeconds }
    var iconicTriggers: [IconicTriggerConfiguration] { runtime.iconicTriggers }

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
    private let install: InstallConfiguration
    private let runtimeURL: URL
    private var runtime: RuntimeConfiguration

    // MARK: Lifecycle

    init(botToken: String, install: InstallConfiguration, runtime: RuntimeConfiguration) {
        self.botToken = botToken
        self.install = install
        self.runtime = runtime
        self.runtimeURL = URL(fileURLWithPath: install.runtimeConfigPath)
    }

    // MARK: Loading

    static func load(from localConfigURL: URL?, environment: [String: String]) throws -> ConfigurationStore {
        let botToken = environment["DISCORD_BOT_TOKEN"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        var install = InstallConfiguration.defaults
        if let localConfigURL {
            let data = try Data(contentsOf: localConfigURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            install = try decoder.decode(InstallConfiguration.self, from: data)
        }

        install.applicationID = environment["DISCORD_APPLICATION_ID"] ?? install.applicationID
        install.guildID = environment["DISCORD_GUILD_ID"] ?? install.guildID
        install.defaultMemberRoleID = environment["DISCORD_DEFAULT_MEMBER_ROLE_ID"] ?? install.defaultMemberRoleID
        install.databasePath = environment["FIZZE_DATABASE_PATH"] ?? install.databasePath
        install.runtimeConfigPath = environment["FIZZE_RUNTIME_CONFIG_PATH"] ?? install.runtimeConfigPath

        if let allowed = environment["DISCORD_ALLOWED_STAFF_ROLE_IDS"], !allowed.isEmpty {
            install.allowedStaffRoleIDs = allowed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let allowed = environment["DISCORD_ALLOWED_CONFIG_ROLE_IDS"], !allowed.isEmpty {
            install.allowedConfigRoleIDs = allowed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        let runtimeURL = URL(fileURLWithPath: install.runtimeConfigPath)
        let runtime: RuntimeConfiguration
        if FileManager.default.fileExists(atPath: runtimeURL.path) {
            let data = try Data(contentsOf: runtimeURL)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            runtime = try decoder.decode(RuntimeConfiguration.self, from: data).validated()
        } else {
            runtime = try RuntimeConfiguration.defaults.validated()
        }

        return ConfigurationStore(botToken: botToken, install: install, runtime: runtime)
    }

    // MARK: Accessors

    func currentConfiguration() -> AppConfiguration {
        AppConfiguration(botToken: botToken, install: install, runtime: runtime)
    }

    func readyConfiguration() throws -> AppConfiguration {
        AppConfiguration(
            botToken: botToken,
            install: try install.readyForRuntime(botToken: botToken),
            runtime: try runtime.validated()
        )
    }

    func installConfiguration() -> InstallConfiguration {
        install
    }

    func runtimeConfiguration() -> RuntimeConfiguration {
        runtime
    }

    // MARK: Runtime File Management

    @discardableResult
    func initializeRuntimeConfigurationFileIfNeeded() throws -> URL {
        if FileManager.default.fileExists(atPath: runtimeURL.path) {
            return runtimeURL
        }

        try persist(runtimeConfiguration: runtime)
        return runtimeURL
    }

    func update(setting: RuntimeConfigSetting, value: String) throws -> RuntimeConfiguration {
        var next = runtime
        switch setting {
        case .welcomeChannelID:
            next.welcomeChannelID = normalizeOptionalString(value)
        case .leaveChannelID:
            next.leaveChannelID = normalizeOptionalString(value)
        case .modLogChannelID:
            next.modLogChannelID = normalizeOptionalString(value)
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

        runtime = try next.validated()
        try persist(runtimeConfiguration: runtime)
        return runtime
    }

    func addTrigger(trigger: String, response: String) throws -> RuntimeConfiguration {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        let normalizedResponse = try normalizedRequiredString(response, name: "response")

        var next = runtime
        if let index = next.iconicTriggers.firstIndex(where: { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }) {
            next.iconicTriggers[index] = IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse)
        } else {
            next.iconicTriggers.append(IconicTriggerConfiguration(trigger: normalizedTrigger, response: normalizedResponse))
        }

        runtime = try next.validated()
        try persist(runtimeConfiguration: runtime)
        return runtime
    }

    func removeTrigger(trigger: String) throws -> Bool {
        let normalizedTrigger = try normalizedRequiredString(trigger, name: "trigger")
        var next = runtime
        let originalCount = next.iconicTriggers.count
        next.iconicTriggers.removeAll { $0.trigger.caseInsensitiveCompare(normalizedTrigger) == .orderedSame }

        guard next.iconicTriggers.count != originalCount else {
            return false
        }

        runtime = try next.validated()
        try persist(runtimeConfiguration: runtime)
        return true
    }

    // MARK: Helpers

    private func persist(runtimeConfiguration: RuntimeConfiguration) throws {
        let directoryURL = runtimeURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(runtimeConfiguration)

        let temporaryURL = directoryURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: .atomic)

        if FileManager.default.fileExists(atPath: runtimeURL.path) {
            try FileManager.default.removeItem(at: runtimeURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: runtimeURL)
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

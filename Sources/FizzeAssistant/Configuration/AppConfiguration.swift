import Foundation

struct AppConfiguration: Codable, Sendable {
    // MARK: Stored Properties

    var botToken: String
    var applicationID: String
    var guildID: String
    var welcomeChannelID: String
    var leaveChannelID: String
    var modLogChannelID: String
    var defaultMemberRoleID: String
    var allowedStaffRoleIDs: [String]
    var databasePath: String
    var warnUsersViaDM: Bool
    var welcomeMessage: String
    var voluntaryLeaveMessage: String
    var kickMessage: String
    var banMessage: String
    var unknownRemovalMessage: String
    var roleAssignmentFailureMessage: String
    var saySuccessMessage: String
    var warningDMTemplate: String
    var triggerCooldownSeconds: Double
    var leaveAuditLogLookbackSeconds: Double
    var iconicTriggers: [IconicTriggerConfiguration]

    // MARK: Loading

    static func load(from url: URL?, environment: [String: String]) throws -> AppConfiguration {
        var base = AppConfiguration.defaults

        if let url {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            base = try decoder.decode(AppConfiguration.self, from: data)
        }

        return try base.overlaying(environment: environment)
    }

    // MARK: Defaults

    static let defaults = AppConfiguration(
        botToken: "",
        applicationID: "",
        guildID: "",
        welcomeChannelID: "",
        leaveChannelID: "",
        modLogChannelID: "",
        defaultMemberRoleID: "",
        allowedStaffRoleIDs: [],
        databasePath: ".data/fizze-assistant.sqlite",
        warnUsersViaDM: false,
        welcomeMessage: "Welcome to the server, {user_mention}!",
        voluntaryLeaveMessage: "{username} left the server.",
        kickMessage: "{username} was kicked from the server.",
        banMessage: "{username} was banned from the server.",
        unknownRemovalMessage: "{username} left or was removed from the server.",
        roleAssignmentFailureMessage: "I couldn't assign the default member role to {user_mention}. Please check role hierarchy and `Manage Roles` permissions.",
        saySuccessMessage: "Sent.",
        warningDMTemplate: "You have been warned in {guild_name}: {reason}",
        triggerCooldownSeconds: 30,
        leaveAuditLogLookbackSeconds: 30,
        iconicTriggers: []
    )

    // MARK: Validation

    func validated() throws -> AppConfiguration {
        let requiredValues: [(String, String)] = [
            ("DISCORD_BOT_TOKEN", botToken),
            ("DISCORD_APPLICATION_ID", applicationID),
            ("DISCORD_GUILD_ID", guildID),
            ("DISCORD_WELCOME_CHANNEL_ID", welcomeChannelID),
            ("DISCORD_LEAVE_CHANNEL_ID", leaveChannelID),
            ("DISCORD_MOD_LOG_CHANNEL_ID", modLogChannelID),
            ("DISCORD_DEFAULT_MEMBER_ROLE_ID", defaultMemberRoleID),
        ]

        let missing = requiredValues
            .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(\.0)

        guard missing.isEmpty else {
            throw UserFacingError("Missing required configuration: \(missing.joined(separator: ", "))")
        }

        guard !allowedStaffRoleIDs.isEmpty else {
            throw UserFacingError("Configure at least one staff role ID via `DISCORD_ALLOWED_STAFF_ROLE_IDS` or the config file.")
        }

        return self
    }

    // MARK: Helpers

    private func overlaying(environment: [String: String]) throws -> AppConfiguration {
        var copy = self

        copy.botToken = environment["DISCORD_BOT_TOKEN"] ?? copy.botToken
        copy.applicationID = environment["DISCORD_APPLICATION_ID"] ?? copy.applicationID
        copy.guildID = environment["DISCORD_GUILD_ID"] ?? copy.guildID
        copy.welcomeChannelID = environment["DISCORD_WELCOME_CHANNEL_ID"] ?? copy.welcomeChannelID
        copy.leaveChannelID = environment["DISCORD_LEAVE_CHANNEL_ID"] ?? copy.leaveChannelID
        copy.modLogChannelID = environment["DISCORD_MOD_LOG_CHANNEL_ID"] ?? copy.modLogChannelID
        copy.defaultMemberRoleID = environment["DISCORD_DEFAULT_MEMBER_ROLE_ID"] ?? copy.defaultMemberRoleID
        copy.databasePath = environment["FIZZE_DATABASE_PATH"] ?? copy.databasePath
        copy.warnUsersViaDM = environment["FIZZE_WARN_USERS_VIA_DM"].flatMap(Bool.init) ?? copy.warnUsersViaDM
        copy.welcomeMessage = environment["FIZZE_WELCOME_MESSAGE"] ?? copy.welcomeMessage
        copy.voluntaryLeaveMessage = environment["FIZZE_VOLUNTARY_LEAVE_MESSAGE"] ?? copy.voluntaryLeaveMessage
        copy.kickMessage = environment["FIZZE_KICK_MESSAGE"] ?? copy.kickMessage
        copy.banMessage = environment["FIZZE_BAN_MESSAGE"] ?? copy.banMessage
        copy.unknownRemovalMessage = environment["FIZZE_UNKNOWN_REMOVAL_MESSAGE"] ?? copy.unknownRemovalMessage
        copy.roleAssignmentFailureMessage = environment["FIZZE_ROLE_ASSIGNMENT_FAILURE_MESSAGE"] ?? copy.roleAssignmentFailureMessage
        copy.saySuccessMessage = environment["FIZZE_SAY_SUCCESS_MESSAGE"] ?? copy.saySuccessMessage
        copy.warningDMTemplate = environment["FIZZE_WARNING_DM_TEMPLATE"] ?? copy.warningDMTemplate

        if let allowed = environment["DISCORD_ALLOWED_STAFF_ROLE_IDS"], !allowed.isEmpty {
            copy.allowedStaffRoleIDs = allowed
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        if let cooldown = environment["FIZZE_TRIGGER_COOLDOWN_SECONDS"], let value = Double(cooldown) {
            copy.triggerCooldownSeconds = value
        }

        if let cooldown = environment["FIZZE_LEAVE_AUDIT_LOG_LOOKBACK_SECONDS"], let value = Double(cooldown) {
            copy.leaveAuditLogLookbackSeconds = value
        }

        if let rawTriggers = environment["FIZZE_ICONIC_TRIGGERS_JSON"], !rawTriggers.isEmpty {
            let decoder = JSONDecoder()
            let data = Data(rawTriggers.utf8)
            copy.iconicTriggers = try decoder.decode([IconicTriggerConfiguration].self, from: data)
        }

        return try copy.validated()
    }
}

struct IconicTriggerConfiguration: Codable, Hashable, Sendable {
    var trigger: String
    var response: String
}

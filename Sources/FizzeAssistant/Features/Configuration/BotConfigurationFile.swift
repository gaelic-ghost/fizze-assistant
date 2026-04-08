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
    var bot_mention_responses: [String]
    var trigger_cooldown_seconds: Double
    var leave_audit_log_lookback_seconds: Double
    var trigger_matching_mode: IconicTriggerMatchingMode
    var iconic_messages: [String: IconicMessageConfiguration]

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
        bot_mention_responses: [
            "Fizze Assistant, at your service, {user_mention}.",
            "*robot noises*",
        ],
        trigger_cooldown_seconds: 30,
        leave_audit_log_lookback_seconds: 30,
        trigger_matching_mode: .exact,
        iconic_messages: [:]
    )

    // MARK: Lifecycle

    init(
        application_id: String,
        guild_id: String,
        default_member_role_id: String,
        allowed_staff_role_ids: [String],
        allowed_config_role_ids: [String],
        database_path: String,
        welcome_channel_id: String?,
        leave_channel_id: String?,
        mod_log_channel_id: String?,
        suggestions_channel_id: String?,
        warn_users_via_dm: Bool,
        welcome_message: String,
        voluntary_leave_message: String,
        kick_message: String,
        ban_message: String,
        unknown_removal_message: String,
        role_assignment_failure_message: String,
        warning_dm_template: String,
        bot_mention_responses: [String],
        trigger_cooldown_seconds: Double,
        leave_audit_log_lookback_seconds: Double,
        trigger_matching_mode: IconicTriggerMatchingMode,
        iconic_messages: [String: IconicMessageConfiguration]
    ) {
        self.application_id = application_id
        self.guild_id = guild_id
        self.default_member_role_id = default_member_role_id
        self.allowed_staff_role_ids = allowed_staff_role_ids
        self.allowed_config_role_ids = allowed_config_role_ids
        self.database_path = database_path
        self.welcome_channel_id = welcome_channel_id
        self.leave_channel_id = leave_channel_id
        self.mod_log_channel_id = mod_log_channel_id
        self.suggestions_channel_id = suggestions_channel_id
        self.warn_users_via_dm = warn_users_via_dm
        self.welcome_message = welcome_message
        self.voluntary_leave_message = voluntary_leave_message
        self.kick_message = kick_message
        self.ban_message = ban_message
        self.unknown_removal_message = unknown_removal_message
        self.role_assignment_failure_message = role_assignment_failure_message
        self.warning_dm_template = warning_dm_template
        self.bot_mention_responses = bot_mention_responses
        self.trigger_cooldown_seconds = trigger_cooldown_seconds
        self.leave_audit_log_lookback_seconds = leave_audit_log_lookback_seconds
        self.trigger_matching_mode = trigger_matching_mode
        self.iconic_messages = iconic_messages
    }

    // MARK: Codable

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        application_id = try container.decode(String.self, forKey: .application_id)
        guild_id = try container.decode(String.self, forKey: .guild_id)
        default_member_role_id = try container.decode(String.self, forKey: .default_member_role_id)
        allowed_staff_role_ids = try container.decode([String].self, forKey: .allowed_staff_role_ids)
        allowed_config_role_ids = try container.decode([String].self, forKey: .allowed_config_role_ids)
        database_path = try container.decode(String.self, forKey: .database_path)
        welcome_channel_id = try container.decodeIfPresent(String.self, forKey: .welcome_channel_id)
        leave_channel_id = try container.decodeIfPresent(String.self, forKey: .leave_channel_id)
        mod_log_channel_id = try container.decodeIfPresent(String.self, forKey: .mod_log_channel_id)
        suggestions_channel_id = try container.decodeIfPresent(String.self, forKey: .suggestions_channel_id)
        warn_users_via_dm = try container.decode(Bool.self, forKey: .warn_users_via_dm)
        welcome_message = try container.decode(String.self, forKey: .welcome_message)
        voluntary_leave_message = try container.decode(String.self, forKey: .voluntary_leave_message)
        kick_message = try container.decode(String.self, forKey: .kick_message)
        ban_message = try container.decode(String.self, forKey: .ban_message)
        unknown_removal_message = try container.decode(String.self, forKey: .unknown_removal_message)
        role_assignment_failure_message = try container.decode(String.self, forKey: .role_assignment_failure_message)
        warning_dm_template = try container.decode(String.self, forKey: .warning_dm_template)
        bot_mention_responses = try container.decodeIfPresent([String].self, forKey: .bot_mention_responses) ?? Self.defaults.bot_mention_responses
        trigger_cooldown_seconds = try container.decode(Double.self, forKey: .trigger_cooldown_seconds)
        leave_audit_log_lookback_seconds = try container.decode(Double.self, forKey: .leave_audit_log_lookback_seconds)
        trigger_matching_mode = try container.decode(IconicTriggerMatchingMode.self, forKey: .trigger_matching_mode)
        iconic_messages = try container.decode([String: IconicMessageConfiguration].self, forKey: .iconic_messages)
    }

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
            throw UserFacingError("BotConfigurationFile.readyForRuntime: the bot cannot start until these required values are filled in: \(missing.joined(separator: ", ")). The most likely cause is that the active JSON config file or `DISCORD_BOT_TOKEN` is still incomplete.")
        }

        guard !allowed_staff_role_ids.isEmpty else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `allowed_staff_role_ids` is empty in the active JSON config file, so staff commands would have no authorized roles. Add at least one staff role ID and try again.")
        }

        guard !allowed_config_role_ids.isEmpty else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `allowed_config_role_ids` is empty in the active JSON config file, so `/config` would have no authorized owners. Add at least one config-owner role ID and try again.")
        }

        guard trigger_cooldown_seconds > 0 else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `trigger_cooldown_seconds` in the active JSON config file must be greater than zero. The most likely cause is a zero or negative number in the config file.")
        }

        guard leave_audit_log_lookback_seconds > 0 else {
            throw UserFacingError("BotConfigurationFile.readyForRuntime: `leave_audit_log_lookback_seconds` in the active JSON config file must be greater than zero. The most likely cause is a zero or negative number in the config file.")
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
            bot_mention_responses: Self.normalizedMessageTemplates(bot_mention_responses),
            trigger_cooldown_seconds: trigger_cooldown_seconds,
            leave_audit_log_lookback_seconds: leave_audit_log_lookback_seconds,
            trigger_matching_mode: trigger_matching_mode,
            iconic_messages: try Self.normalizedIconicMessages(iconic_messages)
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

    // MARK: Helpers

    private static func normalizedSnowflake(_ value: String?) -> String? {
        guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw
    }

    private static func normalizedMessageTemplates(_ values: [String]) -> [String] {
        values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func normalizedIconicMessages(_ messages: [String: IconicMessageConfiguration]) throws -> [String: IconicMessageConfiguration] {
        var normalized: [String: IconicMessageConfiguration] = [:]
        for (trigger, message) in messages {
            let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(trigger)
            normalized[normalizedTrigger] = try message.readyForRuntime(trigger: normalizedTrigger)
        }
        return normalized
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
    var bot_mention_responses: [String] { file.bot_mention_responses }
    var trigger_cooldown_seconds: Double { file.trigger_cooldown_seconds }
    var leave_audit_log_lookback_seconds: Double { file.leave_audit_log_lookback_seconds }
    var trigger_matching_mode: IconicTriggerMatchingMode { file.trigger_matching_mode }
    var iconic_messages: [String: IconicMessageConfiguration] { file.iconic_messages }

    var say_success_message: String { "Sent." }

    // MARK: Static Properties

    static let required_permission_integer = 268_438_656

    // MARK: Derived Values

    var install_url: String {
        "https://discord.com/oauth2/authorize?client_id=\(application_id)&scope=bot%20applications.commands&permissions=\(Self.required_permission_integer)"
    }
}

enum IconicTriggerMatchingMode: String, Codable, CaseIterable, Sendable {
    // MARK: Cases

    case exact = "exact"
    case fuzze = "fuzze"
}

struct IconicMessageConfiguration: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var content: String?
    var embeds: [DiscordEmbed]?

    // MARK: Public API

    var discordMessageCreate: DiscordMessageCreate {
        DiscordMessageCreate(content: content, embeds: embeds, flags: nil)
    }

    var payloadSummary: String {
        switch (content != nil, embeds?.isEmpty == false) {
        case (true, true):
            return "text + embeds"
        case (true, false):
            return "text"
        case (false, true):
            return "embeds"
        case (false, false):
            return "empty"
        }
    }

    func readyForRuntime(trigger: String) throws -> IconicMessageConfiguration {
        let trimmedContent = content?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedContent = trimmedContent?.isEmpty == true ? nil : trimmedContent
        let normalizedEmbeds = embeds?.isEmpty == true ? nil : embeds

        guard normalizedContent != nil || normalizedEmbeds != nil else {
            throw UserFacingError("IconicMessageConfiguration.readyForRuntime: iconic message `\(trigger)` must include text content, embeds, or both. The most likely cause is an empty iconic-message entry in the active JSON config file.")
        }

        return IconicMessageConfiguration(content: normalizedContent, embeds: normalizedEmbeds)
    }

    // MARK: Trigger Normalization

    static func normalizedTrigger(_ trigger: String) throws -> String {
        let normalized = trigger.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            throw UserFacingError("IconicMessageConfiguration.normalizedTrigger: iconic-message triggers cannot be blank. The most likely cause is an empty trigger key in the active JSON config file or `/config trigger-add`.")
        }
        return normalized
    }
}

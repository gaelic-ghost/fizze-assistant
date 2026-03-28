import Foundation
import Logging

struct InteractionCallbackPayload: Codable, Sendable {
    var type: Int
    var data: DiscordMessageCreate?
}

actor InteractionHandler {
    let restClient: DiscordRESTClient
    let configurationStore: ConfigurationStore
    let warningStore: WarningStore
    let logger: Logger

    init(restClient: DiscordRESTClient, configurationStore: ConfigurationStore, warningStore: WarningStore, logger: Logger) {
        self.restClient = restClient
        self.configurationStore = configurationStore
        self.warningStore = warningStore
        self.logger = logger
    }

    func handle(_ interaction: DiscordInteraction, guildName: String) async {
        guard interaction.type == 2, let data = interaction.data else {
            return
        }

        do {
            let configuration = await configurationStore.currentConfiguration()

            switch data.name {
            case "say":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let channel_id = try requireOption(named: "channel", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "channel")
                let message = try requireOption(named: "message", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "message")
                try await restClient.createMessage(channel_id: channel_id, content: message)
                try await respond(interaction, content: configuration.say_success_message, ephemeral: true)

            case "warn":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                guard let mod_log_channel_id = configuration.mod_log_channel_id else {
                    throw UserFacingError("InteractionHandler.handle warn: `/warn` needs `mod_log_channel_id` in `fizze-assistant.json` before it can record warnings. The most likely cause is that the mod log channel has not been configured yet.")
                }
                let user_id = try requireOption(named: "user", from: data, commandName: "warn").stringValueRequired(commandName: "warn", optionName: "user")
                let reason = try requireOption(named: "reason", from: data, commandName: "warn").stringValueRequired(commandName: "warn", optionName: "reason")
                let moderator_id = interaction.member?.user?.id ?? "unknown"
                let warning = try await warningStore.createWarning(
                    guild_id: configuration.guild_id,
                    user_id: user_id,
                    moderator_user_id: moderator_id,
                    reason: reason
                )
                try await restClient.createMessage(
                    channel_id: mod_log_channel_id,
                    content: "Warning \(warning.id) recorded for <@\(user_id)> by <@\(moderator_id)>: \(reason)"
                )
                if configuration.warn_users_via_dm {
                    let dmChannel = try await restClient.createDMChannel(recipient_id: user_id)
                    let dmMessage = configuration.warning_dm_template
                        .replacingOccurrences(of: "{reason}", with: reason)
                        .replacingOccurrences(of: "{guild_name}", with: guildName)
                    try await restClient.createMessage(channel_id: dmChannel.id, content: dmMessage)
                }
                try await respond(interaction, content: "Warning recorded as `\(warning.id)`.", ephemeral: true)

            case "warns":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let user_id = try requireOption(named: "user", from: data, commandName: "warns").stringValueRequired(commandName: "warns", optionName: "user")
                let warnings = try await warningStore.warnings(for: user_id, guild_id: configuration.guild_id)
                let content: String
                if warnings.isEmpty {
                    content = "No warnings recorded for <@\(user_id)>."
                } else {
                    content = warnings.map { warning in
                        let timestamp = ISO8601DateFormatter().string(from: warning.created_at)
                        return "`\(warning.id)` • \(timestamp) • <@\(warning.moderator_user_id)> • \(warning.reason)"
                    }.joined(separator: "\n")
                }
                try await respond(interaction, content: content, ephemeral: true)

            case "clear-warning":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let warningID = try requireOption(named: "warning_id", from: data, commandName: "clear-warning").stringValueRequired(commandName: "clear-warning", optionName: "warning_id")
                let deleted = try await warningStore.deleteWarning(id: warningID)
                try await respond(interaction, content: deleted ? "Deleted warning `\(warningID)`." : "No warning found with ID `\(warningID)`.", ephemeral: true)

            case "clear-warnings":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let user_id = try requireOption(named: "user", from: data, commandName: "clear-warnings").stringValueRequired(commandName: "clear-warnings", optionName: "user")
                let deleted = try await warningStore.deleteWarnings(for: user_id, guild_id: configuration.guild_id)
                try await respond(interaction, content: "Deleted \(deleted) warnings for <@\(user_id)>.", ephemeral: true)

            case "config":
                try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
                try await handleConfigCommand(interaction, data: data)

            default:
                try await respond(interaction, content: "That command isn't implemented yet.", ephemeral: true)
            }
        } catch {
            logger.warning("InteractionHandler.handle: a slash command hit an error path, and the bot is trying to return a human-readable reply instead of failing silently.", metadata: ["error": .string(String(describing: error))])
            try? await respond(
                interaction,
                content: (error as? LocalizedError)?.errorDescription ?? "InteractionHandler.handle: the command did not finish cleanly, so the bot sent this fallback reply instead. The most likely cause is a missing Discord permission or a configuration mismatch in `fizze-assistant.json`.",
                ephemeral: true
            )
        }
    }

    private func respond(_ interaction: DiscordInteraction, content: String, ephemeral: Bool) async throws {
        let payload = InteractionCallbackPayload(
            type: 4,
            data: DiscordMessageCreate(content: content, flags: ephemeral ? 64 : nil)
        )
        try await restClient.createInteractionResponse(
            interaction_id: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }

    private func ensureStaffAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isStaffAuthorized(for: configuration) == true else {
            throw UserFacingError("InteractionHandler.ensureStaffAuthorized: this command is limited to configured staff roles, or members with Discord `Administrator` or `Manage Server` permissions. The most likely cause is that your server roles do not match `allowed_staff_role_ids` in `fizze-assistant.json` yet.")
        }
    }

    private func ensureConfigAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isConfigAuthorized(for: configuration) == true else {
            throw UserFacingError("InteractionHandler.ensureConfigAuthorized: `/config` is limited to configured config-owner roles, or members with Discord `Administrator` or `Manage Server` permissions. The most likely cause is that your server roles do not match `allowed_config_role_ids` in `fizze-assistant.json` yet.")
        }
    }

    private func requireOption(named name: String, from data: DiscordInteractionData, commandName: String) throws -> JSONValue {
        guard let value = data.options?.first(where: { $0.name == name })?.value else {
            throw UserFacingError("InteractionHandler.requireOption: Discord sent `/\(commandName)` without the `\(name)` option, so the command cannot continue. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
        return value
    }

    private func requireNestedOption(named name: String, from options: [DiscordInteractionOption], commandName: String, subcommandName: String) throws -> JSONValue {
        guard let value = options.first(where: { $0.name == name })?.value else {
            throw UserFacingError("InteractionHandler.requireNestedOption: Discord sent `/\(commandName) \(subcommandName)` without the `\(name)` option, so the command cannot continue. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
        return value
    }

    private func handleConfigCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData) async throws {
        guard let subcommand = data.options?.first else {
            throw UserFacingError("InteractionHandler.handleConfigCommand: Discord sent `/config` without a subcommand, so the bot does not know which config action to run. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }

        let options = subcommand.options ?? []
        switch subcommand.name {
        case "show":
            let configurationFile = await configurationStore.configurationFileContents()
            let json = try configurationFile.prettyPrintedJSON()
            try await respond(interaction, content: "```json\n\(json)\n```", ephemeral: true)

        case "set":
            let key = try requireNestedOption(named: "setting", from: options, commandName: "config", subcommandName: "set").stringValueRequired(commandName: "config set", optionName: "setting")
            guard let setting = RuntimeConfigSetting(rawValue: key) else {
                throw UserFacingError("InteractionHandler.handleConfigCommand: `/config set` received the unknown setting `\(key)`. Allowed settings are: \(RuntimeConfigSetting.allowedKeysText). The most likely cause is a typo in the command option.")
            }
            let value = try requireNestedOption(named: "value", from: options, commandName: "config", subcommandName: "set").stringValueRequired(commandName: "config set", optionName: "value")
            _ = try await configurationStore.update(setting: setting, value: value)
            try await respond(interaction, content: "Updated `\(setting.rawValue)`.", ephemeral: true)

        case "trigger-add":
            let trigger = try requireNestedOption(named: "trigger", from: options, commandName: "config", subcommandName: "trigger-add").stringValueRequired(commandName: "config trigger-add", optionName: "trigger")
            let responseText = try requireNestedOption(named: "response", from: options, commandName: "config", subcommandName: "trigger-add").stringValueRequired(commandName: "config trigger-add", optionName: "response")
            _ = try await configurationStore.addTrigger(trigger: trigger, response: responseText)
            try await respond(interaction, content: "Saved trigger `\(trigger)`.", ephemeral: true)

        case "trigger-remove":
            let trigger = try requireNestedOption(named: "trigger", from: options, commandName: "config", subcommandName: "trigger-remove").stringValueRequired(commandName: "config trigger-remove", optionName: "trigger")
            let removed = try await configurationStore.removeTrigger(trigger: trigger)
            try await respond(interaction, content: removed ? "Removed trigger `\(trigger)`." : "No trigger matched `\(trigger)`.", ephemeral: true)

        case "trigger-list":
            let runtime = await configurationStore.configurationFileContents()
            let content: String
            if runtime.iconic_triggers.isEmpty {
                content = "No exact-match triggers are configured."
            } else {
                content = runtime.iconic_triggers.map { "`\($0.trigger)` -> \($0.response)" }.joined(separator: "\n")
            }
            try await respond(interaction, content: content, ephemeral: true)

        default:
            throw UserFacingError("InteractionHandler.handleConfigCommand: `/config` received the unknown subcommand `\(subcommand.name)`, so the bot could not match it to a config action. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
    }
}

private extension JSONValue {
    func stringValueRequired(commandName: String, optionName: String) throws -> String {
        if let stringValue {
            return stringValue
        }
        throw UserFacingError("InteractionHandler.JSONValue.stringValueRequired: `/\(commandName)` received a non-text value for `\(optionName)`, but this option must be plain text. The most likely cause is that the slash command definition in Discord is out of date; rerun command registration.")
    }
}

private extension DiscordInteractionMember {
    func isStaffAuthorized(for configuration: AppConfiguration) -> Bool {
        hasServerManagementPrivileges || !Set(roles).isDisjoint(with: configuration.allowed_staff_role_ids)
    }

    func isConfigAuthorized(for configuration: AppConfiguration) -> Bool {
        hasServerManagementPrivileges || !Set(roles).isDisjoint(with: configuration.allowed_config_role_ids)
    }

    var hasServerManagementPrivileges: Bool {
        let permissions = permissionSet
        return permissions.contains(.administrator) || permissions.contains(.manageGuild)
    }
}

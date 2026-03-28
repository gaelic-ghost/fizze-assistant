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
                let channelID = try requireOption(named: "channel", from: data).stringValueRequired
                let message = try requireOption(named: "message", from: data).stringValueRequired
                try await restClient.createMessage(channelID: channelID, content: message)
                try await respond(interaction, content: configuration.saySuccessMessage, ephemeral: true)

            case "warn":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                guard let modLogChannelID = configuration.modLogChannelID else {
                    throw UserFacingError("The mod log channel is not configured yet.")
                }
                let userID = try requireOption(named: "user", from: data).stringValueRequired
                let reason = try requireOption(named: "reason", from: data).stringValueRequired
                let moderatorID = interaction.member?.user?.id ?? "unknown"
                let warning = try await warningStore.createWarning(
                    guildID: configuration.guildID,
                    userID: userID,
                    moderatorUserID: moderatorID,
                    reason: reason
                )
                try await restClient.createMessage(
                    channelID: modLogChannelID,
                    content: "Warning \(warning.id) recorded for <@\(userID)> by <@\(moderatorID)>: \(reason)"
                )
                if configuration.warnUsersViaDM {
                    let dmChannel = try await restClient.createDMChannel(recipientID: userID)
                    let dmMessage = configuration.warningDMTemplate
                        .replacingOccurrences(of: "{reason}", with: reason)
                        .replacingOccurrences(of: "{guild_name}", with: guildName)
                    try await restClient.createMessage(channelID: dmChannel.id, content: dmMessage)
                }
                try await respond(interaction, content: "Warning recorded as `\(warning.id)`.", ephemeral: true)

            case "warns":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let userID = try requireOption(named: "user", from: data).stringValueRequired
                let warnings = try await warningStore.warnings(for: userID, guildID: configuration.guildID)
                let content: String
                if warnings.isEmpty {
                    content = "No warnings recorded for <@\(userID)>."
                } else {
                    content = warnings.map { warning in
                        let timestamp = ISO8601DateFormatter().string(from: warning.createdAt)
                        return "`\(warning.id)` • \(timestamp) • <@\(warning.moderatorUserID)> • \(warning.reason)"
                    }.joined(separator: "\n")
                }
                try await respond(interaction, content: content, ephemeral: true)

            case "clear-warning":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let warningID = try requireOption(named: "warning_id", from: data).stringValueRequired
                let deleted = try await warningStore.deleteWarning(id: warningID)
                try await respond(interaction, content: deleted ? "Deleted warning `\(warningID)`." : "No warning found with ID `\(warningID)`.", ephemeral: true)

            case "clear-warnings":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                let userID = try requireOption(named: "user", from: data).stringValueRequired
                let deleted = try await warningStore.deleteWarnings(for: userID, guildID: configuration.guildID)
                try await respond(interaction, content: "Deleted \(deleted) warnings for <@\(userID)>.", ephemeral: true)

            case "config":
                try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
                try await handleConfigCommand(interaction, data: data)

            default:
                try await respond(interaction, content: "That command isn't implemented yet.", ephemeral: true)
            }
        } catch {
            logger.error("Failed to handle interaction.", metadata: ["error": .string(String(describing: error))])
            try? await respond(
                interaction,
                content: (error as? LocalizedError)?.errorDescription ?? "I couldn't complete that command. Please check my permissions and configuration, then try again.",
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
            interactionID: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }

    private func ensureStaffAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isStaffAuthorized(for: configuration) == true else {
            throw UserFacingError("You are not allowed to use this command.")
        }
    }

    private func ensureConfigAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isConfigAuthorized(for: configuration) == true else {
            throw UserFacingError("You are not allowed to change the bot configuration.")
        }
    }

    private func requireOption(named name: String, from data: DiscordInteractionData) throws -> JSONValue {
        guard let value = data.options?.first(where: { $0.name == name })?.value else {
            throw UserFacingError("Missing command option \(name).")
        }
        return value
    }

    private func requireNestedOption(named name: String, from options: [DiscordInteractionOption]) throws -> JSONValue {
        guard let value = options.first(where: { $0.name == name })?.value else {
            throw UserFacingError("Missing command option \(name).")
        }
        return value
    }

    private func handleConfigCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData) async throws {
        guard let subcommand = data.options?.first else {
            throw UserFacingError("Missing config subcommand.")
        }

        let options = subcommand.options ?? []
        switch subcommand.name {
        case "show":
            let configurationFile = await configurationStore.configurationFileContents()
            let json = try configurationFile.prettyPrintedJSON()
            try await respond(interaction, content: "```json\n\(json)\n```", ephemeral: true)

        case "set":
            let key = try requireNestedOption(named: "setting", from: options).stringValueRequired
            guard let setting = RuntimeConfigSetting(rawValue: key) else {
                throw UserFacingError("Unknown setting. Allowed keys: \(RuntimeConfigSetting.allowedKeysText)")
            }
            let value = try requireNestedOption(named: "value", from: options).stringValueRequired
            _ = try await configurationStore.update(setting: setting, value: value)
            try await respond(interaction, content: "Updated `\(setting.rawValue)`.", ephemeral: true)

        case "trigger-add":
            let trigger = try requireNestedOption(named: "trigger", from: options).stringValueRequired
            let responseText = try requireNestedOption(named: "response", from: options).stringValueRequired
            _ = try await configurationStore.addTrigger(trigger: trigger, response: responseText)
            try await respond(interaction, content: "Saved trigger `\(trigger)`.", ephemeral: true)

        case "trigger-remove":
            let trigger = try requireNestedOption(named: "trigger", from: options).stringValueRequired
            let removed = try await configurationStore.removeTrigger(trigger: trigger)
            try await respond(interaction, content: removed ? "Removed trigger `\(trigger)`." : "No trigger matched `\(trigger)`.", ephemeral: true)

        case "trigger-list":
            let runtime = await configurationStore.configurationFileContents()
            let content: String
            if runtime.iconicTriggers.isEmpty {
                content = "No exact-match triggers are configured."
            } else {
                content = runtime.iconicTriggers.map { "`\($0.trigger)` -> \($0.response)" }.joined(separator: "\n")
            }
            try await respond(interaction, content: content, ephemeral: true)

        default:
            throw UserFacingError("Unknown config subcommand.")
        }
    }
}

private extension JSONValue {
    var stringValueRequired: String {
        get throws {
            if let stringValue {
                return stringValue
            }
            throw UserFacingError("Expected a string option value.")
        }
    }
}

private extension DiscordInteractionMember {
    func isStaffAuthorized(for configuration: AppConfiguration) -> Bool {
        hasServerManagementPrivileges || !Set(roles).isDisjoint(with: configuration.allowedStaffRoleIDs)
    }

    func isConfigAuthorized(for configuration: AppConfiguration) -> Bool {
        hasServerManagementPrivileges || !Set(roles).isDisjoint(with: configuration.allowedConfigRoleIDs)
    }

    var hasServerManagementPrivileges: Bool {
        let permissions = permissionSet
        return permissions.contains(.administrator) || permissions.contains(.manageGuild)
    }
}

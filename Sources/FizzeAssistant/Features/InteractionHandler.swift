import Foundation
import Logging

struct InteractionCallbackPayload: Codable, Sendable {
    var type: Int
    var data: DiscordMessageCreate?
}

actor InteractionHandler {
    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let warningStore: WarningStore
    let logger: Logger

    init(restClient: DiscordRESTClient, configuration: AppConfiguration, warningStore: WarningStore, logger: Logger) {
        self.restClient = restClient
        self.configuration = configuration
        self.warningStore = warningStore
        self.logger = logger
    }

    func handle(_ interaction: DiscordInteraction, guildName: String) async {
        guard interaction.type == 2, let data = interaction.data else {
            return
        }

        do {
            try ensureAuthorized(member: interaction.member)

            switch data.name {
            case "say":
                let channelID = try requireOption(named: "channel", from: data).stringValueRequired
                let message = try requireOption(named: "message", from: data).stringValueRequired
                try await restClient.createMessage(channelID: channelID, content: message)
                try await respond(interaction, content: configuration.saySuccessMessage, ephemeral: true)

            case "warn":
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
                    channelID: configuration.modLogChannelID,
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
                let warningID = try requireOption(named: "warning_id", from: data).stringValueRequired
                let deleted = try await warningStore.deleteWarning(id: warningID)
                try await respond(interaction, content: deleted ? "Deleted warning `\(warningID)`." : "No warning found with ID `\(warningID)`.", ephemeral: true)

            case "clear-warnings":
                let userID = try requireOption(named: "user", from: data).stringValueRequired
                let deleted = try await warningStore.deleteWarnings(for: userID, guildID: configuration.guildID)
                try await respond(interaction, content: "Deleted \(deleted) warnings for <@\(userID)>.", ephemeral: true)

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

    private func ensureAuthorized(member: DiscordInteractionMember?) throws {
        let roles = Set(member?.roles ?? [])
        guard !roles.isDisjoint(with: configuration.allowedStaffRoleIDs) else {
            throw UserFacingError("You are not allowed to use this command.")
        }
    }

    private func requireOption(named name: String, from data: DiscordInteractionData) throws -> JSONValue {
        guard let value = data.options?.first(where: { $0.name == name })?.value else {
            throw UserFacingError("Missing command option \(name).")
        }
        return value
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

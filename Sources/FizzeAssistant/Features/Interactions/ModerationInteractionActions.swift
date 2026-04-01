import Foundation

extension DiscordInteractionRouter {
    // MARK: Moderation Commands

    private static let arrestRoleID = "819657472209977404"
    private struct DeferredModerationOutcome {
        let moderatorMessage: String
        let visibleChannelMessage: String?
    }

    func handleModerationCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration, guildName: String) async throws {
        switch data.name ?? "" {
        case "arrest":
            try await handleArrestCommand(interaction, data: data, configuration: configuration)
        case "bailout":
            try await handleBailoutCommand(interaction, data: data, configuration: configuration)
        case "warn":
            try await handleWarnCommand(interaction, data: data, configuration: configuration, guildName: guildName)
        case "warns":
            try await handleWarnsCommand(interaction, data: data, configuration: configuration)
        case "clear-warning":
            try await handleClearWarningCommand(interaction, data: data)
        case "clear-warnings":
            try await handleClearWarningsCommand(interaction, data: data, configuration: configuration)
        default:
            throw UserFacingError("DiscordInteractionRouter.handleModerationCommand: received unsupported moderation command `\(data.name ?? "<missing-name>")`. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
    }

    // MARK: Private Helpers

    private func handleArrestCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let userID = try requireOption(named: "user", from: data, commandName: "arrest").stringValueRequired(commandName: "arrest", optionName: "user")
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        try await handleDeferredModerationAction(interaction, commandName: "arrest") {
            try await restClient.addRole(
                to: userID,
                guild_id: configuration.guild_id,
                role_id: Self.arrestRoleID
            )
            return DeferredModerationOutcome(
                moderatorMessage: "Applied the arrest role to <@\(userID)>.",
                visibleChannelMessage: "<@\(moderatorID)> applied the arrest role to <@\(userID)>."
            )
        }
    }

    private func handleBailoutCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let userID = try requireOption(named: "user", from: data, commandName: "bailout").stringValueRequired(commandName: "bailout", optionName: "user")
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        try await handleDeferredModerationAction(interaction, commandName: "bailout") {
            try await restClient.removeRole(
                from: userID,
                guild_id: configuration.guild_id,
                role_id: Self.arrestRoleID
            )
            return DeferredModerationOutcome(
                moderatorMessage: "Removed the arrest role from <@\(userID)>.",
                visibleChannelMessage: "<@\(moderatorID)> removed the arrest role from <@\(userID)>."
            )
        }
    }

    private func handleWarnCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration, guildName: String) async throws {
        guard let mod_log_channel_id = configuration.mod_log_channel_id else {
            throw UserFacingError("DiscordInteractionRouter.handleWarnCommand: `/warn` needs `mod_log_channel_id` in the active JSON config file before it can record warnings. The most likely cause is that the mod log channel has not been configured yet.")
        }

        let user_id = try requireOption(named: "user", from: data, commandName: "warn").stringValueRequired(commandName: "warn", optionName: "user")
        let reason = try requireOption(named: "reason", from: data, commandName: "warn").stringValueRequired(commandName: "warn", optionName: "reason")
        let moderator_id = interaction.member?.user?.id ?? "unknown"
        try await handleDeferredModerationAction(interaction, commandName: "warn") {
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

            return DeferredModerationOutcome(
                moderatorMessage: "Warning recorded as `\(warning.id)`.",
                visibleChannelMessage: "<@\(moderator_id)> warned <@\(user_id)>."
            )
        }
    }

    private func handleWarnsCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let user_id = try requireOption(named: "user", from: data, commandName: "warns").stringValueRequired(commandName: "warns", optionName: "user")
        let warnings = try await warningStore.warnings(for: user_id, guild_id: configuration.guild_id)
        let content = formatWarningHistory(warnings, for: user_id)
        try await respond(to: interaction, content: content, ephemeral: true)
    }

    private func handleClearWarningCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData) async throws {
        let warningID = try requireOption(named: "warning_id", from: data, commandName: "clear-warning").stringValueRequired(commandName: "clear-warning", optionName: "warning_id")
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        try await handleDeferredModerationAction(interaction, commandName: "clear-warning") {
            let deleted = try await warningStore.deleteWarning(id: warningID)
            return DeferredModerationOutcome(
                moderatorMessage: deleted ? "Deleted warning `\(warningID)`." : "No warning found with ID `\(warningID)`.",
                visibleChannelMessage: deleted ? "<@\(moderatorID)> cleared warning `\(warningID)`." : nil
            )
        }
    }

    private func handleClearWarningsCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let user_id = try requireOption(named: "user", from: data, commandName: "clear-warnings").stringValueRequired(commandName: "clear-warnings", optionName: "user")
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        try await handleDeferredModerationAction(interaction, commandName: "clear-warnings") {
            let deleted = try await warningStore.deleteWarnings(for: user_id, guild_id: configuration.guild_id)
            return DeferredModerationOutcome(
                moderatorMessage: "Deleted \(deleted) warnings for <@\(user_id)>.",
                visibleChannelMessage: deleted > 0 ? "<@\(moderatorID)> cleared \(deleted) warnings for <@\(user_id)>." : nil
            )
        }
    }

    private func postVisibleModerationFollowup(for interaction: DiscordInteraction, content: String) async throws {
        guard let channelID = interaction.channel_id else { return }
        try await restClient.createMessage(channel_id: channelID, content: content)
    }

    private func handleDeferredModerationAction(
        _ interaction: DiscordInteraction,
        commandName: String,
        work: () async throws -> DeferredModerationOutcome
    ) async throws {
        try await deferResponse(to: interaction, ephemeral: true)

        let outcome: DeferredModerationOutcome
        do {
            outcome = try await work()
        } catch {
            logger.warning("DiscordInteractionRouter.handleDeferredModerationAction: the moderation action failed after the interaction was deferred, so the bot is editing the private response with the error details.", metadata: [
                "command": .string(commandName),
                "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
            ])
            try? await completeDeferredModerationResponse(
                for: interaction,
                content: (error as? LocalizedError)?.errorDescription ?? String(describing: error)
            )
            return
        }

        do {
            try await completeDeferredModerationResponse(for: interaction, content: outcome.moderatorMessage)
        } catch {
            logger.warning("DiscordInteractionRouter.handleDeferredModerationAction: the moderation action succeeded, but the bot could not deliver the deferred moderator reply cleanly.", metadata: [
                "command": .string(commandName),
                "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
            ])
            return
        }

        guard let visibleChannelMessage = outcome.visibleChannelMessage else { return }
        do {
            try await postVisibleModerationFollowup(for: interaction, content: visibleChannelMessage)
        } catch {
            logger.warning("DiscordInteractionRouter.handleDeferredModerationAction: the moderation action succeeded, but the visible in-channel followup could not be posted.", metadata: [
                "command": .string(commandName),
                "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
            ])
        }
    }

    private func completeDeferredModerationResponse(for interaction: DiscordInteraction, content: String) async throws {
        let editPayload = DiscordMessageCreate(content: content, embeds: nil, components: nil, flags: nil)
        do {
            try await editOriginalResponse(to: interaction, payload: editPayload)
        } catch {
            logger.warning("DiscordInteractionRouter.completeDeferredModerationResponse: editing the deferred interaction response failed, so the bot is falling back to an ephemeral followup message.", metadata: [
                "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
            ])
            let followupPayload = DiscordMessageCreate(content: content, embeds: nil, components: nil, flags: 64)
            try await createInteractionFollowup(to: interaction, payload: followupPayload)
        }
    }

    private func formatWarningHistory(_ warnings: [WarningRecord], for userID: String) -> String {
        if warnings.isEmpty {
            return "No warnings recorded for <@\(userID)>."
        }

        let formatter = ISO8601DateFormatter()
        return warnings.map { warning in
            let timestamp = formatter.string(from: warning.created_at)
            return "`\(warning.id)` • \(timestamp) • <@\(warning.moderator_user_id)> • \(warning.reason)"
        }.joined(separator: "\n")
    }
}

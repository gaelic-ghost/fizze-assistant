import Foundation

extension DiscordInteractionRouter {
    // MARK: Moderation Commands

    private static let arrestRoleID = "819657472209977404"

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
        try await restClient.addRole(
            to: userID,
            guild_id: configuration.guild_id,
            role_id: Self.arrestRoleID
        )
        try await postVisibleModerationFollowup(
            for: interaction,
            content: "<@\(moderatorID)> applied the arrest role to <@\(userID)>."
        )
        try await respond(to: interaction, content: "Applied the arrest role to <@\(userID)>.", ephemeral: true)
    }

    private func handleBailoutCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let userID = try requireOption(named: "user", from: data, commandName: "bailout").stringValueRequired(commandName: "bailout", optionName: "user")
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        try await restClient.removeRole(
            from: userID,
            guild_id: configuration.guild_id,
            role_id: Self.arrestRoleID
        )
        try await postVisibleModerationFollowup(
            for: interaction,
            content: "<@\(moderatorID)> removed the arrest role from <@\(userID)>."
        )
        try await respond(to: interaction, content: "Removed the arrest role from <@\(userID)>.", ephemeral: true)
    }

    private func handleWarnCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration, guildName: String) async throws {
        guard let mod_log_channel_id = configuration.mod_log_channel_id else {
            throw UserFacingError("DiscordInteractionRouter.handleWarnCommand: `/warn` needs `mod_log_channel_id` in `fizze-assistant.json` before it can record warnings. The most likely cause is that the mod log channel has not been configured yet.")
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

        try await postVisibleModerationFollowup(
            for: interaction,
            content: "<@\(moderator_id)> warned <@\(user_id)>."
        )
        try await respond(to: interaction, content: "Warning recorded as `\(warning.id)`.", ephemeral: true)
    }

    private func handleWarnsCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let user_id = try requireOption(named: "user", from: data, commandName: "warns").stringValueRequired(commandName: "warns", optionName: "user")
        let warnings = try await warningStore.warnings(for: user_id, guild_id: configuration.guild_id)
        let content = formatWarningHistory(warnings, for: user_id)
        try await respond(to: interaction, content: content, ephemeral: true)
    }

    private func handleClearWarningCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData) async throws {
        let warningID = try requireOption(named: "warning_id", from: data, commandName: "clear-warning").stringValueRequired(commandName: "clear-warning", optionName: "warning_id")
        let deleted = try await warningStore.deleteWarning(id: warningID)
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        if deleted {
            try await postVisibleModerationFollowup(
                for: interaction,
                content: "<@\(moderatorID)> cleared warning `\(warningID)`."
            )
        }
        try await respond(to: interaction, content: deleted ? "Deleted warning `\(warningID)`." : "No warning found with ID `\(warningID)`.", ephemeral: true)
    }

    private func handleClearWarningsCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let user_id = try requireOption(named: "user", from: data, commandName: "clear-warnings").stringValueRequired(commandName: "clear-warnings", optionName: "user")
        let deleted = try await warningStore.deleteWarnings(for: user_id, guild_id: configuration.guild_id)
        let moderatorID = interaction.member?.user?.id ?? "unknown"
        if deleted > 0 {
            try await postVisibleModerationFollowup(
                for: interaction,
                content: "<@\(moderatorID)> cleared \(deleted) warnings for <@\(user_id)>."
            )
        }
        try await respond(to: interaction, content: "Deleted \(deleted) warnings for <@\(user_id)>.", ephemeral: true)
    }

    private func postVisibleModerationFollowup(for interaction: DiscordInteraction, content: String) async throws {
        guard let channelID = interaction.channel_id else { return }
        try await restClient.createMessage(channel_id: channelID, content: content)
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

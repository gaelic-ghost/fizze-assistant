import Foundation
import Logging

actor DiscordInteractionRouter {
    // MARK: Stored Properties

    let restClient: DiscordRESTClient
    let configurationStore: ConfigurationStore
    let warningStore: WarningStore
    let logger: Logger

    // MARK: Lifecycle

    init(restClient: DiscordRESTClient, configurationStore: ConfigurationStore, warningStore: WarningStore, logger: Logger) {
        self.restClient = restClient
        self.configurationStore = configurationStore
        self.warningStore = warningStore
        self.logger = logger
    }

    // MARK: Public API

    func handle(_ interaction: DiscordInteraction, guildName: String) async {
        guard let data = interaction.data else {
            return
        }

        do {
            let configuration = await configurationStore.currentConfiguration()

            switch interaction.type {
            case DiscordInteractionType.applicationCommand:
                try await handleApplicationCommand(interaction, data: data, configuration: configuration, guildName: guildName)

            case DiscordInteractionType.messageComponent:
                try await handleMessageComponent(interaction, data: data, configuration: configuration)

            case DiscordInteractionType.modalSubmit:
                try await handleModalSubmit(interaction, data: data, configuration: configuration)

            default:
                return
            }
        } catch {
            logger.warning("DiscordInteractionRouter.handle: an interaction hit an error path, and the bot is trying to return a human-readable reply instead of failing silently.", metadata: ["error": .string(String(describing: error))])
            try? await respond(
                to: interaction,
                content: (error as? LocalizedError)?.errorDescription ?? "DiscordInteractionRouter.handle: the interaction did not finish cleanly, so the bot sent this fallback reply instead. The most likely cause is a missing Discord permission, an expired wizard step, or a configuration mismatch in the active JSON config file.",
                ephemeral: true
            )
        }
    }

    // MARK: Private Helpers

    private func handleApplicationCommand(
        _ interaction: DiscordInteraction,
        data: DiscordInteractionData,
        configuration: AppConfiguration,
        guildName: String
    ) async throws {
        switch data.name ?? "" {
        case "say":
            try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
            try await handleSayCommand(interaction, data: data, configuration: configuration)

        case "arrest", "bailout", "warn", "warns", "clear-warning", "clear-warnings":
            try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
            try await handleModerationCommand(interaction, data: data, configuration: configuration, guildName: guildName)

        case "config":
            try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
            try await handleConfigCommand(interaction, data: data)

        case "this-is-iconic":
            try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
            try await startThisIsIconicWizard(interaction)

        case "this-isn't-iconic":
            try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
            try await startThisIsntIconicWizard(interaction)

        default:
            try await respond(to: interaction, content: "That command isn't implemented yet.", ephemeral: true)
        }
    }
}

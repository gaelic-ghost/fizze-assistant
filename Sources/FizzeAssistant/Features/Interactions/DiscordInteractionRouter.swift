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
        guard interaction.type == 2, let data = interaction.data else {
            return
        }

        do {
            let configuration = await configurationStore.currentConfiguration()

            switch data.name {
            case "say":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                try await handleSayCommand(interaction, data: data, configuration: configuration)

            case "warn", "warns", "clear-warning", "clear-warnings":
                try ensureStaffAuthorized(member: interaction.member, configuration: configuration)
                try await handleModerationCommand(interaction, data: data, configuration: configuration, guildName: guildName)

            case "config":
                try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
                try await handleConfigCommand(interaction, data: data)

            default:
                try await respond(to: interaction, content: "That command isn't implemented yet.", ephemeral: true)
            }
        } catch {
            logger.warning("DiscordInteractionRouter.handle: a slash command hit an error path, and the bot is trying to return a human-readable reply instead of failing silently.", metadata: ["error": .string(String(describing: error))])
            try? await respond(
                to: interaction,
                content: (error as? LocalizedError)?.errorDescription ?? "DiscordInteractionRouter.handle: the command did not finish cleanly, so the bot sent this fallback reply instead. The most likely cause is a missing Discord permission or a configuration mismatch in `fizze-assistant.json`.",
                ephemeral: true
            )
        }
    }
}

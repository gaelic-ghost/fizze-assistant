import Foundation
import Logging

struct CommandRegistrar {
    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let logger: Logger

    func registerGuildCommands() async throws {
        let commands = [
            DiscordSlashCommand(
                name: "say",
                description: "Speak through the bot in another channel.",
                options: [
                    DiscordApplicationCommandOption(type: 7, name: "channel", description: "Where the bot should speak.", required: true, channelTypes: [0]),
                    DiscordApplicationCommandOption(type: 3, name: "message", description: "Message text to send.", required: true, channelTypes: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "warn",
                description: "Record a moderator warning for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to warn.", required: true, channelTypes: nil),
                    DiscordApplicationCommandOption(type: 3, name: "reason", description: "Reason for the warning.", required: true, channelTypes: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "warns",
                description: "Show warning history for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to inspect.", required: true, channelTypes: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "clear-warning",
                description: "Delete a warning by its warning ID.",
                options: [
                    DiscordApplicationCommandOption(type: 3, name: "warning_id", description: "Warning ID to delete.", required: true, channelTypes: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "clear-warnings",
                description: "Delete all warnings for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User whose warnings should be removed.", required: true, channelTypes: nil),
                ]
            ),
        ]

        try await restClient.upsertGuildCommands(
            applicationID: configuration.applicationID,
            guildID: configuration.guildID,
            commands: commands
        )
        logger.info("Guild commands upserted.", metadata: ["count": .string(String(commands.count))])
    }
}

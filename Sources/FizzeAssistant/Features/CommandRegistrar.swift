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
            DiscordSlashCommand(
                name: "config",
                description: "View or adjust the bot's non-secret configuration.",
                options: [
                    DiscordApplicationCommandOption(type: 1, name: "show", description: "Show the current non-secret configuration.", required: nil, channelTypes: nil, options: nil),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "set",
                        description: "Set one non-secret configuration value.",
                        required: nil,
                        channelTypes: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "setting", description: "Editable setting key.", required: true, channelTypes: nil, options: nil),
                            DiscordApplicationCommandOption(type: 3, name: "value", description: "New value.", required: true, channelTypes: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "trigger-add",
                        description: "Add or replace an exact-match trigger.",
                        required: nil,
                        channelTypes: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "trigger", description: "Exact phrase to match.", required: true, channelTypes: nil, options: nil),
                            DiscordApplicationCommandOption(type: 3, name: "response", description: "Message to send.", required: true, channelTypes: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "trigger-remove",
                        description: "Remove an exact-match trigger.",
                        required: nil,
                        channelTypes: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "trigger", description: "Trigger phrase to remove.", required: true, channelTypes: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(type: 1, name: "trigger-list", description: "List exact-match triggers.", required: nil, channelTypes: nil, options: nil),
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

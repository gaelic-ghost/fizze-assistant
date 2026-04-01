import Foundation
import Logging

struct DiscordCommandRegistrar {
    // MARK: Stored Properties

    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let logger: Logger

    // MARK: Public API

    var guildCommands: [DiscordSlashCommand] {
        [
            DiscordSlashCommand(
                name: "say",
                description: "Speak through the bot in another channel.",
                options: [
                    DiscordApplicationCommandOption(type: 7, name: "channel", description: "Where the bot should speak.", required: true, channel_types: [0]),
                    DiscordApplicationCommandOption(type: 3, name: "message", description: "Message text to send.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "warn",
                description: "Record a moderator warning for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to warn.", required: true, channel_types: nil),
                    DiscordApplicationCommandOption(type: 3, name: "reason", description: "Reason for the warning.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "arrest",
                description: "Apply the arrest role to a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to arrest.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "warns",
                description: "Show warning history for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to inspect.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "clear-warning",
                description: "Delete a warning by its warning ID.",
                options: [
                    DiscordApplicationCommandOption(type: 3, name: "warning_id", description: "Warning ID to delete.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "clear-warnings",
                description: "Delete all warnings for a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User whose warnings should be removed.", required: true, channel_types: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "config",
                description: "View or adjust the bot's non-secret configuration.",
                options: [
                    DiscordApplicationCommandOption(type: 1, name: "show", description: "Show the current non-secret configuration.", required: nil, channel_types: nil, options: nil),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "set",
                        description: "Set one non-secret configuration value.",
                        required: nil,
                        channel_types: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "setting", description: "Editable setting key.", required: true, channel_types: nil, options: nil),
                            DiscordApplicationCommandOption(type: 3, name: "value", description: "New value.", required: true, channel_types: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "trigger-add",
                        description: "Add or replace one iconic trigger response.",
                        required: nil,
                        channel_types: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "trigger", description: "Trigger phrase to match.", required: true, channel_types: nil, options: nil),
                            DiscordApplicationCommandOption(type: 3, name: "response", description: "Message to send.", required: true, channel_types: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(
                        type: 1,
                        name: "trigger-remove",
                        description: "Remove one iconic trigger.",
                        required: nil,
                        channel_types: nil,
                        options: [
                            DiscordApplicationCommandOption(type: 3, name: "trigger", description: "Trigger phrase to remove.", required: true, channel_types: nil, options: nil),
                        ]
                    ),
                    DiscordApplicationCommandOption(type: 1, name: "trigger-list", description: "List iconic triggers and payload types.", required: nil, channel_types: nil, options: nil),
                ]
            ),
            DiscordSlashCommand(
                name: "this-is-iconic",
                description: "Walk through a new iconic response in two quick steps.",
                options: nil
            ),
        ]
    }

    func registerGuildCommands() async throws {
        let commands = guildCommands

        try await restClient.upsertGuildCommands(
            application_id: configuration.application_id,
            guild_id: configuration.guild_id,
            commands: commands
        )
        logger.info("Guild commands upserted.", metadata: ["count": .string(String(commands.count))])
    }
}

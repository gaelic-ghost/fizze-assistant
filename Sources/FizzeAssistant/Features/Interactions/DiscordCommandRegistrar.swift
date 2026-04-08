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
                name: "bailout",
                description: "Remove the arrest role from a user.",
                options: [
                    DiscordApplicationCommandOption(type: 6, name: "user", description: "User to release.", required: true, channel_types: nil),
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
            DiscordSlashCommand(
                name: "this-isnt-iconic",
                description: "Walk through updating one existing iconic response.",
                options: nil
            ),
        ]
    }

    var registrationValidationIssues: [String] {
        DiscordRegistrationValidator.issues(
            commands: guildCommands,
            wizardCustomIDs: wizardCustomIDs(sessionID: String(repeating: "a", count: 36))
        )
    }

    func registerGuildCommands() async throws {
        let commands = guildCommands
        let validationIssues = DiscordRegistrationValidator.issues(
            commands: commands,
            wizardCustomIDs: wizardCustomIDs(sessionID: String(repeating: "a", count: 36))
        )

        guard validationIssues.isEmpty else {
            throw UserFacingError(
                """
                DiscordCommandRegistrar.registerGuildCommands: local command validation found \(validationIssues.count) Discord registration issue(s), so the bot will not send an invalid slash-command payload upstream. \(validationIssues.joined(separator: " "))
                """
            )
        }

        try await restClient.upsertGuildCommands(
            application_id: configuration.application_id,
            guild_id: configuration.guild_id,
            commands: commands
        )
        logger.info("Guild commands upserted.", metadata: ["count": .string(String(commands.count))])
    }

    // MARK: Private Helpers

    private func wizardCustomIDs(sessionID: String) -> [String] {
        [
            ThisIsIconicWizard.triggerModalID,
            ThisIsIconicWizard.triggerFieldID,
            ThisIsIconicWizard.continueButtonPrefix + sessionID,
            ThisIsIconicWizard.contentModalPrefix + sessionID,
            ThisIsIconicWizard.contentFieldID,
            ThisIsntIconicWizard.triggerModalID,
            ThisIsntIconicWizard.triggerFieldID,
            ThisIsntIconicWizard.continueButtonPrefix + sessionID,
            ThisIsntIconicWizard.contentModalPrefix + sessionID,
        ]
    }
}

enum DiscordRegistrationValidator {
    // MARK: Constants

    static let maxCommandNameLength = 32
    static let maxCommandDescriptionLength = 100
    static let maxCommandOptionCount = 25
    static let maxComponentCustomIDLength = 100
    static let commandNamePattern = try! NSRegularExpression(
        pattern: #"^[-_'\p{L}\p{N}\p{sc=Deva}\p{sc=Thai}]{1,32}$"#
    )

    // MARK: Validation

    static func issues(commands: [DiscordSlashCommand], wizardCustomIDs: [String]) -> [String] {
        var issues: [String] = []

        for command in commands {
            validate(command: command, path: "/\(command.name)", issues: &issues)
        }

        for customID in wizardCustomIDs where customID.count > maxComponentCustomIDLength {
            issues.append(
                "Wizard component `custom_id` `\(customID)` is \(customID.count) characters long, but Discord only allows up to \(maxComponentCustomIDLength)."
            )
        }

        return issues
    }

    // MARK: Private Helpers

    private static func validate(
        command: DiscordSlashCommand,
        path: String,
        issues: inout [String]
    ) {
        validateCommandName(command.name, path: path, issues: &issues)
        validateDescription(command.description, path: path, issues: &issues)

        if let options = command.options {
            validateOptionCount(options.count, path: path, issues: &issues)
            validateRequiredOptionsPrecedeOptional(options, path: path, issues: &issues)

            for option in options {
                validate(option: option, path: "\(path) \(option.name)", issues: &issues)
            }
        }
    }

    private static func validate(
        option: DiscordApplicationCommandOption,
        path: String,
        issues: inout [String]
    ) {
        validateCommandName(option.name, path: path, issues: &issues)
        validateDescription(option.description, path: path, issues: &issues)

        if let nestedOptions = option.options {
            validateOptionCount(nestedOptions.count, path: path, issues: &issues)
            validateRequiredOptionsPrecedeOptional(nestedOptions, path: path, issues: &issues)

            for nestedOption in nestedOptions {
                validate(option: nestedOption, path: "\(path) \(nestedOption.name)", issues: &issues)
            }
        }
    }

    private static func validateCommandName(
        _ name: String,
        path: String,
        issues: inout [String]
    ) {
        let fullRange = NSRange(location: 0, length: name.utf16.count)
        let matchesPattern = commandNamePattern.firstMatch(in: name, options: [], range: fullRange)?.range == fullRange

        guard matchesPattern, name == name.lowercased(), !name.isEmpty, name.count <= maxCommandNameLength else {
            issues.append(
                "`\(path)` uses the command or option name `\(name)`, but Discord slash-command names must stay lowercase, match Discord's allowed token characters, and fit within \(maxCommandNameLength) characters."
            )
            return
        }
    }

    private static func validateDescription(
        _ description: String,
        path: String,
        issues: inout [String]
    ) {
        guard !description.isEmpty, description.count <= maxCommandDescriptionLength else {
            issues.append(
                "`\(path)` uses a description that is \(description.count) characters long, but Discord command and option descriptions must be between 1 and \(maxCommandDescriptionLength) characters."
            )
            return
        }
    }

    private static func validateOptionCount(
        _ count: Int,
        path: String,
        issues: inout [String]
    ) {
        guard count <= maxCommandOptionCount else {
            issues.append(
                "`\(path)` defines \(count) options, but Discord currently allows at most \(maxCommandOptionCount) options at one level."
            )
            return
        }
    }

    private static func validateRequiredOptionsPrecedeOptional(
        _ options: [DiscordApplicationCommandOption],
        path: String,
        issues: inout [String]
    ) {
        var sawOptional = false

        for option in options {
            let isRequired = option.required ?? false
            if sawOptional, isRequired {
                issues.append(
                    "`\(path)` places the required option `\(option.name)` after an optional option, but Discord requires required options to appear first."
                )
                return
            }

            if !isRequired {
                sawOptional = true
            }
        }
    }
}

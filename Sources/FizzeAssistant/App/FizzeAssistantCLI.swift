import ArgumentParser
import Foundation
import Logging

@main
struct FizzeAssistantCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "fizze-assistant",
        abstract: "Discord bot CLI for the Fizze Assistant server bot.",
        subcommands: [
            RunCommand.self,
            RegisterCommandsCommand.self,
            CheckCommand.self,
            ConfigCommand.self,
        ],
        defaultSubcommand: RunCommand.self
    )
}

struct SharedOptions: ParsableArguments {
    @Option(name: .shortAndLong, help: "Optional path to a JSON configuration file.")
    var config: String?

    @Flag(help: "Enable extra debug logging.")
    var verbose = false
}

struct RunCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the bot."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .run, options: options)
    }
}

struct RegisterCommandsCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "register-commands",
        abstract: "Register guild slash commands."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .registerCommands, options: options)
    }
}

struct CheckCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Validate configuration and Discord permissions."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .check, options: options)
    }
}

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage the committed non-secret JSON configuration file.",
        subcommands: [
            ConfigShowCommand.self,
            ConfigInitCommand.self,
            ConfigValidateCommand.self,
        ]
    )
}

struct ConfigShowCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the current non-secret configuration."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .configShow, options: options)
    }
}

struct ConfigInitCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create the JSON configuration file if it does not exist."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .configInit, options: options)
    }
}

struct ConfigValidateCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the non-secret configuration setup."
    )

    @OptionGroup
    var options: SharedOptions

    mutating func run() async throws {
        try await BotApplication.run(command: .configValidate, options: options)
    }
}

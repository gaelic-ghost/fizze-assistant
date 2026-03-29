import ArgumentParser
import Foundation
import Logging

@main
struct FizzeAssistantCLI: AsyncParsableCommand {
    // MARK: Command Configuration

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
    // MARK: Parsed Options

    @Option(name: .shortAndLong, help: "Optional path to a JSON configuration file.")
    var config: String?

    @Flag(help: "Enable extra debug logging.")
    var verbose = false
}

struct RunCommand: AsyncParsableCommand {
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run the bot."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .run, options: options)
    }
}

struct RegisterCommandsCommand: AsyncParsableCommand {
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "register-commands",
        abstract: "Register guild slash commands."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .registerCommands, options: options)
    }
}

struct CheckCommand: AsyncParsableCommand {
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "check",
        abstract: "Validate configuration and Discord permissions."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .check, options: options)
    }
}

struct ConfigCommand: AsyncParsableCommand {
    // MARK: Command Configuration

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
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Print the current non-secret configuration."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .configShow, options: options)
    }
}

struct ConfigInitCommand: AsyncParsableCommand {
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "init",
        abstract: "Create the JSON configuration file if it does not exist."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .configInit, options: options)
    }
}

struct ConfigValidateCommand: AsyncParsableCommand {
    // MARK: Command Configuration

    static let configuration = CommandConfiguration(
        commandName: "validate",
        abstract: "Validate the non-secret configuration setup."
    )

    // MARK: Parsed Options

    @OptionGroup
    var options: SharedOptions

    // MARK: AsyncParsableCommand

    mutating func run() async throws {
        try await BotApplication.run(command: .configValidate, options: options)
    }
}

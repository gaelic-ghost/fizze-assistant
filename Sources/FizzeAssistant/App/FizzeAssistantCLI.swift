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

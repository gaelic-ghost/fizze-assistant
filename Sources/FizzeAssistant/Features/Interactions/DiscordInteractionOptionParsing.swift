import Foundation

extension DiscordInteractionRouter {
    // MARK: Option Parsing

    func requireOption(named name: String, from data: DiscordInteractionData, commandName: String) throws -> JSONValue {
        guard let value = data.options?.first(where: { $0.name == name })?.value else {
            throw UserFacingError("DiscordInteractionRouter.requireOption: Discord sent `/\(commandName)` without the `\(name)` option, so the command cannot continue. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
        return value
    }

    func requireNestedOption(named name: String, from options: [DiscordInteractionOption], commandName: String, subcommandName: String) throws -> JSONValue {
        guard let value = options.first(where: { $0.name == name })?.value else {
            throw UserFacingError("DiscordInteractionRouter.requireNestedOption: Discord sent `/\(commandName) \(subcommandName)` without the `\(name)` option, so the command cannot continue. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
        return value
    }
}

extension JSONValue {
    // MARK: Interaction Decoding

    func stringValueRequired(commandName: String, optionName: String) throws -> String {
        if let stringValue {
            return stringValue
        }
        throw UserFacingError("DiscordInteractionRouter.JSONValue.stringValueRequired: `/\(commandName)` received a non-text value for `\(optionName)`, but this option must be plain text. The most likely cause is that the slash command definition in Discord is out of date; rerun command registration.")
    }
}

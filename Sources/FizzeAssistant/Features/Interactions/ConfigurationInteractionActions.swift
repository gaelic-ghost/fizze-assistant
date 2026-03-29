import Foundation

extension DiscordInteractionRouter {
    // MARK: Configuration Commands

    func handleConfigCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData) async throws {
        guard let subcommand = data.options?.first else {
            throw UserFacingError("DiscordInteractionRouter.handleConfigCommand: Discord sent `/config` without a subcommand, so the bot does not know which config action to run. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }

        let options = subcommand.options ?? []
        switch subcommand.name {
        case "show":
            let configurationFile = await configurationStore.configurationFileContents()
            let json = try configurationFile.prettyPrintedJSON()
            try await respond(to: interaction, content: "```json\n\(json)\n```", ephemeral: true)

        case "set":
            let key = try requireNestedOption(named: "setting", from: options, commandName: "config", subcommandName: "set").stringValueRequired(commandName: "config set", optionName: "setting")
            guard let setting = RuntimeConfigSetting(rawValue: key) else {
                throw UserFacingError("DiscordInteractionRouter.handleConfigCommand: `/config set` received the unknown setting `\(key)`. Allowed settings are: \(RuntimeConfigSetting.allowedKeysText). The most likely cause is a typo in the command option.")
            }
            let value = try requireNestedOption(named: "value", from: options, commandName: "config", subcommandName: "set").stringValueRequired(commandName: "config set", optionName: "value")
            _ = try await configurationStore.update(setting: setting, value: value)
            try await respond(to: interaction, content: "Updated `\(setting.rawValue)`.", ephemeral: true)

        case "trigger-add":
            let trigger = try requireNestedOption(named: "trigger", from: options, commandName: "config", subcommandName: "trigger-add").stringValueRequired(commandName: "config trigger-add", optionName: "trigger")
            let responseText = try requireNestedOption(named: "response", from: options, commandName: "config", subcommandName: "trigger-add").stringValueRequired(commandName: "config trigger-add", optionName: "response")
            _ = try await configurationStore.addTrigger(trigger: trigger, response: responseText)
            try await respond(to: interaction, content: "Saved trigger `\(trigger)`.", ephemeral: true)

        case "trigger-remove":
            let trigger = try requireNestedOption(named: "trigger", from: options, commandName: "config", subcommandName: "trigger-remove").stringValueRequired(commandName: "config trigger-remove", optionName: "trigger")
            let removed = try await configurationStore.removeTrigger(trigger: trigger)
            try await respond(to: interaction, content: removed ? "Removed trigger `\(trigger)`." : "No trigger matched `\(trigger)`.", ephemeral: true)

        case "trigger-list":
            let runtime = await configurationStore.configurationFileContents()
            let content: String
            if runtime.iconic_triggers.isEmpty {
                content = "No exact-match triggers are configured."
            } else {
                content = runtime.iconic_triggers.map { "`\($0.trigger)` -> \($0.response)" }.joined(separator: "\n")
            }
            try await respond(to: interaction, content: content, ephemeral: true)

        default:
            throw UserFacingError("DiscordInteractionRouter.handleConfigCommand: `/config` received the unknown subcommand `\(subcommand.name)`, so the bot could not match it to a config action. The most likely cause is that the slash commands in the server are out of date; rerun command registration.")
        }
    }
}

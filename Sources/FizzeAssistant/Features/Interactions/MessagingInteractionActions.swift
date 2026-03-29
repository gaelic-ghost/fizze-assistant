import Foundation

extension DiscordInteractionRouter {
    // MARK: Messaging Commands

    func handleSayCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let channel_id = try requireOption(named: "channel", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "channel")
        let message = try requireOption(named: "message", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "message")
        try await restClient.createMessage(channel_id: channel_id, content: message)
        try await respond(to: interaction, content: configuration.say_success_message, ephemeral: true)
    }
}

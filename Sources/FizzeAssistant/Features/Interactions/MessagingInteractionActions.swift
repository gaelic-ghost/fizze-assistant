import Foundation

extension DiscordInteractionRouter {
    // MARK: Messaging Commands

    func handleSayCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let channel_id = try requireOption(named: "channel", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "channel")
        let message = try requireOption(named: "message", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "message")
        try await restClient.createManagedMessage(
            channel_id: channel_id,
            payload: DiscordMessageCreate(content: message, embeds: nil, components: nil, flags: nil),
            kind: .sayCommand,
            logicalTargetID: interaction.id
        )
        try await respond(to: interaction, content: configuration.say_success_message, ephemeral: true)
    }
}

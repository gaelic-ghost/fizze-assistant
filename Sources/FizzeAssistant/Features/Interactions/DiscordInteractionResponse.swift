import Foundation

struct DiscordInteractionCallbackData: Codable, Sendable {
    // MARK: Stored Properties

    var content: String?
    var embeds: [DiscordEmbed]?
    var components: [DiscordComponent]?
    var flags: Int?
    var custom_id: String?
    var title: String?
}

struct InteractionCallbackPayload: Codable, Sendable {
    // MARK: Stored Properties

    var type: Int
    var data: DiscordInteractionCallbackData?
}

extension DiscordInteractionRouter {
    // MARK: Response Helpers

    func respond(to interaction: DiscordInteraction, content: String, ephemeral: Bool) async throws {
        try await respond(
            to: interaction,
            payload: DiscordMessageCreate(content: content, embeds: nil, flags: ephemeral ? 64 : nil)
        )
    }

    func respond(to interaction: DiscordInteraction, payload messagePayload: DiscordMessageCreate) async throws {
        let payload = InteractionCallbackPayload(
            type: DiscordInteractionCallbackType.channelMessageWithSource,
            data: DiscordInteractionCallbackData(
                content: messagePayload.content,
                embeds: messagePayload.embeds,
                components: messagePayload.components,
                flags: messagePayload.flags,
                custom_id: nil,
                title: nil
            )
        )
        try await restClient.createInteractionResponse(
            interaction_id: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }

    func respondWithModal(
        to interaction: DiscordInteraction,
        customID: String,
        title: String,
        components: [DiscordComponent]
    ) async throws {
        let payload = InteractionCallbackPayload(
            type: DiscordInteractionCallbackType.modal,
            data: DiscordInteractionCallbackData(
                content: nil,
                embeds: nil,
                components: components,
                flags: nil,
                custom_id: customID,
                title: title
            )
        )
        try await restClient.createInteractionResponse(
            interaction_id: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }
}

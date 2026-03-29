import Foundation

struct InteractionCallbackPayload: Codable, Sendable {
    // MARK: Stored Properties

    var type: Int
    var data: DiscordMessageCreate?
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
            type: 4,
            data: messagePayload
        )
        try await restClient.createInteractionResponse(
            interaction_id: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }
}

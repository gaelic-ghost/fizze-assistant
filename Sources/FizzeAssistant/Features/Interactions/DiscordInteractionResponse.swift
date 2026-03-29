import Foundation

struct InteractionCallbackPayload: Codable, Sendable {
    // MARK: Stored Properties

    var type: Int
    var data: DiscordMessageCreate?
}

extension DiscordInteractionRouter {
    // MARK: Response Helpers

    func respond(to interaction: DiscordInteraction, content: String, ephemeral: Bool) async throws {
        let payload = InteractionCallbackPayload(
            type: 4,
            data: DiscordMessageCreate(content: content, flags: ephemeral ? 64 : nil)
        )
        try await restClient.createInteractionResponse(
            interaction_id: interaction.id,
            token: interaction.token,
            payload: payload
        )
    }
}

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

    func deferResponse(to interaction: DiscordInteraction, ephemeral: Bool) async throws {
        let payload = InteractionCallbackPayload(
            type: DiscordInteractionCallbackType.deferredChannelMessageWithSource,
            data: DiscordInteractionCallbackData(
                content: nil,
                embeds: nil,
                components: nil,
                flags: ephemeral ? 64 : nil,
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

    func editOriginalResponse(to interaction: DiscordInteraction, content: String) async throws {
        try await editOriginalResponse(
            to: interaction,
            payload: DiscordMessageCreate(content: content, embeds: nil, components: nil, flags: nil)
        )
    }

    func editOriginalResponse(to interaction: DiscordInteraction, payload: DiscordMessageCreate) async throws {
        try await restClient.editOriginalInteractionResponse(
            application_id: interaction.application_id,
            token: interaction.token,
            payload: payload
        )
    }

    func createInteractionFollowup(to interaction: DiscordInteraction, payload: DiscordMessageCreate) async throws {
        try await restClient.createInteractionFollowup(
            application_id: interaction.application_id,
            token: interaction.token,
            payload: payload
        )
    }

    func completeDeferredEphemeralResponse(
        to interaction: DiscordInteraction,
        content: String,
        failureContext: String
    ) async throws {
        let editPayload = DiscordMessageCreate(content: content, embeds: nil, components: nil, flags: nil)
        do {
            try await editOriginalResponse(to: interaction, payload: editPayload)
        } catch {
            logger.warning("\(failureContext): editing the deferred interaction response failed, so the bot is falling back to an ephemeral followup message.", metadata: [
                "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
            ])
            let followupPayload = DiscordMessageCreate(content: content, embeds: nil, components: nil, flags: 64)
            try await createInteractionFollowup(to: interaction, payload: followupPayload)
        }
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

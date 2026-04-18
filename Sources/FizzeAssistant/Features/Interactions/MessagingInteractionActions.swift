import Foundation

enum SongOfTheDayModal {
    static let modalID = "sotd:compose-modal"
    static let messageFieldID = "sotd:message"
    static let linksFieldID = "sotd:links"
}

extension DiscordInteractionRouter {
    // MARK: Messaging Commands

    func handleSayCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let channel_id = try requireOption(named: "channel", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "channel")
        let message = try requireOption(named: "message", from: data, commandName: "say").stringValueRequired(commandName: "say", optionName: "message")
        try await postMessage(
            interaction: interaction,
            channelID: channel_id,
            message: message,
            kind: .sayCommand,
            successMessage: configuration.say_success_message
        )
    }

    func handleSOTDCommand(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        try await respondWithModal(
            to: interaction,
            customID: SongOfTheDayModal.modalID,
            title: "Song of the Day",
            components: [
                modalParagraphInputRow(
                    customID: SongOfTheDayModal.messageFieldID,
                    label: "What message should go at the top?",
                    placeholder: "Add your intro, commentary, or Song of the Day note here.",
                    required: true,
                    maxLength: 2_000
                ),
                modalParagraphInputRow(
                    customID: SongOfTheDayModal.linksFieldID,
                    label: "Which links should go at the bottom?",
                    placeholder: "Paste one or more links here. They'll be added after a blank line.",
                    required: false,
                    maxLength: 2_000
                ),
            ]
        )
    }

    func handleSOTDModalSubmit(_ interaction: DiscordInteraction, data: DiscordInteractionData, configuration: AppConfiguration) async throws {
        let topMessage = try requireComponentValue(
            customID: SongOfTheDayModal.messageFieldID,
            from: data.components,
            interactionName: "Song of the Day modal"
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !topMessage.isEmpty else {
            throw UserFacingError("DiscordInteractionRouter.handleSOTDModalSubmit: the Song of the Day top message cannot be blank. The most likely cause is that the modal was submitted without any message text.")
        }

        let links = (try? requireComponentValue(
            customID: SongOfTheDayModal.linksFieldID,
            from: data.components,
            interactionName: "Song of the Day modal"
        ))?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        let finalMessage = if links.isEmpty {
            topMessage
        } else {
            "\(topMessage)\n\n\(links)"
        }

        try await postMessage(
            interaction: interaction,
            channelID: AppConfiguration.song_of_the_day_channel_id,
            message: finalMessage,
            kind: .songOfTheDayCommand,
            successMessage: configuration.sotd_success_message
        )
    }

    // MARK: Private Helpers

    private func postMessage(
        interaction: DiscordInteraction,
        channelID: DiscordSnowflake,
        message: String,
        kind: ManagedDiscordMessageKind,
        successMessage: String
    ) async throws {
        try await restClient.createManagedMessage(
            channel_id: channelID,
            payload: DiscordMessageCreate(content: message, embeds: nil, components: nil, flags: nil),
            kind: kind,
            logicalTargetID: interaction.id
        )
        try await respond(to: interaction, content: successMessage, ephemeral: true)
    }

    private func modalParagraphInputRow(
        customID: String,
        label: String,
        placeholder: String,
        required: Bool,
        maxLength: Int
    ) -> DiscordComponent {
        DiscordComponent(
            type: DiscordComponentType.actionRow,
            components: [
                DiscordComponent(
                    type: DiscordComponentType.textInput,
                    components: nil,
                    custom_id: customID,
                    style: DiscordTextInputStyle.paragraph,
                    label: label,
                    title: nil,
                    description: nil,
                    value: nil,
                    url: nil,
                    placeholder: placeholder,
                    required: required,
                    min_length: nil,
                    max_length: maxLength
                ),
            ],
            custom_id: nil,
            style: nil,
            label: nil,
            title: nil,
            description: nil,
            value: nil,
            url: nil,
            placeholder: nil,
            required: nil,
            min_length: nil,
            max_length: nil
        )
    }
}

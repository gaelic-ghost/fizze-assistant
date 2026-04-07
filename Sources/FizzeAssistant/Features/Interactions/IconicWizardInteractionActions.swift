import Foundation

enum ThisIsIconicWizard {
    // MARK: Constants

    static let triggerModalID = "this-is-iconic:trigger-modal"
    static let triggerFieldID = "this-is-iconic:trigger"
    static let continueButtonPrefix = "this-is-iconic:continue:"
    static let contentModalPrefix = "this-is-iconic:content-modal:"
    static let contentFieldID = "this-is-iconic:content"
    static let continuePrompt = "how can i be this iconic? what should i do? how should i look?"
    static let contentFieldLabel = "What should I say or do?"
    static let contentFieldPlaceholder = "Tell me what to say, and include an image URL if you want one."
    static let successMessage = "thank you so much! i'll start practicing this right away!"
}

enum ThisIsntIconicWizard {
    // MARK: Constants

    static let triggerModalID = "this-isnt-iconic:trigger-modal"
    static let triggerFieldID = "this-isnt-iconic:trigger"
    static let continueButtonPrefix = "this-isnt-iconic:continue:"
    static let contentModalPrefix = "this-isnt-iconic:content-modal:"
    static let successMessage = "okay, i've updated that iconic moment."
}

extension DiscordInteractionRouter {
    // MARK: Wizard Routing

    func handleMessageComponent(
        _ interaction: DiscordInteraction,
        data: DiscordInteractionData,
        configuration: AppConfiguration
    ) async throws {
        guard let customID = data.custom_id else {
            throw UserFacingError("DiscordInteractionRouter.handleMessageComponent: Discord sent a component interaction without a `custom_id`, so the bot cannot tell which button was clicked. The most likely cause is a malformed component payload.")
        }

        if customID.hasPrefix(ThisIsIconicWizard.continueButtonPrefix) {
            try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
            let sessionID = String(customID.dropFirst(ThisIsIconicWizard.continueButtonPrefix.count))
            let userID = try requireInteractionUserID(interaction, context: "this-is-iconic continue button")
            _ = try await warningStore.iconicWizardDraft(sessionID: sessionID, userID: userID)
            try await respondWithModal(
                to: interaction,
                customID: ThisIsIconicWizard.contentModalPrefix + sessionID,
                title: "This Is Iconic",
                components: [
                    paragraphInputRow(
                        customID: ThisIsIconicWizard.contentFieldID,
                        label: ThisIsIconicWizard.contentFieldLabel,
                        placeholder: ThisIsIconicWizard.contentFieldPlaceholder,
                        maxLength: 4_000
                    ),
                ]
            )
            return
        }

        if customID.hasPrefix(ThisIsntIconicWizard.continueButtonPrefix) {
            try ensureConfigAuthorized(member: interaction.member, configuration: configuration)
            let sessionID = String(customID.dropFirst(ThisIsntIconicWizard.continueButtonPrefix.count))
            let userID = try requireInteractionUserID(interaction, context: "this-isn't-iconic continue button")
            let draft = try await warningStore.iconicWizardDraft(sessionID: sessionID, userID: userID)
            guard let existingMessage = configuration.iconic_messages[draft.trigger] else {
                throw UserFacingError("DiscordInteractionRouter.handleMessageComponent: the iconic trigger `\(draft.trigger)` disappeared before `this-isn't-iconic` reached the edit step. The most likely cause is that someone removed the iconic response in another command; start `this-isn't-iconic` again.")
            }
            let editableContent = try editableWizardContent(from: existingMessage, trigger: draft.trigger)
            try await respondWithModal(
                to: interaction,
                customID: ThisIsntIconicWizard.contentModalPrefix + sessionID,
                title: "This Isn't Iconic",
                components: [
                    paragraphInputRow(
                        customID: ThisIsIconicWizard.contentFieldID,
                        label: "What should be different this time?",
                        placeholder: "Rewrite the iconic text here, and include an image URL if you want one.",
                        value: editableContent,
                        maxLength: 4_000
                    ),
                ]
            )
            return
        }

        else {
            try await respond(to: interaction, content: "That button isn't implemented yet.", ephemeral: true)
            return
        }
    }

    func handleModalSubmit(
        _ interaction: DiscordInteraction,
        data: DiscordInteractionData,
        configuration: AppConfiguration
    ) async throws {
        guard let customID = data.custom_id else {
            throw UserFacingError("DiscordInteractionRouter.handleModalSubmit: Discord sent a modal submission without a `custom_id`, so the bot cannot tell which wizard step was submitted. The most likely cause is a malformed modal payload.")
        }

        let userID = try requireInteractionUserID(interaction, context: "this-is-iconic modal submission")
        try ensureConfigAuthorized(member: interaction.member, configuration: configuration)

        switch customID {
        case ThisIsIconicWizard.triggerModalID:
            let submittedTrigger = try requireComponentValue(
                customID: ThisIsIconicWizard.triggerFieldID,
                from: data.components,
                interactionName: "this-is-iconic trigger step"
            )
            let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(submittedTrigger)
            let sessionID = try await warningStore.saveIconicWizardDraft(trigger: normalizedTrigger, userID: userID)

            try await respond(
                to: interaction,
                payload: DiscordMessageCreate(
                    content: ThisIsIconicWizard.continuePrompt,
                    embeds: nil,
                    components: [
                        buttonRow(
                            customID: ThisIsIconicWizard.continueButtonPrefix + sessionID,
                            label: "Keep Going"
                        ),
                    ],
                    flags: 64
                )
            )

        case ThisIsntIconicWizard.triggerModalID:
            let submittedTrigger = try requireComponentValue(
                customID: ThisIsntIconicWizard.triggerFieldID,
                from: data.components,
                interactionName: "this-isn't-iconic trigger step"
            )
            let normalizedTrigger = try IconicMessageConfiguration.normalizedTrigger(submittedTrigger)
            guard let existingMessage = configuration.iconic_messages[normalizedTrigger] else {
                throw UserFacingError("DiscordInteractionRouter.handleModalSubmit: `this-isn't-iconic` could not find an existing iconic trigger named `\(normalizedTrigger)`. The most likely cause is a typo in the trigger text or that the iconic response has not been created yet.")
            }
            let editableContent = try editableWizardContent(from: existingMessage, trigger: normalizedTrigger)
            let sessionID = try await warningStore.saveIconicWizardDraft(trigger: normalizedTrigger, userID: userID)

            try await respond(
                to: interaction,
                payload: DiscordMessageCreate(
                    content: editSummaryPrompt(trigger: normalizedTrigger, currentContent: editableContent),
                    embeds: nil,
                    components: [
                        buttonRow(
                            customID: ThisIsntIconicWizard.continueButtonPrefix + sessionID,
                            label: "Keep Going"
                        ),
                    ],
                    flags: 64
                )
            )

        case let modalID where modalID.hasPrefix(ThisIsIconicWizard.contentModalPrefix):
            let sessionID = String(modalID.dropFirst(ThisIsIconicWizard.contentModalPrefix.count))
            let draft = try await warningStore.iconicWizardDraft(sessionID: sessionID, userID: userID)
            let submittedContent = try requireComponentValue(
                customID: ThisIsIconicWizard.contentFieldID,
                from: data.components,
                interactionName: "this-is-iconic content step"
            )
            let iconicMessage = try iconicMessageConfiguration(fromWizardContent: submittedContent)
            _ = try await configurationStore.saveIconicMessage(trigger: draft.trigger, message: iconicMessage)
            try await warningStore.removeIconicWizardDraft(sessionID: sessionID)
            try await respond(to: interaction, content: ThisIsIconicWizard.successMessage, ephemeral: true)

        case let modalID where modalID.hasPrefix(ThisIsntIconicWizard.contentModalPrefix):
            let sessionID = String(modalID.dropFirst(ThisIsntIconicWizard.contentModalPrefix.count))
            let draft = try await warningStore.iconicWizardDraft(sessionID: sessionID, userID: userID)
            let submittedContent = try requireComponentValue(
                customID: ThisIsIconicWizard.contentFieldID,
                from: data.components,
                interactionName: "this-isn't-iconic content step"
            )
            let iconicMessage = try iconicMessageConfiguration(fromWizardContent: submittedContent)
            _ = try await configurationStore.saveIconicMessage(trigger: draft.trigger, message: iconicMessage)
            try await warningStore.removeIconicWizardDraft(sessionID: sessionID)
            try await respond(to: interaction, content: ThisIsntIconicWizard.successMessage, ephemeral: true)

        default:
            throw UserFacingError("DiscordInteractionRouter.handleModalSubmit: the bot received an unknown modal step `\(customID)`, so it cannot continue the wizard. The most likely cause is an outdated button or modal still open in Discord.")
        }
    }

    func startThisIsIconicWizard(_ interaction: DiscordInteraction) async throws {
        try await respondWithModal(
            to: interaction,
            customID: ThisIsIconicWizard.triggerModalID,
            title: "This Is Iconic",
            components: [
                shortInputRow(
                    customID: ThisIsIconicWizard.triggerFieldID,
                    label: "What trigger text should wake up this iconic moment?",
                    placeholder: "Type the trigger text here."
                ),
            ]
        )
    }

    func startThisIsntIconicWizard(_ interaction: DiscordInteraction) async throws {
        try await respondWithModal(
            to: interaction,
            customID: ThisIsntIconicWizard.triggerModalID,
            title: "This Isn't Iconic",
            components: [
                shortInputRow(
                    customID: ThisIsntIconicWizard.triggerFieldID,
                    label: "Which iconic trigger should change?",
                    placeholder: "Type the existing trigger text here."
                ),
            ]
        )
    }

    // MARK: Wizard Helpers

    func iconicMessageConfiguration(fromWizardContent content: String) throws -> IconicMessageConfiguration {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw UserFacingError("DiscordInteractionRouter.iconicMessageConfiguration: the iconic content cannot be blank. The most likely cause is that the modal was submitted without any text.")
        }

        let imageURL = firstURL(in: content)
        let embed = DiscordEmbed(
            title: nil,
            type: nil,
            description: content,
            url: nil,
            color: nil,
            footer: nil,
            image: imageURL.map { DiscordEmbedImage(url: $0.absoluteString, height: nil, width: nil) }
        )
        return try IconicMessageConfiguration(content: nil, embeds: [embed]).readyForRuntime(trigger: "this-is-iconic")
    }

    func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector?
            .matches(in: text, options: [], range: range)
            .compactMap { match -> URL? in
                guard match.resultType == .link else {
                    return nil
                }
                return match.url
            }
            .first
    }

    func editableWizardContent(from message: IconicMessageConfiguration, trigger: String) throws -> String {
        if let content = message.content, message.embeds == nil {
            return content
        }

        if
            message.content == nil,
            let embeds = message.embeds,
            embeds.count == 1,
            let embed = embeds.first,
            embed.title == nil,
            embed.type == nil,
            embed.url == nil,
            embed.color == nil,
            embed.footer == nil,
            let description = embed.description
        {
            return description
        }

        throw UserFacingError("DiscordInteractionRouter.editableWizardContent: iconic trigger `\(trigger)` uses a richer payload than the current `/this-is-iconic` editor can round-trip safely. The most likely cause is a hand-authored config entry with extra embed fields or mixed text-plus-embed content; edit that entry directly in `fizze-assistant-local.json` instead.")
    }

    func editSummaryPrompt(trigger: String, currentContent: String) -> String {
        let previewLimit = 700
        let preview: String
        if currentContent.count <= previewLimit {
            preview = currentContent
        } else {
            preview = String(currentContent.prefix(previewLimit)) + "..."
        }

        return """
        okay, right now when someone says `\(trigger)`, i reply with this:
        ```text
        \(preview)
        ```
        what should be different this time?
        """
    }

    // MARK: Private Helpers

    private func requireInteractionUserID(_ interaction: DiscordInteraction, context: String) throws -> DiscordSnowflake {
        guard let userID = interaction.member?.user?.id else {
            throw UserFacingError("DiscordInteractionRouter.requireInteractionUserID: `\(context)` did not include the invoking user ID, so the bot cannot safely continue this private wizard flow. The most likely cause is an unexpected Discord interaction payload shape.")
        }
        return userID
    }

    private func shortInputRow(customID: String, label: String, placeholder: String) -> DiscordComponent {
        DiscordComponent(
            type: DiscordComponentType.actionRow,
            components: [
                DiscordComponent(
                    type: DiscordComponentType.textInput,
                    components: nil,
                    custom_id: customID,
                    style: DiscordTextInputStyle.short,
                    label: label,
                    title: nil,
                    description: nil,
                    value: nil,
                    url: nil,
                    placeholder: placeholder,
                    required: true,
                    min_length: 1,
                    max_length: 100
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

    private func paragraphInputRow(customID: String, label: String, placeholder: String, value: String? = nil, maxLength: Int) -> DiscordComponent {
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
                    value: value,
                    url: nil,
                    placeholder: placeholder,
                    required: true,
                    min_length: 1,
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

    private func buttonRow(customID: String, label: String) -> DiscordComponent {
        DiscordComponent(
            type: DiscordComponentType.actionRow,
            components: [
                DiscordComponent(
                    type: DiscordComponentType.button,
                    components: nil,
                    custom_id: customID,
                    style: DiscordButtonStyle.primary,
                    label: label,
                    title: nil,
                    description: nil,
                    value: nil,
                    url: nil,
                    placeholder: nil,
                    required: nil,
                    min_length: nil,
                    max_length: nil
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

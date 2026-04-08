import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized) // Serialized because these flow tests share filesystem-backed config and warning-store state.
struct DiscordInteractionRouterTests {
    @Test
    func thisIsIconicWizardPersistsEmbedBackedMessageAcrossAllSteps() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(id: "interaction-1", name: "this-is-iconic", memberRoles: ["config-role"]),
            guildName: "Guild"
        )

        let modalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        #expect(modalPayload.type == DiscordInteractionCallbackType.modal)
        #expect(modalPayload.data?.custom_id == ThisIsIconicWizard.triggerModalID)

        await router.handle(
            modalInteraction(
                id: "interaction-2",
                customID: ThisIsIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.triggerFieldID,
                value: "FIZZE TIME"
            ),
            guildName: "Guild"
        )

        let continuePayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let continueButtonID = continuePayload.data?.components?.first?.components?.first?.custom_id
        #expect(continuePayload.data?.content == ThisIsIconicWizard.continuePrompt)

        await router.handle(
            buttonInteraction(
                id: "interaction-3",
                customID: try #require(continueButtonID),
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let contentModalID = contentModalPayload.data?.custom_id
        #expect(contentModalPayload.type == DiscordInteractionCallbackType.modal)
        let contentField = try #require(contentModalPayload.data?.components?.first?.components?.first)
        #expect(contentField.custom_id == ThisIsIconicWizard.contentFieldID)
        #expect(contentField.label == ThisIsIconicWizard.contentFieldLabel)
        #expect((contentField.label?.count ?? 0) <= 45)
        #expect(contentField.placeholder == ThisIsIconicWizard.contentFieldPlaceholder)

        await router.handle(
            modalInteraction(
                id: "interaction-4",
                customID: try #require(contentModalID),
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "sparkle mode engaged https://example.com/iconic.png"
            ),
            guildName: "Guild"
        )

        let successPayload = try lastInteractionPayload(from: stub)
        #expect(successPayload.data?.content == ThisIsIconicWizard.successMessage)

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages["fizze time"]?.content == nil)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "sparkle mode engaged https://example.com/iconic.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/iconic.png")
    }

    @Test
    func thisIsIconicWizardSurvivesRouterRecreationBetweenSteps() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let firstRouter = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await firstRouter.handle(
            modalInteraction(
                id: "interaction-restart-1",
                customID: ThisIsIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.triggerFieldID,
                value: "FIZZE RESTART"
            ),
            guildName: "Guild"
        )

        let continuePayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let continueButtonID = try #require(continuePayload.data?.components?.first?.components?.first?.custom_id)

        let restartedRouter = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await restartedRouter.handle(
            buttonInteraction(
                id: "interaction-restart-2",
                customID: continueButtonID,
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let contentModalID = try #require(contentModalPayload.data?.custom_id)

        await restartedRouter.handle(
            modalInteraction(
                id: "interaction-restart-3",
                customID: contentModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "restart-safe sparkle"
            ),
            guildName: "Guild"
        )

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages["fizze restart"]?.embeds?.first?.description == "restart-safe sparkle")
    }

    @Test
    func thisIsntIconicCommandCanEditExistingTriggerThroughPrefilledContentModal() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "old sparkle https://example.com/old.png",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: DiscordEmbedImage(url: "https://example.com/old.png", height: nil, width: nil)
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            slashInteraction(
                id: "interaction-edit-1",
                name: "this-isnt-iconic",
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let modalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        #expect(modalPayload.data?.custom_id == ThisIsntIconicWizard.triggerModalID)

        await router.handle(
            modalInteraction(
                id: "interaction-edit-2",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )

        let continuePayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        #expect(continuePayload.data?.content?.contains("right now when someone says `fizze time`") == true)

        await router.handle(
            buttonInteraction(
                id: "interaction-edit-3",
                customID: try #require(continuePayload.data?.components?.first?.components?.first?.custom_id),
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let contentField = try #require(contentModalPayload.data?.components?.first?.components?.first)
        #expect(contentField.value == "old sparkle https://example.com/old.png")
        #expect(contentField.label == "What should be different this time?")

        await router.handle(
            modalInteraction(
                id: "interaction-edit-4",
                customID: try #require(contentModalPayload.data?.custom_id),
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "new sparkle https://example.com/new.png"
            ),
            guildName: "Guild"
        )

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "new sparkle https://example.com/new.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/new.png")
    }

    @Test
    func thisIsIconicTextOnlyContentPersistsAsEmbedWithoutImage() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            modalInteraction(
                id: "interaction-text-only-1",
                customID: ThisIsIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.triggerFieldID,
                value: "just words"
            ),
            guildName: "Guild"
        )

        let continuePayload = try lastInteractionPayload(from: stub)
        let continueButtonID = try #require(continuePayload.data?.components?.first?.components?.first?.custom_id)

        await router.handle(
            buttonInteraction(
                id: "interaction-text-only-2",
                customID: continueButtonID,
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try lastInteractionPayload(from: stub)
        let contentModalID = try #require(contentModalPayload.data?.custom_id)

        await router.handle(
            modalInteraction(
                id: "interaction-text-only-3",
                customID: contentModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "just sparkle words"
            ),
            guildName: "Guild"
        )

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages["just words"]?.content == nil)
        #expect(persisted.iconic_messages["just words"]?.embeds?.first?.description == "just sparkle words")
        #expect(persisted.iconic_messages["just words"]?.embeds?.first?.image == nil)
    }

    @Test
    func thisIsIconicCreateFlowDocumentsTheWholeAuthoringContract() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(id: "interaction-contract-create-1", name: "this-is-iconic", memberRoles: ["config-role"]),
            guildName: "Guild"
        )

        let triggerModalPayload = try lastInteractionPayload(from: stub)
        #expect(triggerModalPayload.type == DiscordInteractionCallbackType.modal)
        #expect(triggerModalPayload.data?.custom_id == ThisIsIconicWizard.triggerModalID)
        #expect(triggerModalPayload.data?.title == "This Is Iconic")
        let triggerField = try #require(triggerModalPayload.data?.components?.first?.components?.first)
        #expect(triggerField.custom_id == ThisIsIconicWizard.triggerFieldID)
        #expect(triggerField.label == "What trigger should start this iconic moment?")
        #expect(triggerField.placeholder == "Type the trigger text here.")

        await router.handle(
            modalInteraction(
                id: "interaction-contract-create-2",
                customID: ThisIsIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.triggerFieldID,
                value: "  FIZZE TIME  "
            ),
            guildName: "Guild"
        )

        let continuePayload = try lastInteractionPayload(from: stub)
        #expect(continuePayload.type == DiscordInteractionCallbackType.channelMessageWithSource)
        #expect(continuePayload.data?.flags == 64)
        #expect(continuePayload.data?.content == ThisIsIconicWizard.continuePrompt)
        let continueButton = try #require(continuePayload.data?.components?.first?.components?.first)
        #expect(continueButton.label == "Keep Going")
        let continueButtonID = try #require(continueButton.custom_id)
        #expect(continueButtonID.hasPrefix(ThisIsIconicWizard.continueButtonPrefix))

        await router.handle(
            buttonInteraction(
                id: "interaction-contract-create-3",
                customID: continueButtonID,
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try lastInteractionPayload(from: stub)
        #expect(contentModalPayload.type == DiscordInteractionCallbackType.modal)
        #expect(contentModalPayload.data?.title == "This Is Iconic")
        let contentModalID = try #require(contentModalPayload.data?.custom_id)
        #expect(contentModalID.hasPrefix(ThisIsIconicWizard.contentModalPrefix))
        let contentField = try #require(contentModalPayload.data?.components?.first?.components?.first)
        #expect(contentField.custom_id == ThisIsIconicWizard.contentFieldID)
        #expect(contentField.label == ThisIsIconicWizard.contentFieldLabel)
        #expect(contentField.placeholder == ThisIsIconicWizard.contentFieldPlaceholder)

        await router.handle(
            modalInteraction(
                id: "interaction-contract-create-4",
                customID: contentModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "sparkle mode engaged https://example.com/iconic.png"
            ),
            guildName: "Guild"
        )

        let successPayload = try lastInteractionPayload(from: stub)
        #expect(successPayload.type == DiscordInteractionCallbackType.channelMessageWithSource)
        #expect(successPayload.data?.flags == 64)
        #expect(successPayload.data?.content == ThisIsIconicWizard.successMessage)

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages.keys.sorted() == ["fizze time"])
        #expect(persisted.iconic_messages["fizze time"]?.content == nil)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.count == 1)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "sparkle mode engaged https://example.com/iconic.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/iconic.png")
    }

    @Test
    func thisIsntIconicEditFlowRewritesContentWhilePreservingTriggerIdentity() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "old sparkle words",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            modalInteraction(
                id: "interaction-edit-preserve-1",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )

        let continuePayload = try lastInteractionPayload(from: stub)
        let continueButtonID = try #require(continuePayload.data?.components?.first?.components?.first?.custom_id)
        #expect(continuePayload.data?.content?.contains("right now when someone says `fizze time`") == true)
        #expect(continuePayload.data?.content?.contains("old sparkle words") == true)

        await router.handle(
            buttonInteraction(
                id: "interaction-edit-preserve-2",
                customID: continueButtonID,
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try lastInteractionPayload(from: stub)
        let contentModalID = try #require(contentModalPayload.data?.custom_id)
        let contentField = try #require(contentModalPayload.data?.components?.first?.components?.first)
        #expect(contentField.value == "old sparkle words")

        await router.handle(
            modalInteraction(
                id: "interaction-edit-preserve-3",
                customID: contentModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "new sparkle words"
            ),
            guildName: "Guild"
        )

        let successPayload = try lastInteractionPayload(from: stub)
        #expect(successPayload.data?.content == ThisIsntIconicWizard.successMessage)

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages.keys.sorted() == ["fizze time"])
        #expect(persisted.iconic_messages["fizze time"]?.content == nil)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "new sparkle words")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image == nil)
    }

    @Test
    func thisIsntIconicEditFlowDocumentsTheWholeEditingContract() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "old sparkle https://example.com/old.png",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: DiscordEmbedImage(url: "https://example.com/old.png", height: nil, width: nil)
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            slashInteraction(
                id: "interaction-contract-edit-1",
                name: "this-isnt-iconic",
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let triggerModalPayload = try lastInteractionPayload(from: stub)
        #expect(triggerModalPayload.type == DiscordInteractionCallbackType.modal)
        #expect(triggerModalPayload.data?.custom_id == ThisIsntIconicWizard.triggerModalID)
        #expect(triggerModalPayload.data?.title == "This Isn't Iconic")
        let triggerField = try #require(triggerModalPayload.data?.components?.first?.components?.first)
        #expect(triggerField.custom_id == ThisIsntIconicWizard.triggerFieldID)
        #expect(triggerField.label == "Which iconic trigger should change?")
        #expect(triggerField.placeholder == "Type the existing trigger text here.")

        await router.handle(
            modalInteraction(
                id: "interaction-contract-edit-2",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )

        let continuePayload = try lastInteractionPayload(from: stub)
        #expect(continuePayload.type == DiscordInteractionCallbackType.channelMessageWithSource)
        #expect(continuePayload.data?.flags == 64)
        #expect(continuePayload.data?.content?.contains("right now when someone says `fizze time`") == true)
        #expect(continuePayload.data?.content?.contains("old sparkle https://example.com/old.png") == true)
        let continueButton = try #require(continuePayload.data?.components?.first?.components?.first)
        #expect(continueButton.label == "Keep Going")
        let continueButtonID = try #require(continueButton.custom_id)
        #expect(continueButtonID.hasPrefix(ThisIsntIconicWizard.continueButtonPrefix))

        await router.handle(
            buttonInteraction(
                id: "interaction-contract-edit-3",
                customID: continueButtonID,
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let contentModalPayload = try lastInteractionPayload(from: stub)
        #expect(contentModalPayload.type == DiscordInteractionCallbackType.modal)
        #expect(contentModalPayload.data?.title == "This Isn't Iconic")
        let contentModalID = try #require(contentModalPayload.data?.custom_id)
        #expect(contentModalID.hasPrefix(ThisIsntIconicWizard.contentModalPrefix))
        let contentField = try #require(contentModalPayload.data?.components?.first?.components?.first)
        #expect(contentField.custom_id == ThisIsIconicWizard.contentFieldID)
        #expect(contentField.label == "What should be different this time?")
        #expect(contentField.placeholder == "Rewrite the iconic text here, and include an image URL if you want one.")
        #expect(contentField.value == "old sparkle https://example.com/old.png")

        await router.handle(
            modalInteraction(
                id: "interaction-contract-edit-4",
                customID: contentModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "new sparkle https://example.com/new.png"
            ),
            guildName: "Guild"
        )

        let successPayload = try lastInteractionPayload(from: stub)
        #expect(successPayload.type == DiscordInteractionCallbackType.channelMessageWithSource)
        #expect(successPayload.data?.flags == 64)
        #expect(successPayload.data?.content == ThisIsntIconicWizard.successMessage)

        let persisted = try persistedLocalConfiguration(rootURL: rootURL)
        #expect(persisted.iconic_messages.keys.sorted() == ["fizze time"])
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "new sparkle https://example.com/new.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/new.png")
    }

    @Test
    func iconicWizardCreateAndEditFlowSurfacesStayWithinDiscordFieldLengthLimits() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "old sparkle words",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            slashInteraction(id: "interaction-limits-create", name: "this-is-iconic", memberRoles: ["config-role"]),
            guildName: "Guild"
        )
        let createTriggerModal = try lastInteractionPayload(from: stub)

        await router.handle(
            modalInteraction(
                id: "interaction-limits-create-2",
                customID: ThisIsIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )
        let createContinuePayload = try lastInteractionPayload(from: stub)

        await router.handle(
            buttonInteraction(
                id: "interaction-limits-create-3",
                customID: try #require(createContinuePayload.data?.components?.first?.components?.first?.custom_id),
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )
        let createContentModal = try lastInteractionPayload(from: stub)

        await router.handle(
            slashInteraction(id: "interaction-limits-edit", name: "this-isnt-iconic", memberRoles: ["config-role"]),
            guildName: "Guild"
        )
        let editTriggerModal = try lastInteractionPayload(from: stub)

        await router.handle(
            modalInteraction(
                id: "interaction-limits-edit-2",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )
        let editContinuePayload = try lastInteractionPayload(from: stub)

        await router.handle(
            buttonInteraction(
                id: "interaction-limits-edit-3",
                customID: try #require(editContinuePayload.data?.components?.first?.components?.first?.custom_id),
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )
        let editContentModal = try lastInteractionPayload(from: stub)

        assertModalSurfaceLengths(createTriggerModal)
        assertButtonSurfaceLengths(createContinuePayload)
        assertSummaryLength(createContinuePayload, maxLength: 2_000)
        assertModalSurfaceLengths(createContentModal)

        assertModalSurfaceLengths(editTriggerModal)
        assertButtonSurfaceLengths(editContinuePayload)
        assertSummaryLength(editContinuePayload, maxLength: 2_000)
        assertModalSurfaceLengths(editContentModal)
    }

    @Test
    func thisIsntIconicReturnsTypoOrMissingTriggerGuidanceForUnknownTrigger() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            modalInteraction(
                id: "interaction-missing-trigger",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "missing iconic thing"
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("could not find an existing iconic trigger named `missing iconic thing`") == true)
        #expect(payload.data?.content?.contains("typo in the trigger text") == true)
    }

    @Test
    func thisIsntIconicRejectsRicherPayloadsWithLocalConfigEditingGuidance() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: "plain text",
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "rich embed",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            modalInteraction(
                id: "interaction-rich-payload",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "fizze time"
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("uses a richer payload") == true)
        #expect(payload.data?.content?.contains("fizze-assistant-local.json") == true)
    }

    @Test
    func thisIsIconicContinueButtonReturnsReadableErrorWhenDraftIsMissing() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            buttonInteraction(
                id: "interaction-missing-create-draft",
                customID: ThisIsIconicWizard.continueButtonPrefix + "missing-draft",
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("draft has expired or is missing") == true)
        #expect(payload.data?.content?.contains("start `/this-is-iconic` again") == true)
    }

    @Test
    func thisIsntIconicContinueButtonReturnsReadableErrorWhenDraftIsMissing() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            buttonInteraction(
                id: "interaction-missing-edit-draft",
                customID: ThisIsntIconicWizard.continueButtonPrefix + "missing-draft",
                memberRoles: ["config-role"]
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("draft has expired or is missing") == true)
        #expect(payload.data?.content?.contains("start `/this-is-iconic` again") == true)
    }

    @Test
    func unknownSecondStepModalReturnsOutdatedModalGuidance() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            modalInteraction(
                id: "interaction-unknown-modal",
                customID: "this-is-iconic:old-content-modal:stale",
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "stale content"
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("received an unknown modal step") == true)
        #expect(payload.data?.content?.contains("outdated button or modal still open in Discord") == true)
    }

    @Test
    func thisIsntIconicNormalizesMixedCaseAndSurroundingWhitespaceBeforeLookup() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client) { configuration in
            configuration.iconic_messages = [
                "fizze time": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "normalized old sparkle",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
            ]
        }

        await router.handle(
            modalInteraction(
                id: "interaction-normalized-trigger",
                customID: ThisIsntIconicWizard.triggerModalID,
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsntIconicWizard.triggerFieldID,
                value: "  FIZZE TIME  "
            ),
            guildName: "Guild"
        )

        let payload = try lastInteractionPayload(from: stub)
        #expect(payload.data?.content?.contains("right now when someone says `fizze time`") == true)
        #expect(payload.data?.flags == 64)
    }

    @Test
    func unauthorizedThisIsIconicCommandNamesTheIconicCommandInsteadOfConfig() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(id: "interaction-unauthorized-1", name: "this-is-iconic", memberRoles: ["staff-role"]),
            guildName: "Guild"
        )

        let errorPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let message = try #require(errorPayload.data?.content)
        #expect(message.contains("`/this-is-iconic` is limited"))
        #expect(!message.contains("`/config` is limited"))
    }

    @Test
    func unauthorizedThisIsIconicContinueButtonNamesTheWizardStepInsteadOfConfig() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            buttonInteraction(
                id: "interaction-unauthorized-2",
                customID: ThisIsIconicWizard.continueButtonPrefix + "draft-123",
                memberRoles: ["staff-role"]
            ),
            guildName: "Guild"
        )

        let errorPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let message = try #require(errorPayload.data?.content)
        #expect(message.contains("the `this-is-iconic` continue button"))
        #expect(!message.contains("`/config` is limited"))
    }
}

private func assertModalSurfaceLengths(_ payload: InteractionCallbackPayload) {
    #expect((payload.data?.custom_id?.count ?? 0) <= 100)
    #expect((payload.data?.title?.count ?? 0) <= 45)

    let fields = payload.data?.components?.flatMap { $0.components ?? [] } ?? []
    for field in fields {
        #expect((field.custom_id?.count ?? 0) <= 100)
        #expect((field.label?.count ?? 0) <= 45)
        #expect((field.placeholder?.count ?? 0) <= 100)
        if let value = field.value {
            #expect(value.count <= 4_000)
        }
    }
}

private func assertButtonSurfaceLengths(_ payload: InteractionCallbackPayload) {
    let buttons = payload.data?.components?.flatMap { $0.components ?? [] } ?? []
    for button in buttons {
        #expect((button.custom_id?.count ?? 0) <= 100)
        #expect((button.label?.count ?? 0) <= 80)
    }
}

private func assertSummaryLength(_ payload: InteractionCallbackPayload, maxLength: Int) {
    #expect((payload.data?.content?.count ?? 0) <= maxLength)
}

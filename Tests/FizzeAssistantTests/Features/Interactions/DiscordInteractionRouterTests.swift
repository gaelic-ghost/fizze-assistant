import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
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

        let successPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        #expect(successPayload.data?.content == ThisIsIconicWizard.successMessage)

        let persisted = try JSONDecoder().decode(
            BotConfigurationFile.self,
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant-local.json"))
        )
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

        let persisted = try JSONDecoder().decode(
            BotConfigurationFile.self,
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant-local.json"))
        )
        #expect(persisted.iconic_messages["fizze restart"]?.embeds?.first?.description == "restart-safe sparkle")
    }

    @Test
    func thisIsIconicCommandCanEditExistingTriggerThroughPrefilledContentModal() async throws {
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
                name: "this-is-iconic",
                memberRoles: ["config-role"],
                options: [
                    DiscordInteractionOption(name: "trigger", type: 3, value: .string("fizze time"), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        let modalPayload = try decodeRequestBody(
            InteractionCallbackPayload.self,
            from: try #require(stub.requests().last)
        )
        let contentField = try #require(modalPayload.data?.components?.first?.components?.first)
        #expect(contentField.value == "old sparkle https://example.com/old.png")

        await router.handle(
            modalInteraction(
                id: "interaction-edit-2",
                customID: try #require(modalPayload.data?.custom_id),
                memberRoles: ["config-role"],
                fieldCustomID: ThisIsIconicWizard.contentFieldID,
                value: "new sparkle https://example.com/new.png"
            ),
            guildName: "Guild"
        )

        let persisted = try JSONDecoder().decode(
            BotConfigurationFile.self,
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant-local.json"))
        )
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "new sparkle https://example.com/new.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/new.png")
    }
}

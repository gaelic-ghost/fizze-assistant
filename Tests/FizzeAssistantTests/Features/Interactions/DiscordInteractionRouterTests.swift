import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct DiscordInteractionRouterTests {
    // MARK: Tests

    @Test
    func configSetUpdatesPersistedConfigurationAndReturnsEphemeralReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-1",
                name: "config",
                memberRoles: ["config-role"],
                options: [
                    DiscordInteractionOption(
                        name: "set",
                        type: 1,
                        value: nil,
                        options: [
                            DiscordInteractionOption(name: "setting", type: 3, value: .string("trigger_matching_mode"), options: nil),
                            DiscordInteractionOption(name: "value", type: 3, value: .string("fuzze"), options: nil),
                        ]
                    ),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 1)

        let payload = try decodeRequestBody(InteractionCallbackPayload.self, from: try #require(requests.first))
        #expect(payload.type == DiscordInteractionCallbackType.channelMessageWithSource)
        #expect(payload.data?.content == "Updated `trigger_matching_mode`.")
        #expect(payload.data?.flags == 64)

        let persisted = try JSONDecoder().decode(
            BotConfigurationFile.self,
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant.json"))
        )
        #expect(persisted.trigger_matching_mode == .fuzze)
    }

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
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant.json"))
        )
        #expect(persisted.iconic_messages["fizze time"]?.content == nil)
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.description == "sparkle mode engaged https://example.com/iconic.png")
        #expect(persisted.iconic_messages["fizze time"]?.embeds?.first?.image?.url == "https://example.com/iconic.png")
    }

    @Test
    func warnCommandCreatesWarningRecordAndRespondsToModerator() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-warn",
                name: "warn",
                memberRoles: ["staff-role"],
                options: [
                    DiscordInteractionOption(name: "user", type: 6, value: .string("user-2"), options: nil),
                    DiscordInteractionOption(name: "reason", type: 3, value: .string("Too much chaos."), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 2)
        #expect(requests.first?.url?.path == "/api/v10/channels/mod-log-channel/messages")
        #expect(requests.last?.url?.path == "/api/v10/interactions/interaction-warn/token-interaction-warn/callback")

        let warningStore = try WarningStore(path: rootURL.appendingPathComponent("warnings.sqlite").path)
        let warnings = try await warningStore.warnings(for: "user-2", guild_id: "guild")
        #expect(warnings.count == 1)
        #expect(warnings.first?.reason == "Too much chaos.")
    }

    @Test
    func arrestCommandAppliesConfiguredRoleAndAcknowledgesModerator() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-arrest",
                name: "arrest",
                memberRoles: ["staff-role"],
                options: [
                    DiscordInteractionOption(name: "user", type: 6, value: .string("user-9"), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 2)

        let roleRequest = try #require(requests.first)
        #expect(roleRequest.httpMethod == "PUT")
        #expect(roleRequest.url?.path == "/api/v10/guilds/guild/members/user-9/roles/819657472209977404")

        let callbackRequest = try #require(requests.last)
        #expect(callbackRequest.url?.path == "/api/v10/interactions/interaction-arrest/token-interaction-arrest/callback")
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.content == "Applied the arrest role to <@user-9>.")
        #expect(callbackPayload.data?.flags == 64)
    }

    @Test
    func sayCommandPostsToRequestedChannelAndAcknowledgesSender() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-say",
                name: "say",
                memberRoles: ["staff-role"],
                options: [
                    DiscordInteractionOption(name: "channel", type: 7, value: .string("target-channel"), options: nil),
                    DiscordInteractionOption(name: "message", type: 3, value: .string("hello from fizze"), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        let messageRequest = try #require(requests.first(where: { $0.url?.path == "/api/v10/channels/target-channel/messages" }))
        let messagePayload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(messagePayload.content == "hello from fizze")

        let callbackRequest = try #require(requests.last(where: { $0.url?.path == "/api/v10/interactions/interaction-say/token-interaction-say/callback" }))
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.content == "Sent.")
    }

    // MARK: Helpers

    private func slashInteraction(
        id: String,
        name: String,
        memberRoles: [String],
        options: [DiscordInteractionOption]? = nil
    ) -> DiscordInteraction {
        DiscordInteraction(
            id: id,
            application_id: "app",
            type: DiscordInteractionType.applicationCommand,
            token: "token-\(id)",
            member: DiscordInteractionMember(
                user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
                roles: memberRoles,
                permissions: "0"
            ),
            data: DiscordInteractionData(id: "command-\(id)", name: name, custom_id: nil, component_type: nil, options: options, components: nil)
        )
    }

    private func modalInteraction(
        id: String,
        customID: String,
        memberRoles: [String],
        fieldCustomID: String,
        value: String
    ) -> DiscordInteraction {
        DiscordInteraction(
            id: id,
            application_id: "app",
            type: DiscordInteractionType.modalSubmit,
            token: "token-\(id)",
            member: DiscordInteractionMember(
                user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
                roles: memberRoles,
                permissions: "0"
            ),
            data: DiscordInteractionData(
                id: nil,
                name: nil,
                custom_id: customID,
                component_type: nil,
                options: nil,
                components: [
                    DiscordComponent(
                        type: DiscordComponentType.actionRow,
                        components: [
                            DiscordComponent(
                                type: DiscordComponentType.textInput,
                                components: nil,
                                custom_id: fieldCustomID,
                                style: DiscordTextInputStyle.paragraph,
                                label: "Label",
                                title: nil,
                                description: nil,
                                value: value,
                                url: nil,
                                placeholder: nil,
                                required: true,
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
                    ),
                ]
            )
        )
    }

    private func buttonInteraction(id: String, customID: String, memberRoles: [String]) -> DiscordInteraction {
        DiscordInteraction(
            id: id,
            application_id: "app",
            type: DiscordInteractionType.messageComponent,
            token: "token-\(id)",
            member: DiscordInteractionMember(
                user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
                roles: memberRoles,
                permissions: "0"
            ),
            data: DiscordInteractionData(id: nil, name: nil, custom_id: customID, component_type: DiscordComponentType.button, options: nil, components: nil)
        )
    }
}

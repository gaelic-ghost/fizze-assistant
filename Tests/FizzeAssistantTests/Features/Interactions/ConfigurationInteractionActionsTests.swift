import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct ConfigurationInteractionActionsTests {
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
                id: "interaction-config-set",
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

        let request = try #require(stub.requests().first)
        let payload = try decodeRequestBody(InteractionCallbackPayload.self, from: request)
        #expect(payload.data?.content == "Updated `trigger_matching_mode`.")
        #expect(payload.data?.flags == 64)

        let persisted = try JSONDecoder().decode(
            BotConfigurationFile.self,
            from: Data(contentsOf: rootURL.appendingPathComponent("fizze-assistant-local.json"))
        )
        #expect(persisted.trigger_matching_mode == .fuzze)
    }

    @Test
    func triggerCommandsPersistAndListConfiguredTriggers() async throws {
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
                id: "interaction-trigger-add",
                name: "config",
                memberRoles: ["config-role"],
                options: [
                    DiscordInteractionOption(
                        name: "trigger-add",
                        type: 1,
                        value: nil,
                        options: [
                            DiscordInteractionOption(name: "trigger", type: 3, value: .string("fizze time"), options: nil),
                            DiscordInteractionOption(name: "response", type: 3, value: .string("sparkle mode engaged"), options: nil),
                        ]
                    ),
                ]
            ),
            guildName: "Guild"
        )

        await router.handle(
            slashInteraction(
                id: "interaction-trigger-list",
                name: "config",
                memberRoles: ["config-role"],
                options: [
                    DiscordInteractionOption(name: "trigger-list", type: 1, value: nil, options: []),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        let listRequest = try #require(requests.last)
        let listPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: listRequest)
        #expect(listPayload.data?.content?.contains("`fizze time` ->") == true)
    }

    @Test
    func unknownConfigSettingReturnsHumanReadableErrorReply() async throws {
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
                id: "interaction-config-error",
                name: "config",
                memberRoles: ["config-role"],
                options: [
                    DiscordInteractionOption(
                        name: "set",
                        type: 1,
                        value: nil,
                        options: [
                            DiscordInteractionOption(name: "setting", type: 3, value: .string("bogus"), options: nil),
                            DiscordInteractionOption(name: "value", type: 3, value: .string("x"), options: nil),
                        ]
                    ),
                ]
            ),
            guildName: "Guild"
        )

        let request = try #require(stub.requests().first)
        let payload = try decodeRequestBody(InteractionCallbackPayload.self, from: request)
        #expect(payload.data?.flags == 64)
        #expect(payload.data?.content?.contains("unknown setting `bogus`") == true)
    }
}

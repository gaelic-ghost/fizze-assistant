import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct MessagingInteractionActionsTests {
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

    @Test
    func sayCommandFailureReturnsHumanReadableEphemeralReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            if request.url?.path == "/api/v10/channels/target-channel/messages" {
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 403, httpVersion: nil, headerFields: [:])!,
                    Data(#"{"message":"Missing Permissions","code":50013}"#.utf8)
                )
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-say-error",
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
        #expect(requests.count == 2)

        let callbackRequest = try #require(requests.last)
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.flags == 64)
        #expect(callbackPayload.data?.content?.contains("Discord responded with HTTP 403") == true)
    }

    @Test
    func sayCommandRetriesVisiblePostAfterTransientNetworkLoss() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let lock = NSLock()
        var postAttempts = 0
        let stub = makeDiscordRESTClient { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v10/channels/target-channel/messages"):
                lock.lock()
                postAttempts += 1
                let currentAttempt = postAttempts
                lock.unlock()

                if currentAttempt == 1 {
                    throw URLError(.networkConnectionLost)
                }

                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data()
                )

            case ("GET", "/api/v10/users/@me"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data(#"{"id":"bot-1","username":"fizze"}"#.utf8)
                )

            case ("GET", "/api/v10/channels/target-channel/messages"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data("[]".utf8)
                )

            default:
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data()
                )
            }
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-say-retry",
                name: "say",
                memberRoles: ["staff-role"],
                options: [
                    DiscordInteractionOption(name: "channel", type: 7, value: .string("target-channel"), options: nil),
                    DiscordInteractionOption(name: "message", type: 3, value: .string("hello from fizze"), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        #expect(postAttempts == 2)
        let requests = stub.requests()
        let callbackRequest = try #require(requests.last(where: { $0.url?.path == "/api/v10/interactions/interaction-say-retry/token-interaction-say-retry/callback" }))
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.content == "Sent.")
    }

    @Test
    func sotdCommandOpensComposeModal() async throws {
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
                id: "interaction-sotd",
                name: "sotd",
                memberRoles: ["staff-role"],
                options: [DiscordInteractionOption(name: "message", type: 3, value: .string("ignored legacy field"), options: nil)]
            ),
            guildName: "Guild"
        )

        let callbackRequest = try #require(stub.requests().last(where: { $0.url?.path == "/api/v10/interactions/interaction-sotd/token-interaction-sotd/callback" }))
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.type == DiscordInteractionCallbackType.modal)
        #expect(callbackPayload.data?.custom_id == SongOfTheDayModal.modalID)
        #expect(callbackPayload.data?.title == "Song of the Day")
        let firstField = try #require(callbackPayload.data?.components?.first?.components?.first)
        #expect(firstField.custom_id == SongOfTheDayModal.messageFieldID)
        #expect(firstField.label == "What message should go at the top?")
        let secondField = try #require(callbackPayload.data?.components?.dropFirst().first?.components?.first)
        #expect(secondField.custom_id == SongOfTheDayModal.linksFieldID)
        #expect(secondField.label == "Which links should go at the bottom?")
    }

    @Test
    func sotdModalSubmitPostsComposedMessageAndAcknowledgesSender() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            slashInteraction(
                id: "interaction-sotd-submit",
                name: "sotd",
                memberRoles: ["staff-role"],
                options: nil
            ),
            guildName: "Guild"
        )

        await router.handle(
            modalInteraction(
                id: "interaction-sotd-submit-2",
                customID: SongOfTheDayModal.modalID,
                memberRoles: ["staff-role"],
                fields: [
                    (SongOfTheDayModal.messageFieldID, "Today is all about CHVRCHES - Clearest Blue"),
                    (SongOfTheDayModal.linksFieldID, "https://youtu.be/BZyzX4c1vIs\nhttps://open.spotify.com/track/example"),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        let messageRequest = try #require(requests.first(where: { $0.url?.path == "/api/v10/channels/\(AppConfiguration.song_of_the_day_channel_id)/messages" }))
        let messagePayload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(messagePayload.content == "Today is all about CHVRCHES - Clearest Blue\n\nhttps://youtu.be/BZyzX4c1vIs\nhttps://open.spotify.com/track/example")

        let callbackRequest = try #require(requests.last(where: { $0.url?.path == "/api/v10/interactions/interaction-sotd-submit-2/token-interaction-sotd-submit-2/callback" }))
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.content == "Posted to Song of the Day.")
    }

    @Test
    func sotdModalSubmitFailureReturnsHumanReadableEphemeralReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            if request.url?.path == "/api/v10/channels/\(AppConfiguration.song_of_the_day_channel_id)/messages" {
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 403, httpVersion: nil, headerFields: [:])!,
                    Data(#"{"message":"Missing Permissions","code":50013}"#.utf8)
                )
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        await router.handle(
            modalInteraction(
                id: "interaction-sotd-error",
                customID: SongOfTheDayModal.modalID,
                memberRoles: ["staff-role"],
                fields: [
                    (SongOfTheDayModal.messageFieldID, "Broken permissions check"),
                    (SongOfTheDayModal.linksFieldID, "https://example.com"),
                ]
            ),
            guildName: "Guild"
        )

        let callbackRequest = try #require(stub.requests().last)
        let callbackPayload = try decodeRequestBody(InteractionCallbackPayload.self, from: callbackRequest)
        #expect(callbackPayload.data?.flags == 64)
        #expect(callbackPayload.data?.content?.contains("Discord responded with HTTP 403") == true)
    }
}

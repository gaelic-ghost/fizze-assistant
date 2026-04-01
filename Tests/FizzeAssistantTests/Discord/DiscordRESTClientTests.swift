import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct DiscordRESTClientTests {
    // MARK: Tests

    @Test
    func createMessageSendsBotAuthorizedJSONPayload() async throws {
        let stub = makeDiscordRESTClient { request in
            #expect(request.url?.path == "/api/v10/channels/channel-1/messages")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bot token")

            let payload = try decodeRequestBody(DiscordMessageCreate.self, from: request)
            #expect(payload.content == "sparkle")
            #expect(payload.flags == 64)

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.createMessage(channel_id: "channel-1", content: "sparkle", flags: 64)
    }

    @Test
    func createInteractionResponseOmitsBotAuthorization() async throws {
        let stub = makeDiscordRESTClient { request in
            #expect(request.url?.path == "/api/v10/interactions/interaction-1/token-interaction-1/callback")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

            let payload = try decodeRequestBody(InteractionCallbackPayload.self, from: request)
            #expect(payload.type == DiscordInteractionCallbackType.channelMessageWithSource)
            #expect(payload.data?.content == "hello")

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.createInteractionResponse(
            interaction_id: "interaction-1",
            token: "token-interaction-1",
            payload: InteractionCallbackPayload(
                type: DiscordInteractionCallbackType.channelMessageWithSource,
                data: DiscordInteractionCallbackData(
                    content: "hello",
                    embeds: nil,
                    components: nil,
                    flags: 64,
                    custom_id: nil,
                    title: nil
                )
            )
        )
    }

    @Test
    func rateLimitDelayPrefersRetryAfterHeader() {
        let client = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let response = HTTPURLResponse(
            url: URL(string: "https://discord.com/api/v10/test")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: ["Retry-After": "2.5", "X-RateLimit-Reset-After": "9.0"]
        )!

        let delay = client.rateLimitDelay(response: response, body: Data())
        #expect(delay == 2.5)
    }

    @Test
    func rateLimitDelayFallsBackToBody() {
        let client = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let response = HTTPURLResponse(
            url: URL(string: "https://discord.com/api/v10/test")!,
            statusCode: 429,
            httpVersion: nil,
            headerFields: [:]
        )!
        let body = #"{"retry_after":3.75}"#.data(using: .utf8)!

        let delay = client.rateLimitDelay(response: response, body: body)
        #expect(delay == 3.75)
    }

    @Test
    func addRoleRetriesAfterTransientNetworkLoss() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            let currentAttempt = attempts
            lock.unlock()

            #expect(request.url?.path == "/api/v10/guilds/guild-1/members/user-1/roles/role-1")
            #expect(request.httpMethod == "PUT")

            if currentAttempt == 1 {
                throw URLError(.networkConnectionLost)
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 204, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.addRole(to: "user-1", guild_id: "guild-1", role_id: "role-1")

        #expect(stub.requests().count == 2)
    }

    @Test
    func createMessageDoesNotRetryAfterTransientNetworkLoss() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            lock.unlock()

            #expect(request.url?.path == "/api/v10/channels/channel-1/messages")
            #expect(request.httpMethod == "POST")
            throw URLError(.networkConnectionLost)
        }

        do {
            try await stub.client.createMessage(channel_id: "channel-1", content: "sparkle")
            Issue.record("Expected createMessage to fail after the transport drop.")
        } catch let error as URLError {
            #expect(error.code == .networkConnectionLost)
        }

        #expect(attempts == 1)
        #expect(stub.requests().count == 1)
    }
}

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
            #expect(request.value(forHTTPHeaderField: "User-Agent") == "DiscordBot (https://github.com/gaelic-ghost/fizze-assistant, 1.0)")

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
    func editOriginalInteractionResponseUsesWebhookPatchWithoutBotAuthorization() async throws {
        let stub = makeDiscordRESTClient { request in
            #expect(request.url?.path == "/api/v10/webhooks/app-1/token-1/messages/@original")
            #expect(request.httpMethod == "PATCH")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

            let payload = try decodeRequestBody(DiscordMessageCreate.self, from: request)
            #expect(payload.content == "done")

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.editOriginalInteractionResponse(
            application_id: "app-1",
            token: "token-1",
            payload: DiscordMessageCreate(content: "done", embeds: nil, components: nil, flags: nil)
        )
    }

    @Test
    func createInteractionFollowupUsesWebhookPostWithoutBotAuthorization() async throws {
        let stub = makeDiscordRESTClient { request in
            #expect(request.url?.path == "/api/v10/webhooks/app-1/token-1")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == nil)

            let payload = try decodeRequestBody(DiscordMessageCreate.self, from: request)
            #expect(payload.content == "followup")
            #expect(payload.flags == 64)

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.createInteractionFollowup(
            application_id: "app-1",
            token: "token-1",
            payload: DiscordMessageCreate(content: "followup", embeds: nil, components: nil, flags: 64)
        )
    }

    @Test
    func memberRoleBucketLearningCarriesAcrossDifferentUsersInTheSameGuild() async throws {
        let lock = NSLock()
        var requestsByPath: [String: Int] = [:]
        let stub = makeDiscordRESTClient { request in
            let path = try #require(request.url?.path)

            lock.lock()
            requestsByPath[path, default: 0] += 1
            let attempt = requestsByPath[path, default: 0]
            lock.unlock()

            let headers: [String: String]
            if path == "/api/v10/guilds/guild-1/members/user-1/roles/role-1", attempt == 1 {
                headers = [
                    "X-RateLimit-Bucket": "member-role-bucket",
                    "X-RateLimit-Remaining": "0",
                    "X-RateLimit-Reset-After": "0.05",
                ]
            } else {
                headers = [
                    "X-RateLimit-Bucket": "member-role-bucket",
                    "X-RateLimit-Remaining": "1",
                ]
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 204, httpVersion: nil, headerFields: headers)!,
                Data()
            )
        }

        try await stub.client.addRole(to: "user-1", guild_id: "guild-1", role_id: "role-1")

        let start = ContinuousClock.now
        try await stub.client.addRole(to: "user-2", guild_id: "guild-1", role_id: "role-1")
        let elapsed = start.duration(to: .now)

        #expect(elapsed >= .milliseconds(40))
        #expect(stub.requests().count == 2)
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

    @Test
    func createMessageDoesNotRetryAfterServerError() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            lock.unlock()

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 502, httpVersion: nil, headerFields: [:])!,
                Data("bad gateway".utf8)
            )
        }

        do {
            try await stub.client.createMessage(channel_id: "channel-1", content: "sparkle")
            Issue.record("Expected createMessage to fail after the Discord server error.")
        } catch let error as RESTError {
            switch error {
            case let .discordError(statusCode, body):
                #expect(statusCode == 502)
                #expect(body == "bad gateway")
            default:
                Issue.record("Expected a Discord HTTP error for the 502 response.")
            }
        }

        #expect(attempts == 1)
        #expect(stub.requests().count == 1)
    }

    @Test
    func upsertGuildCommandsSurfacesFieldLevelValidationErrorsFromDiscord() async throws {
        let stub = makeDiscordRESTClient { request in
            #expect(request.url?.path == "/api/v10/applications/app-1/guilds/guild-1/commands")
            #expect(request.httpMethod == "PUT")

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 400, httpVersion: nil, headerFields: [:])!,
                Data(
                    #"""
                    {
                      "code": 50035,
                      "message": "Invalid Form Body",
                      "errors": {
                        "0": {
                          "name": {
                            "_errors": [
                              {
                                "code": "APPLICATION_COMMAND_INVALID_NAME",
                                "message": "Command name is invalid"
                              }
                            ]
                          }
                        }
                      }
                    }
                    """#.utf8
                )
            )
        }

        let error = await #expect(throws: RESTError.self, performing: {
            try await stub.client.upsertGuildCommands(
                application_id: "app-1",
                guild_id: "guild-1",
                commands: [
                    DiscordSlashCommand(name: "say", description: "Speak through the bot in another channel.", options: nil),
                ]
            )
        })

        let description = error?.localizedDescription
        #expect(description?.contains("Invalid Form Body") == true)
        #expect(description?.contains("`0.name`: Command name is invalid") == true)
    }

    @Test
    func createInteractionResponseRetriesAfterTransientNetworkLoss() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            let currentAttempt = attempts
            lock.unlock()

            #expect(request.url?.path == "/api/v10/interactions/interaction-1/token-1/callback")
            if currentAttempt == 1 {
                throw URLError(.networkConnectionLost)
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 204, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.createInteractionResponse(
            interaction_id: "interaction-1",
            token: "token-1",
            payload: InteractionCallbackPayload(
                type: DiscordInteractionCallbackType.channelMessageWithSource,
                data: DiscordInteractionCallbackData(
                    content: "hello",
                    embeds: nil,
                    components: nil,
                    flags: nil,
                    custom_id: nil,
                    title: nil
                )
            )
        )

        #expect(attempts == 2)
    }

    @Test
    func createInteractionFollowupRetriesAfterServerError() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            let currentAttempt = attempts
            lock.unlock()

            #expect(request.url?.path == "/api/v10/webhooks/app-1/token-1")
            if currentAttempt == 1 {
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 502, httpVersion: nil, headerFields: [:])!,
                    Data("bad gateway".utf8)
                )
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }

        try await stub.client.createInteractionFollowup(
            application_id: "app-1",
            token: "token-1",
            payload: DiscordMessageCreate(content: "followup", embeds: nil, components: nil, flags: 64)
        )

        #expect(attempts == 2)
    }

    @Test
    func createDMChannelRetriesAfterTransientNetworkLoss() async throws {
        let lock = NSLock()
        var attempts = 0
        let stub = makeDiscordRESTClient { request in
            lock.lock()
            attempts += 1
            let currentAttempt = attempts
            lock.unlock()

            #expect(request.url?.path == "/api/v10/users/@me/channels")
            if currentAttempt == 1 {
                throw URLError(.networkConnectionLost)
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data(#"{"id":"dm-1","type":1}"#.utf8)
            )
        }

        let channel = try await stub.client.createDMChannel(recipient_id: "user-1")
        #expect(channel.id == "dm-1")
        #expect(attempts == 2)
    }

    @Test
    func managedChannelMessageRetriesAfterTransportLossWhenRecentHistoryShowsNoDelivery() async throws {
        let lock = NSLock()
        var postAttempts = 0
        let stub = makeDiscordRESTClient { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v10/channels/channel-1/messages"):
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

            case ("GET", "/api/v10/channels/channel-1/messages"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data("[]".utf8)
                )

            default:
                Issue.record("Unexpected request in managed retry test: \(request.httpMethod ?? "<nil>") \(request.url?.path ?? "<nil>")")
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: [:])!,
                    Data()
                )
            }
        }

        try await stub.client.createManagedMessage(
            channel_id: "channel-1",
            payload: DiscordMessageCreate(content: "sparkle", embeds: nil, components: nil, flags: nil),
            kind: .iconicReply,
            logicalTargetID: "source-message-1"
        )

        #expect(postAttempts == 2)
        let paths = stub.requests().compactMap(\.url?.path)
        #expect(paths == [
            "/api/v10/channels/channel-1/messages",
            "/api/v10/users/@me",
            "/api/v10/channels/channel-1/messages",
            "/api/v10/channels/channel-1/messages",
        ])
    }

    @Test
    func managedChannelMessageSuppressesRetryWhenRecentHistoryAlreadyContainsDeliveredMessage() async throws {
        let lock = NSLock()
        var postAttempts = 0
        let stub = makeDiscordRESTClient { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v10/channels/channel-1/messages"):
                lock.lock()
                postAttempts += 1
                lock.unlock()
                throw URLError(.networkConnectionLost)

            case ("GET", "/api/v10/users/@me"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data(#"{"id":"bot-1","username":"fizze"}"#.utf8)
                )

            case ("GET", "/api/v10/channels/channel-1/messages"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data(#"[{"id":"message-1","channel_id":"channel-1","content":"sparkle","author":{"id":"bot-1","username":"fizze"},"embeds":[],"flags":null}]"#.utf8)
                )

            default:
                Issue.record("Unexpected request in managed dedupe test: \(request.httpMethod ?? "<nil>") \(request.url?.path ?? "<nil>")")
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: [:])!,
                    Data()
                )
            }
        }

        try await stub.client.createManagedMessage(
            channel_id: "channel-1",
            payload: DiscordMessageCreate(content: "sparkle", embeds: nil, components: nil, flags: nil),
            kind: .iconicReply,
            logicalTargetID: "source-message-1"
        )

        #expect(postAttempts == 1)
        let paths = stub.requests().compactMap(\.url?.path)
        #expect(paths == [
            "/api/v10/channels/channel-1/messages",
            "/api/v10/users/@me",
            "/api/v10/channels/channel-1/messages",
        ])
    }

    @Test
    func managedChannelMessagesStaySerializedPerChannelUnderConcurrentBurst() async throws {
        final class PostState: @unchecked Sendable {
            private let lock = NSLock()
            private var postAttempts = 0
            private var overlappingPostDetected = false
            private var firstPostInFlight = false

            func beginPost() -> Int {
                lock.lock()
                defer { lock.unlock() }
                postAttempts += 1
                let currentAttempt = postAttempts
                if firstPostInFlight {
                    overlappingPostDetected = true
                }
                if currentAttempt == 1 {
                    firstPostInFlight = true
                }
                return currentAttempt
            }

            func finishFirstPost() {
                lock.lock()
                defer { lock.unlock() }
                firstPostInFlight = false
            }

            func snapshot() -> (attempts: Int, overlapDetected: Bool) {
                lock.lock()
                defer { lock.unlock() }
                return (postAttempts, overlappingPostDetected)
            }
        }

        let firstPostStarted = DispatchSemaphore(value: 0)
        let releaseFirstPost = DispatchSemaphore(value: 0)
        let postState = PostState()
        let stub = makeDiscordRESTClient { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v10/channels/channel-1/messages"):
                let currentAttempt = postState.beginPost()

                if currentAttempt == 1 {
                    firstPostStarted.signal()
                    _ = releaseFirstPost.wait(timeout: .now() + 1)
                    postState.finishFirstPost()
                }

                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data()
                )

            default:
                Issue.record("Unexpected request in managed lane serialization test: \(request.httpMethod ?? "<nil>") \(request.url?.path ?? "<nil>")")
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 500, httpVersion: nil, headerFields: [:])!,
                    Data()
                )
            }
        }

        async let firstSend: Void = stub.client.createManagedMessage(
            channel_id: "channel-1",
            payload: DiscordMessageCreate(content: "first", embeds: nil, components: nil, flags: nil),
            kind: .iconicReply,
            logicalTargetID: "source-message-1"
        )

        let firstPostDidStart = waitForSemaphore(firstPostStarted, timeout: .now() + 1)
        #expect(firstPostDidStart)

        async let secondSend: Void = stub.client.createManagedMessage(
            channel_id: "channel-1",
            payload: DiscordMessageCreate(content: "second", embeds: nil, components: nil, flags: nil),
            kind: .iconicReply,
            logicalTargetID: "source-message-2"
        )

        try await Task.sleep(for: .milliseconds(100))

        let beforeReleaseSnapshot = postState.snapshot()

        #expect(beforeReleaseSnapshot.attempts == 1)
        #expect(beforeReleaseSnapshot.overlapDetected == false)

        releaseFirstPost.signal()

        _ = try await (firstSend, secondSend)

        let finalSnapshot = postState.snapshot()

        #expect(finalSnapshot.attempts == 2)
        #expect(finalSnapshot.overlapDetected == false)
    }
}

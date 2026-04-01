import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct FizzeBotTests {
    // MARK: Tests

    @Test
    func messageEventSendsMatchingIconicReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.iconic_messages = [
                    "fizze time": IconicMessageConfiguration(content: "sparkle", embeds: nil),
                ]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-1",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "FIZZE TIME",
                    author: DiscordUser(id: "friend-1", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        let messageRequest = try #require(
            stub.requests().last(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" })
        )
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(payload.content == "sparkle")
    }

    @Test
    func botMentionSendsConfiguredReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.bot_mention_responses = ["Fizze Assistant, at your service, {user_mention}."]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-mention-1",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "hello <@bot-user>",
                    author: DiscordUser(id: "friend-2", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        let messageRequest = try #require(
            stub.requests().last(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" })
        )
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(payload.content == "Fizze Assistant, at your service, <@friend-2>.")
    }

    @Test
    func botNicknameMentionSendsConfiguredReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.bot_mention_responses = ["*robot noises*"]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-mention-2",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "hello <@!bot-user>",
                    author: DiscordUser(id: "friend-3", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        let messageRequest = try #require(
            stub.requests().last(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" })
        )
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(payload.content == "*robot noises*")
    }

    @Test
    func mentionCooldownSuppressesSecondImmediateReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.bot_mention_responses = ["hello {user_mention}"]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-mention-3",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "hello <@bot-user>",
                    author: DiscordUser(id: "friend-4", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )
        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-mention-4",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "hello again <@bot-user>",
                    author: DiscordUser(id: "friend-5", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        let messageRequests = stub.requests().filter { $0.url?.path == "/api/v10/channels/source-channel/messages" }
        #expect(messageRequests.count == 1)
    }

    @Test
    func iconicTriggerTakesPrecedenceOverMentionReply() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.bot_mention_responses = ["hello {user_mention}"]
                configuration.iconic_messages = [
                    "<@bot-user>": IconicMessageConfiguration(content: "iconic sparkle", embeds: nil),
                ]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-mention-5",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "<@bot-user>",
                    author: DiscordUser(id: "friend-6", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        let messageRequest = try #require(
            stub.requests().last(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" })
        )
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: messageRequest)
        #expect(payload.content == "iconic sparkle")
    }

    @Test
    func memberJoinAssignsRoleAndPostsWelcome() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(makeConfigurationFile(rootURL: rootURL), to: configURL)
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .memberJoined(
                DiscordGuildMemberAddEvent(
                    user: DiscordUser(id: "new-user", username: "newbie", global_name: "Newbie")
                )
            )
        )

        let requests = stub.requests()
        #expect(requests.contains(where: { $0.url?.path == "/api/v10/guilds/guild/members/new-user/roles/member-role" }))
        let welcomeRequest = try #require(requests.last(where: { $0.url?.path == "/api/v10/channels/welcome-channel/messages" }))
        let welcomePayload = try decodeRequestBody(DiscordMessageCreate.self, from: welcomeRequest)
        #expect(welcomePayload.content == "Welcome, <@new-user>!")
    }

    @Test
    func recentBanCacheTurnsMemberRemovedIntoBanAnnouncement() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            try stubBotRequest(request)
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(makeConfigurationFile(rootURL: rootURL), to: configURL)
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .memberBanned(
                DiscordGuildBanAddEvent(
                    user: DiscordUser(id: "user-2", username: "ghost", global_name: "Ghost")
                )
            )
        )
        await bot.handleEventForTesting(
            .memberRemoved(
                DiscordGuildMemberRemoveEvent(
                    user: DiscordUser(id: "user-2", username: "ghost", global_name: "Ghost")
                )
            )
        )

        let leaveRequest = try #require(
            stub.requests().last(where: { $0.url?.path == "/api/v10/channels/leave-channel/messages" })
        )
        let leavePayload = try decodeRequestBody(DiscordMessageCreate.self, from: leaveRequest)
        #expect(leavePayload.content == "Ghost was banned.")
    }

    @Test
    func iconicReplyRetriesAfterTransientNetworkLoss() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let lock = NSLock()
        var sourceChannelPostAttempts = 0
        let stub = makeDiscordRESTClient { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v10/channels/source-channel/messages"):
                lock.lock()
                sourceChannelPostAttempts += 1
                let currentAttempt = sourceChannelPostAttempts
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
                    Data(#"{"id":"bot-user","username":"fizze","global_name":"Fizze Assistant"}"#.utf8)
                )

            case ("GET", "/api/v10/channels/source-channel/messages"):
                return (
                    HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                    Data("[]".utf8)
                )

            default:
                return try stubBotRequest(request)
            }
        }
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(
            makeConfigurationFile(rootURL: rootURL) { configuration in
                configuration.iconic_messages = [
                    "fizze time": IconicMessageConfiguration(content: "sparkle", embeds: nil),
                ]
            },
            to: configURL
        )
        let store = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let bot = try await FizzeBot(configurationStore: store, restClient: stub.client, logger: .init(label: "test"))

        await bot.handleEventForTesting(
            .message(
                DiscordMessageEvent(
                    id: "message-retry-1",
                    channel_id: "source-channel",
                    guild_id: "guild",
                    content: "FIZZE TIME",
                    author: DiscordUser(id: "friend-1", username: "friend", global_name: "Friend"),
                    webhook_id: nil
                )
            )
        )

        #expect(sourceChannelPostAttempts == 2)
    }

    // MARK: Helpers

    private func stubBotRequest(_ request: URLRequest) throws -> (HTTPURLResponse, Data) {
        let path = request.url?.path
        let responseData: Data

        switch (request.httpMethod, path) {
        case ("GET", "/api/v10/users/@me"):
            responseData = #"{"id":"bot-user","username":"fizze","global_name":"Fizze Assistant"}"#.data(using: .utf8)!
        case ("GET", "/api/v10/guilds/guild"):
            responseData = #"{"id":"guild","name":"Fizze Guild","owner_id":"owner"}"#.data(using: .utf8)!
        case ("GET", "/api/v10/guilds/guild/audit-logs"):
            responseData = #"{"audit_log_entries":[]}"#.data(using: .utf8)!
        default:
            responseData = Data()
        }

        return (
            HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
            responseData
        )
    }
}

import Foundation
import Logging
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct DiscordGatewayClientTests {
    @Test
    func helloAndReadyThenReconnectUsesResumeOnNextSocket() async throws {
        let firstSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"session_id":"session-123","resume_gateway_url":"wss://gateway.resume.discord.gg"},"s":1,"t":"READY"}
            """)),
            .error(URLError(.networkConnectionLost)),
        ])
        let secondSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [firstSocket, secondSocket])
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { _ in }
        )

        try await client.start()

        try await eventually {
            factory.requestedURLs.count == 2
        }

        let requestedURLs = factory.requestedURLs
        #expect(requestedURLs[0].absoluteString == "wss://gateway.discord.gg?v=10&encoding=json")
        #expect(requestedURLs[1].absoluteString == "wss://gateway.resume.discord.gg?v=10&encoding=json")

        try await eventually {
            let secondPayloads = try await secondSocket.sentPayloadObjects()
            return gatewayOpcode(secondPayloads.first?["op"]) == DiscordGatewayOpCode.resume
        }

        let firstPayloads = try await firstSocket.sentPayloadObjects()
        let secondPayloads = try await secondSocket.sentPayloadObjects()
        #expect(gatewayOpcode(firstPayloads.first?["op"]) == DiscordGatewayOpCode.identify)
        #expect(gatewayOpcode(secondPayloads.first?["op"]) == DiscordGatewayOpCode.resume)

        await client.stop()
    }

    @Test
    func invalidSessionReconnectsWithFreshIdentify() async throws {
        let firstSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"session_id":"session-123","resume_gateway_url":"wss://gateway.resume.discord.gg"},"s":1,"t":"READY"}
            """)),
            .message(gatewayMessage("""
            {"op":9,"d":false,"s":2,"t":null}
            """)),
        ])
        let secondSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [firstSocket, secondSocket])
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { _ in }
        )

        try await client.start()

        try await eventually {
            let requested = factory.requestedURLs
            return requested.count == 2
        }

        let requestedURLs = factory.requestedURLs
        #expect(requestedURLs[0].absoluteString == "wss://gateway.discord.gg?v=10&encoding=json")
        #expect(requestedURLs[1].absoluteString == "wss://gateway.discord.gg?v=10&encoding=json")

        let firstPayloads = try await firstSocket.sentPayloadObjects()
        let secondPayloads = try await secondSocket.sentPayloadObjects()
        #expect(gatewayOpcode(firstPayloads.first?["op"]) == DiscordGatewayOpCode.identify)
        #expect(gatewayOpcode(secondPayloads.first?["op"]) == DiscordGatewayOpCode.identify)

        await client.stop()
    }

    @Test
    func messageDispatchForwardsDecodedEventToHandler() async throws {
        let socket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"id":"message-1","channel_id":"channel-1","guild_id":"guild-1","content":"fizze","author":{"id":"user-1","username":"gale","global_name":"Gale"}},"s":2,"t":"MESSAGE_CREATE"}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [socket])
        let recorder = GatewayEventRecorder()
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { event in
                await recorder.append(event)
            }
        )

        try await client.start()

        try await eventually {
            await recorder.snapshot().count == 1
        }

        let events = await recorder.snapshot()
        guard case let .message(event) = events.first else {
            Issue.record("Expected a forwarded message event.")
            return
        }
        #expect(event.content == "fizze")
        #expect(event.channel_id == "channel-1")

        await client.stop()
    }

    @Test
    func interactionDispatchWithNumericCommandIDReachesHandlerWithoutReconnect() async throws {
        let socket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"id":"interaction-1","application_id":"app-1","type":2,"token":"token-1","member":{"roles":["config-role"],"permissions":"0"},"data":{"id":1487254261594325000,"name":"this-is-iconic"}},"s":2,"t":"INTERACTION_CREATE"}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [socket])
        let recorder = GatewayEventRecorder()
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { event in
                await recorder.append(event)
            }
        )

        try await client.start()

        try await eventually {
            await recorder.snapshot().count == 1
        }

        let events = await recorder.snapshot()
        guard case let .interaction(interaction) = events.first else {
            Issue.record("Expected a forwarded interaction event.")
            return
        }
        #expect(interaction.data?.id == "1487254261594325000")
        #expect(interaction.data?.name == "this-is-iconic")
        #expect(factory.requestedURLs.count == 1)

        await client.stop()
    }

    @Test
    func malformedInteractionDispatchIsDroppedWithoutPoisoningLaterEvents() async throws {
        let socket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"id":"interaction-1","application_id":"app-1","type":2,"token":"token-1","member":{"roles":["config-role"],"permissions":"0"},"data":{"id":1487254261594325.5,"name":"this-is-iconic"}},"s":2,"t":"INTERACTION_CREATE"}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"id":"message-1","channel_id":"channel-1","guild_id":"guild-1","content":"fizze","author":{"id":"user-1","username":"gale","global_name":"Gale"}},"s":3,"t":"MESSAGE_CREATE"}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [socket])
        let recorder = GatewayEventRecorder()
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { event in
                await recorder.append(event)
            }
        )

        try await client.start()

        try await eventually {
            await recorder.snapshot().count == 1
        }

        let events = await recorder.snapshot()
        guard case let .message(message) = events.first else {
            Issue.record("Expected the valid message event after the malformed interaction payload.")
            return
        }
        #expect(message.id == "message-1")
        #expect(message.content == "fizze")
        #expect(factory.requestedURLs.count == 1)

        await client.stop()
    }

    @Test
    func toleratedBadDispatchStillUsesResumeOnLaterReconnect() async throws {
        let firstSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"session_id":"session-123","resume_gateway_url":"wss://gateway.resume.discord.gg"},"s":1,"t":"READY"}
            """)),
            .message(gatewayMessage("""
            {"op":0,"d":{"id":"interaction-1","application_id":"app-1","type":2,"token":"token-1","member":{"roles":["config-role"],"permissions":"0"},"data":{"id":1487254261594325.5,"name":"this-is-iconic"}},"s":2,"t":"INTERACTION_CREATE"}
            """)),
            .error(URLError(.networkConnectionLost)),
        ])
        let secondSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":60000},"s":null,"t":null}
            """)),
        ])
        let factory = StubDiscordGatewaySocketFactory(sockets: [firstSocket, secondSocket])
        let recorder = GatewayEventRecorder()
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { event in
                await recorder.append(event)
            }
        )

        try await client.start()

        try await eventually {
            factory.requestedURLs.count == 2
        }

        let requestedURLs = factory.requestedURLs
        #expect(requestedURLs[0].absoluteString == "wss://gateway.discord.gg?v=10&encoding=json")
        #expect(requestedURLs[1].absoluteString == "wss://gateway.resume.discord.gg?v=10&encoding=json")
        #expect(await recorder.snapshot().isEmpty)

        try await eventually {
            let secondPayloads = try await secondSocket.sentPayloadObjects()
            return gatewayOpcode(secondPayloads.first?["op"]) == DiscordGatewayOpCode.resume
        }

        let secondPayloads = try await secondSocket.sentPayloadObjects()
        #expect(gatewayOpcode(secondPayloads.first?["op"]) == DiscordGatewayOpCode.resume)

        await client.stop()
    }

    @Test
    func missedHeartbeatAckSchedulesReconnect() async throws {
        let firstSocket = StubDiscordGatewaySocket(receiveSteps: [
            .message(gatewayMessage("""
            {"op":10,"d":{"heartbeat_interval":1},"s":null,"t":null}
            """)),
        ])
        let secondSocket = StubDiscordGatewaySocket()
        let factory = StubDiscordGatewaySocketFactory(sockets: [firstSocket, secondSocket])
        let client = DiscordGatewayClient(
            token: "token",
            gatewayURL: URL(string: "wss://gateway.discord.gg?v=10&encoding=json")!,
            intents: 513,
            logger: .init(label: "test"),
            makeSocket: { url in
                factory.makeSocket(url: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { _ in 0 },
            onEvent: { _ in }
        )

        try await client.start()

        try await eventually(timeout: .seconds(2)) {
            factory.requestedURLs.count == 2
        }

        let firstPayloads = try await firstSocket.sentPayloadObjects()
        #expect(firstPayloads.contains(where: { gatewayOpcode($0["op"]) == DiscordGatewayOpCode.heartbeat }))

        await client.stop()
    }
}

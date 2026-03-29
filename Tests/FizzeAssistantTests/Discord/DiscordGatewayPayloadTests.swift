import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordGatewayPayloadTests {
    // MARK: Tests

    @Test
    func helloPayloadDecodesHeartbeatIntervalFromGatewayEnvelope() throws {
        let data = """
        {
          "op": 10,
          "d": {
            "heartbeat_interval": 41250
          },
          "s": null,
          "t": null
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)

        guard case let .object(payload)? = envelope.d else {
            Issue.record("Expected hello payload object.")
            return
        }

        guard case let .number(interval)? = payload["heartbeat_interval"] else {
            Issue.record("Expected heartbeat_interval in hello payload.")
            return
        }

        #expect(envelope.op == DiscordGatewayOpCode.hello)
        #expect(interval == 41_250)
    }

    @Test
    func readyPayloadContainsSessionAndResumeURL() throws {
        let data = """
        {
          "op": 0,
          "d": {
            "session_id": "session-123",
            "resume_gateway_url": "wss://gateway.discord.gg"
          },
          "s": 1,
          "t": "READY"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)

        guard case let .object(payload)? = envelope.d else {
            Issue.record("Expected READY payload object.")
            return
        }

        guard case let .string(session_id)? = payload["session_id"] else {
            Issue.record("Expected session_id in READY payload.")
            return
        }

        guard case let .string(resume_gateway_url)? = payload["resume_gateway_url"] else {
            Issue.record("Expected resume_gateway_url in READY payload.")
            return
        }

        #expect(envelope.t == "READY")
        #expect(session_id == "session-123")
        #expect(resume_gateway_url == "wss://gateway.discord.gg")
    }

    @Test
    func messageCreatePayloadDecodesWireFormatNamesDirectly() throws {
        let data = """
        {
          "op": 0,
          "d": {
            "id": "message-123",
            "channel_id": "channel-123",
            "guild_id": "guild-123",
            "content": "fizze",
            "author": {
              "id": "user-123",
              "username": "gale",
              "global_name": "Gale"
            }
          },
          "s": 2,
          "t": "MESSAGE_CREATE"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)
        let payloadData = try JSONEncoder().encode(envelope.d)
        let event = try JSONDecoder().decode(DiscordMessageEvent.self, from: payloadData)

        #expect(envelope.t == "MESSAGE_CREATE")
        #expect(event.channel_id == "channel-123")
        #expect(event.guild_id == "guild-123")
        #expect(event.author.displayName == "Gale")
    }
}

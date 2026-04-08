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

        let interval: Int64
        switch payload["heartbeat_interval"] {
        case let .integer(value)?:
            interval = value
        case let .number(value)?:
            interval = Int64(value)
        default:
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

    @Test
    func interactionCreatePayloadDecodesNumericCommandIDFromGatewayEnvelope() throws {
        let data = """
        {
          "op": 0,
          "d": {
            "id": "interaction-1",
            "application_id": "app-1",
            "type": 2,
            "token": "token-1",
            "member": {
              "roles": ["config-role"],
              "permissions": "0"
            },
            "data": {
              "id": 1487254261594325000,
              "name": "this-is-iconic"
            }
          },
          "s": 3,
          "t": "INTERACTION_CREATE"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)
        let payloadData = try JSONEncoder().encode(envelope.d)
        let interaction = try JSONDecoder().decode(DiscordInteraction.self, from: payloadData)

        #expect(envelope.t == "INTERACTION_CREATE")
        #expect(interaction.data?.id == "1487254261594325000")
        #expect(interaction.data?.name == "this-is-iconic")
    }

    @Test
    func interactionCreatePayloadDecodesNumericTopLevelAndMemberSnowflakesFromGatewayEnvelope() throws {
        let data = """
        {
          "op": 0,
          "d": {
            "id": 1487254261594325201,
            "application_id": 1487254261594325202,
            "type": 2,
            "token": "token-1",
            "channel_id": 1487254261594325203,
            "member": {
              "user": {
                "id": 1487254261594325204,
                "username": "gale",
                "global_name": "Gale"
              },
              "roles": [1487254261594325205, "1487254261594325206"],
              "permissions": "0"
            },
            "data": {
              "id": "1487254261594325207",
              "name": "this-is-iconic"
            }
          },
          "s": 4,
          "t": "INTERACTION_CREATE"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)
        let payloadData = try JSONEncoder().encode(envelope.d)
        let interaction = try JSONDecoder().decode(DiscordInteraction.self, from: payloadData)

        #expect(envelope.t == "INTERACTION_CREATE")
        #expect(interaction.id == "1487254261594325201")
        #expect(interaction.application_id == "1487254261594325202")
        #expect(interaction.channel_id == "1487254261594325203")
        #expect(interaction.member?.user?.id == "1487254261594325204")
        #expect(interaction.member?.roles == ["1487254261594325205", "1487254261594325206"])
    }

    @Test
    func messageCreatePayloadDecodesNumericSnowflakesFromGatewayEnvelope() throws {
        let data = """
        {
          "op": 0,
          "d": {
            "id": 1487254261594325301,
            "channel_id": 1487254261594325302,
            "guild_id": 1487254261594325303,
            "content": "fizze",
            "author": {
              "id": 1487254261594325304,
              "username": "gale",
              "global_name": "Gale"
            },
            "webhook_id": 1487254261594325305
          },
          "s": 5,
          "t": "MESSAGE_CREATE"
        }
        """.data(using: .utf8)!

        let envelope = try JSONDecoder().decode(DiscordGatewayEnvelope.self, from: data)
        let payloadData = try JSONEncoder().encode(envelope.d)
        let event = try JSONDecoder().decode(DiscordMessageEvent.self, from: payloadData)

        #expect(envelope.t == "MESSAGE_CREATE")
        #expect(event.id == "1487254261594325301")
        #expect(event.channel_id == "1487254261594325302")
        #expect(event.guild_id == "1487254261594325303")
        #expect(event.author.id == "1487254261594325304")
        #expect(event.webhook_id == "1487254261594325305")
    }
}

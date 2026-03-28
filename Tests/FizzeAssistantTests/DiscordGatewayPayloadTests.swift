import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordGatewayPayloadTests {
    @Test
    func helloPayloadDecodesHeartbeatIntervalFromGatewayEnvelope() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

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

        let envelope = try decoder.decode(DiscordGatewayEnvelope.self, from: data)

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
}

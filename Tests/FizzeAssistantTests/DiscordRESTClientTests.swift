import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordRESTClientTests {
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
}

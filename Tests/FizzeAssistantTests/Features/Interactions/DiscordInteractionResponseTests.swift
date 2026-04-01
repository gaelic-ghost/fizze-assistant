import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct DiscordInteractionResponseTests {
    @Test
    func deferResponseUsesDeferredEphemeralCallback() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        try await router.deferResponse(
            to: slashInteraction(id: "interaction-defer", name: "say", memberRoles: ["staff-role"]),
            ephemeral: true
        )

        let request = try #require(stub.requests().first)
        let payload = try decodeRequestBody(InteractionCallbackPayload.self, from: request)
        #expect(request.url?.path == "/api/v10/interactions/interaction-defer/token-interaction-defer/callback")
        #expect(payload.type == DiscordInteractionCallbackType.deferredChannelMessageWithSource)
        #expect(payload.data?.flags == 64)
    }

    @Test
    func editOriginalResponseOmitsEphemeralFlags() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        try await router.editOriginalResponse(
            to: slashInteraction(id: "interaction-edit", name: "say", memberRoles: ["staff-role"]),
            payload: DiscordMessageCreate(content: "done", embeds: nil, components: nil, flags: nil)
        )

        let request = try #require(stub.requests().first)
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: request)
        #expect(request.httpMethod == "PATCH")
        #expect(request.url?.path == "/api/v10/webhooks/app/token-interaction-edit/messages/@original")
        #expect(payload.content == "done")
        #expect(payload.flags == nil)
    }

    @Test
    func createInteractionFollowupCanBeEphemeral() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                Data()
            )
        }
        let router = try await makeRouter(rootURL: rootURL, restClient: stub.client)

        try await router.createInteractionFollowup(
            to: slashInteraction(id: "interaction-followup", name: "say", memberRoles: ["staff-role"]),
            payload: DiscordMessageCreate(content: "private", embeds: nil, components: nil, flags: 64)
        )

        let request = try #require(stub.requests().first)
        let payload = try decodeRequestBody(DiscordMessageCreate.self, from: request)
        #expect(request.httpMethod == "POST")
        #expect(request.url?.path == "/api/v10/webhooks/app/token-interaction-followup")
        #expect(payload.flags == 64)
    }
}

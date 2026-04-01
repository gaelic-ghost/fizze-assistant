import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct ModerationInteractionActionsTests {
    @Test
    func warnCommandCreatesWarningRecordAndRespondsToModerator() async throws {
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
                id: "interaction-warn",
                name: "warn",
                memberRoles: ["staff-role"],
                options: [
                    DiscordInteractionOption(name: "user", type: 6, value: .string("user-2"), options: nil),
                    DiscordInteractionOption(name: "reason", type: 3, value: .string("Too much chaos."), options: nil),
                ]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 4)
        let moderatorPayload = try decodeRequestBody(DiscordMessageCreate.self, from: requests[2])
        let channelFollowup = try decodeRequestBody(DiscordMessageCreate.self, from: requests[3])
        #expect(moderatorPayload.flags == nil)
        #expect(channelFollowup.content == "<@user-1> warned <@user-2>.")

        let warningStore = try WarningStore(path: rootURL.appendingPathComponent("warnings.sqlite").path)
        let warnings = try await warningStore.warnings(for: "user-2", guild_id: "guild")
        #expect(warnings.count == 1)
    }

    @Test
    func arrestCommandFallsBackToEphemeralFollowupIfEditOriginalFails() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            if request.url?.path == "/api/v10/webhooks/app/token-interaction-arrest-fallback/messages/@original" {
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
                id: "interaction-arrest-fallback",
                name: "arrest",
                memberRoles: ["staff-role"],
                options: [DiscordInteractionOption(name: "user", type: 6, value: .string("user-9"), options: nil)]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 5)
        let followupRequest = try #require(requests.first(where: { $0.url?.path == "/api/v10/webhooks/app/token-interaction-arrest-fallback" }))
        let followupPayload = try decodeRequestBody(DiscordMessageCreate.self, from: followupRequest)
        #expect(followupPayload.content == "Applied the arrest role to <@user-9>.")
        #expect(followupPayload.flags == 64)

        let visibleMessage = try decodeRequestBody(
            DiscordMessageCreate.self,
            from: try #require(requests.last(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" }))
        )
        #expect(visibleMessage.content == "<@user-1> applied the arrest role to <@user-9>.")
    }

    @Test
    func failedModerationActionEditsPrivateResponseAndSkipsVisibleSuccessPost() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let stub = makeDiscordRESTClient { request in
            if request.url?.path == "/api/v10/guilds/guild/members/user-9/roles/819657472209977404" {
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
                id: "interaction-arrest-error",
                name: "arrest",
                memberRoles: ["staff-role"],
                options: [DiscordInteractionOption(name: "user", type: 6, value: .string("user-9"), options: nil)]
            ),
            guildName: "Guild"
        )

        let requests = stub.requests()
        #expect(requests.count == 3)
        let callbackRequest = try #require(requests.last)
        let callbackPayload = try decodeRequestBody(DiscordMessageCreate.self, from: callbackRequest)
        #expect(callbackPayload.content?.contains("Discord responded with HTTP 403") == true)
        #expect(requests.contains(where: { $0.url?.path == "/api/v10/channels/source-channel/messages" }) == false)
    }
}

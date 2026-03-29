import Foundation
import Testing
@testable import FizzeAssistant

@Suite(.serialized)
struct PermissionReportBuilderTests {
    // MARK: Tests

    @Test
    func buildReportsMissingSendMessagesForConfiguredChannel() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let configuration = AppConfiguration(
            botToken: "token",
            file: makeConfigurationFile(rootURL: rootURL)
        )
        let stub = makeDiscordRESTClient { request in
            let path = request.url?.path
            let responseData: Data

            switch path {
            case "/api/v10/users/@me":
                responseData = #"{"id":"bot-user","username":"fizze","global_name":"Fizze Assistant"}"#.data(using: .utf8)!
            case "/api/v10/guilds/guild":
                responseData = #"{"id":"guild","name":"Fizze Guild","owner_id":"owner"}"#.data(using: .utf8)!
            case "/api/v10/guilds/guild/members/bot-user":
                responseData = #"{"roles":["bot-role"]}"#.data(using: .utf8)!
            case "/api/v10/guilds/guild/roles":
                responseData = """
                [
                  {"id":"bot-role","name":"Bot","permissions":"\(DiscordPermission.viewChannel.rawValue)","position":2},
                  {"id":"member-role","name":"Member","permissions":"0","position":1},
                  {"id":"staff-role","name":"Staff","permissions":"0","position":1},
                  {"id":"config-role","name":"Config","permissions":"0","position":1}
                ]
                """.data(using: .utf8)!
            case "/api/v10/channels/welcome-channel", "/api/v10/channels/leave-channel", "/api/v10/channels/mod-log-channel":
                responseData = """
                {
                  "id":"channel",
                  "name":"arrivals",
                  "type":0,
                  "permission_overwrites":[
                    {"id":"guild","type":0,"allow":"0","deny":"\(DiscordPermission.sendMessages.rawValue)"}
                  ]
                }
                """.data(using: .utf8)!
            default:
                Issue.record("Unexpected permission-report request: \(path ?? "<missing>")")
                responseData = Data()
            }

            return (
                HTTPURLResponse(url: try #require(request.url), statusCode: 200, httpVersion: nil, headerFields: [:])!,
                responseData
            )
        }

        let report = try await PermissionReportBuilder(
            restClient: stub.client,
            configuration: configuration,
            logger: .init(label: "test")
        ).build()

        let rendered = report.renderText()
        #expect(rendered.contains("Send Messages"))
        #expect(rendered.contains("Invite URL"))
        #expect(rendered.contains("Connected to guild"))
    }
}

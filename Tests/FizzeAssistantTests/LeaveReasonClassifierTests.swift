import Foundation
import Testing
@testable import FizzeAssistant

struct LeaveReasonClassifierTests {
    @Test
    func recentBanCacheReturnsBanned() async throws {
        let cache = ModerationEventCache()
        await cache.recordBan(for: "user-1")

        let configuration = AppConfiguration(
            botToken: "token",
            install: InstallConfiguration(
                applicationID: "app",
                guildID: "guild",
                defaultMemberRoleID: "member",
                allowedStaffRoleIDs: ["staff"],
                allowedConfigRoleIDs: ["owner"],
                databasePath: ".data/test.sqlite",
                runtimeConfigPath: ".data/runtime.json"
            ),
            runtime: .defaults
        )

        let restClient = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let classifier = LeaveReasonClassifier(restClient: restClient, configuration: configuration, banCache: cache)

        let banned = await cache.recentBan(for: "user-1", within: 30)
        #expect(banned)
        _ = classifier
    }
}

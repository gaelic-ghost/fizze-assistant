import Foundation
import Testing
@testable import FizzeAssistant

struct LeaveReasonClassifierTests {
    @Test
    func recentBanCacheReturnsBanned() async throws {
        let cache = ModerationEventCache()
        await cache.recordBan(for: "user-1")

        let configuration = try AppConfiguration.load(from: nil, environment: [
            "DISCORD_BOT_TOKEN": "token",
            "DISCORD_APPLICATION_ID": "app",
            "DISCORD_GUILD_ID": "guild",
            "DISCORD_WELCOME_CHANNEL_ID": "welcome",
            "DISCORD_LEAVE_CHANNEL_ID": "leave",
            "DISCORD_MOD_LOG_CHANNEL_ID": "mod",
            "DISCORD_DEFAULT_MEMBER_ROLE_ID": "member",
            "DISCORD_ALLOWED_STAFF_ROLE_IDS": "staff",
        ])

        let restClient = DiscordRESTClient(token: "token", logger: .init(label: "test"))
        let classifier = LeaveReasonClassifier(restClient: restClient, configuration: configuration, banCache: cache)

        let banned = await cache.recentBan(for: "user-1", within: 30)
        #expect(banned)
        _ = classifier
    }
}

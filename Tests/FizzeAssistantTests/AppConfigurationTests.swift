import Foundation
import Testing
@testable import FizzeAssistant

struct AppConfigurationTests {
    @Test
    func configurationStoreParsesSingleConfigFile() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let configurationFile = BotConfigurationFile(
            applicationID: "app",
            guildID: "guild",
            defaultMemberRoleID: "member",
            allowedStaffRoleIDs: ["staff-a", "staff-b"],
            allowedConfigRoleIDs: ["owner-a", "owner-b"],
            databasePath: ".data/fizze-assistant.sqlite",
            welcomeChannelID: "welcome",
            leaveChannelID: "leave",
            modLogChannelID: "mod-log",
            suggestionsChannelID: "suggestions",
            warnUsersViaDM: false,
            welcomeMessage: "hi",
            voluntaryLeaveMessage: "bye",
            kickMessage: "kick",
            banMessage: "ban",
            unknownRemovalMessage: "unknown",
            roleAssignmentFailureMessage: "role failure",
            warningDMTemplate: "warn",
            triggerCooldownSeconds: 30,
            leaveAuditLogLookbackSeconds: 30,
            iconicTriggers: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: configURL)

        let store = try ConfigurationStore.load(from: configURL, environment: [
            "DISCORD_BOT_TOKEN": "token",
        ])
        let configuration = try await store.readyConfiguration()

        #expect(configuration.allowedStaffRoleIDs == ["staff-a", "staff-b"])
        #expect(configuration.allowedConfigRoleIDs == ["owner-a", "owner-b"])
        #expect(configuration.databasePath == ".data/fizze-assistant.sqlite")
        #expect(configuration.suggestionsChannelID == "suggestions")
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct ConfigurationStoreTests {
    @Test
    func runtimeUpdatesPersistToDisk() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")

        let configurationFile = BotConfigurationFile(
            applicationID: "app",
            guildID: "guild",
            defaultMemberRoleID: "member",
            allowedStaffRoleIDs: ["staff"],
            allowedConfigRoleIDs: ["owner"],
            databasePath: rootURL.appendingPathComponent("warnings.sqlite").path,
            welcomeChannelID: nil,
            leaveChannelID: nil,
            modLogChannelID: nil,
            suggestionsChannelID: nil,
            warnUsersViaDM: false,
            welcomeMessage: "Welcome",
            voluntaryLeaveMessage: "Bye",
            kickMessage: "Kick",
            banMessage: "Ban",
            unknownRemovalMessage: "Unknown",
            roleAssignmentFailureMessage: "Role failure",
            warningDMTemplate: "Warn",
            triggerCooldownSeconds: 30,
            leaveAuditLogLookbackSeconds: 30,
            iconicTriggers: []
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: configURL)

        let store = try ConfigurationStore.load(
            from: configURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        _ = try await store.update(setting: .welcomeChannelID, value: "123456")
        _ = try await store.update(setting: .suggestionsChannelID, value: "654321")
        _ = try await store.addTrigger(trigger: "fizze time", response: "sparkle")

        let data = try Data(contentsOf: configURL)
        let runtime = try JSONDecoder().decode(BotConfigurationFile.self, from: data)
        #expect(runtime.welcomeChannelID == "123456")
        #expect(runtime.suggestionsChannelID == "654321")
        #expect(runtime.iconicTriggers.count == 1)
    }
}

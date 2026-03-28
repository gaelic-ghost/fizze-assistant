import Foundation
import Testing
@testable import FizzeAssistant

struct ConfigurationStoreTests {
    @Test
    func runtimeUpdatesPersistToDisk() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let localConfigURL = rootURL.appendingPathComponent("fizze-assistant.local.json")
        let runtimeConfigURL = rootURL.appendingPathComponent("runtime.json")

        let localConfig = InstallConfiguration(
            applicationID: "app",
            guildID: "guild",
            defaultMemberRoleID: "member",
            allowedStaffRoleIDs: ["staff"],
            allowedConfigRoleIDs: ["owner"],
            databasePath: rootURL.appendingPathComponent("warnings.sqlite").path,
            runtimeConfigPath: runtimeConfigURL.path
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(localConfig).write(to: localConfigURL)

        let store = try ConfigurationStore.load(
            from: localConfigURL,
            environment: ["DISCORD_BOT_TOKEN": "token"]
        )

        _ = try await store.update(setting: .welcomeChannelID, value: "123456")
        _ = try await store.addTrigger(trigger: "fizze time", response: "sparkle")

        let data = try Data(contentsOf: runtimeConfigURL)
        let runtime = try JSONDecoder().decode(RuntimeConfiguration.self, from: data)
        #expect(runtime.welcomeChannelID == "123456")
        #expect(runtime.iconicTriggers.count == 1)
    }
}

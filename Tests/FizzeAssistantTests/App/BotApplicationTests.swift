import Foundation
import Testing
@testable import FizzeAssistant

struct BotApplicationTests {
    // MARK: Tests

    @Test
    func configInitCreatesConfigurationFile() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let options = try SharedOptions.parse(["--config", configURL.path])

        try await BotApplication.run(command: .configInit, options: options)

        #expect(FileManager.default.fileExists(atPath: configURL.path))
    }

    @Test
    func configValidateRunsAgainstStoredConfiguration() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        try writeConfigurationFile(makeConfigurationFile(rootURL: rootURL), to: configURL)

        let options = try SharedOptions.parse(["--config", configURL.path])
        try await BotApplication.run(command: .configValidate, options: options)
    }

    @Test
    func cliRegistersExpectedTopLevelCommands() {
        let subcommandNames = FizzeAssistantCLI.configuration.subcommands.map {
            String(describing: $0)
        }

        #expect(subcommandNames.contains("RunCommand"))
        #expect(subcommandNames.contains("RegisterCommandsCommand"))
        #expect(subcommandNames.contains("CheckCommand"))
        #expect(subcommandNames.contains("ConfigCommand"))
    }
}

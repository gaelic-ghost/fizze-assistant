import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordCommandRegistrarTests {
    // MARK: Tests

    @Test
    func guildCommandsIncludeThisIsIconicAndConfigSubcommands() {
        let registrar = DiscordCommandRegistrar(
            restClient: DiscordRESTClient(token: "token", logger: .init(label: "test")),
            configuration: AppConfiguration(botToken: "token", file: .defaults),
            logger: .init(label: "test")
        )

        let commandNames = registrar.guildCommands.map(\.name)
        #expect(commandNames.contains("this-is-iconic"))
        #expect(commandNames.contains("config"))

        let configCommand = registrar.guildCommands.first(where: { $0.name == "config" })
        let subcommandNames = configCommand?.options?.map(\.name) ?? []
        #expect(subcommandNames.contains("trigger-add"))
        #expect(subcommandNames.contains("trigger-list"))
    }
}

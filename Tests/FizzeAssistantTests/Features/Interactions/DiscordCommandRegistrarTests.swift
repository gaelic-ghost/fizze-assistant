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
        #expect(commandNames.contains("this-isnt-iconic"))
        #expect(commandNames.contains("config"))
        #expect(commandNames.contains("arrest"))
        #expect(commandNames.contains("bailout"))

        let configCommand = registrar.guildCommands.first(where: { $0.name == "config" })
        let subcommandNames = configCommand?.options?.map(\.name) ?? []
        #expect(subcommandNames.contains("trigger-add"))
        #expect(subcommandNames.contains("trigger-list"))

        let iconicCommand = registrar.guildCommands.first(where: { $0.name == "this-is-iconic" })
        #expect(iconicCommand?.options == nil)

        let editIconicCommand = registrar.guildCommands.first(where: { $0.name == "this-isnt-iconic" })
        #expect(editIconicCommand?.options == nil)

        let arrestCommand = registrar.guildCommands.first(where: { $0.name == "arrest" })
        #expect(arrestCommand?.options?.first?.name == "user")

        let bailoutCommand = registrar.guildCommands.first(where: { $0.name == "bailout" })
        #expect(bailoutCommand?.options?.first?.name == "user")
    }

    @Test
    func guildCommandsPassLocalDiscordRegistrationValidation() {
        let registrar = DiscordCommandRegistrar(
            restClient: DiscordRESTClient(token: "token", logger: .init(label: "test")),
            configuration: AppConfiguration(botToken: "token", file: .defaults),
            logger: .init(label: "test")
        )

        #expect(registrar.registrationValidationIssues.isEmpty)
    }

    @Test(arguments: [
        "BadName",
        "contains spaces",
        String(repeating: "a", count: 33),
    ])
    func registrationValidationRejectsUnsafeCommandNames(_ invalidName: String) {
        let issues = DiscordRegistrationValidator.issues(
            commands: [
                DiscordSlashCommand(
                    name: invalidName,
                    description: "valid description",
                    options: nil
                ),
            ],
            wizardCustomIDs: []
        )

        #expect(issues.contains { $0.contains("must stay lowercase") })
    }

    @Test
    func registrationValidationRejectsOverlongDescriptions() {
        let issues = DiscordRegistrationValidator.issues(
            commands: [
                DiscordSlashCommand(
                    name: "valid-name",
                    description: String(repeating: "d", count: 101),
                    options: nil
                ),
            ],
            wizardCustomIDs: []
        )

        #expect(issues.contains { $0.contains("descriptions must be between 1 and 100 characters") })
    }

    @Test
    func registrationValidationRejectsRequiredOptionsAfterOptionalOnes() {
        let issues = DiscordRegistrationValidator.issues(
            commands: [
                DiscordSlashCommand(
                    name: "valid-name",
                    description: "valid description",
                    options: [
                        DiscordApplicationCommandOption(
                            type: 3,
                            name: "optional_first",
                            description: "Optional first.",
                            required: false,
                            channel_types: nil
                        ),
                        DiscordApplicationCommandOption(
                            type: 3,
                            name: "required_second",
                            description: "Required second.",
                            required: true,
                            channel_types: nil
                        ),
                    ]
                ),
            ],
            wizardCustomIDs: []
        )

        #expect(issues.contains { $0.contains("required option `required_second` after an optional option") })
    }

    @Test
    func wizardCustomIDsStayWithinDiscordComponentLimits() {
        let issues = DiscordRegistrationValidator.issues(
            commands: [],
            wizardCustomIDs: [
                ThisIsIconicWizard.triggerModalID,
                ThisIsIconicWizard.continueButtonPrefix + String(repeating: "a", count: 36),
                ThisIsIconicWizard.contentModalPrefix + String(repeating: "a", count: 36),
                ThisIsntIconicWizard.triggerModalID,
                ThisIsntIconicWizard.continueButtonPrefix + String(repeating: "a", count: 36),
                ThisIsntIconicWizard.contentModalPrefix + String(repeating: "a", count: 36),
            ]
        )

        #expect(issues.isEmpty)
    }
}

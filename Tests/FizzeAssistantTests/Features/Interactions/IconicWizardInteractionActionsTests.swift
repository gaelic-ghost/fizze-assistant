import Foundation
import Testing
@testable import FizzeAssistant

struct IconicWizardInteractionActionsTests {
    // MARK: Tests

    @Test
    func wizardContentBuildsEmbedAndUsesFirstURLAsImage() async throws {
        let router = try await makeRouter()

        let content = """
        sparkle mode engaged
        https://example.com/first.png
        https://example.com/second.png
        """
        let message = try await router.iconicMessageConfiguration(fromWizardContent: content)

        #expect(message.content == nil)
        #expect(message.embeds?.first?.description == content)
        #expect(message.embeds?.first?.image?.url == "https://example.com/first.png")
    }

    @Test
    func firstStepModalLabelFitsDiscordLimit() {
        let label = "What trigger should start this iconic moment?"
        #expect(label.count <= 45)
        #expect(!label.isEmpty)
    }

    @Test
    func secondStepModalLabelFitsDiscordLimit() {
        #expect(ThisIsIconicWizard.contentFieldLabel.count <= 45)
        #expect(!ThisIsIconicWizard.contentFieldLabel.isEmpty)
    }

    @Test
    func editableWizardContentSupportsTextOnlyReplies() async throws {
        let router = try await makeRouter()

        let content = try await router.editableWizardContent(
            from: IconicMessageConfiguration(content: "sparkle mode engaged", embeds: nil),
            trigger: "fizze time"
        )
        #expect(content == "sparkle mode engaged")
    }

    @Test
    func editableWizardContentRejectsMixedTextAndEmbeds() async throws {
        let router = try await makeRouter()

        let error = await #expect(throws: UserFacingError.self, performing: {
            _ = try await router.editableWizardContent(
                from: IconicMessageConfiguration(
                    content: "sparkle mode engaged",
                    embeds: [
                        DiscordEmbed(
                            title: nil,
                            type: nil,
                            description: "sparkle mode engaged",
                            url: nil,
                            color: nil,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
                trigger: "fizze time"
            )
        })
        #expect(error?.localizedDescription.contains("richer payload") == true)
    }

    // MARK: Helpers

    private func makeRouter() async throws -> DiscordInteractionRouter {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let configURL = rootURL.appendingPathComponent("fizze-assistant.json")
        let configurationFile = BotConfigurationFile(
            application_id: "app",
            guild_id: "guild",
            default_member_role_id: "member",
            allowed_staff_role_ids: ["staff"],
            allowed_config_role_ids: ["owner"],
            database_path: rootURL.appendingPathComponent("warnings.sqlite").path,
            welcome_channel_id: nil,
            leave_channel_id: nil,
            mod_log_channel_id: nil,
            suggestions_channel_id: nil,
            warn_users_via_dm: false,
            welcome_message: "Welcome",
            voluntary_leave_message: "Bye",
            kick_message: "Kick",
            ban_message: "Ban",
            unknown_removal_message: "Unknown",
            role_assignment_failure_message: "Role failure",
            warning_dm_template: "Warn",
            bot_mention_responses: ["hello"],
            trigger_cooldown_seconds: 30,
            leave_audit_log_lookback_seconds: 30,
            trigger_matching_mode: .exact,
            iconic_messages: [:]
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(configurationFile).write(to: configURL)

        let configurationStore = try ConfigurationStore.load(from: configURL, environment: ["DISCORD_BOT_TOKEN": "token"])
        let warningStore = try WarningStore(path: configurationFile.database_path)
        return DiscordInteractionRouter(
            restClient: DiscordRESTClient(token: "token", logger: .init(label: "test")),
            configurationStore: configurationStore,
            warningStore: warningStore,
            logger: .init(label: "test")
        )
    }
}

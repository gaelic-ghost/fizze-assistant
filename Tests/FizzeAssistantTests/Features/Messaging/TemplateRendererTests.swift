import Foundation
import Testing
@testable import FizzeAssistant

struct TemplateRendererTests {
    // MARK: Tests

    @Test
    func renderReplacesKnownTemplateFields() {
        let user = DiscordUser(id: "user-1", username: "gale", global_name: "Gale")
        let rendered = TemplateRenderer.render(
            "Welcome {user_mention} to {guild_name}, {username}!",
            user: user,
            guildName: "Fizze Guild"
        )

        #expect(rendered == "Welcome <@user-1> to Fizze Guild, Gale!")
    }
}

import Foundation

enum TemplateRenderer {
    static func render(_ template: String, user: DiscordUser, guildName: String? = nil) -> String {
        template
            .replacingOccurrences(of: "{user_mention}", with: "<@\(user.id)>")
            .replacingOccurrences(of: "{username}", with: user.displayName)
            .replacingOccurrences(of: "{guild_name}", with: guildName ?? "")
    }
}

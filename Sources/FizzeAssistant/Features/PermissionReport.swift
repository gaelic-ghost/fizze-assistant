import Foundation
import Logging

struct PermissionReport: Sendable {
    struct Issue: Hashable, Sendable {
        enum Severity: String, Sendable {
            case info = "INFO"
            case warning = "WARN"
            case blocking = "BLOCKING"
        }

        var severity: Severity
        var message: String
    }

    var issues: [Issue]

    var hasBlockingIssue: Bool {
        issues.contains { $0.severity == .blocking }
    }

    func renderText() -> String {
        let lines = issues.map { "[\($0.severity.rawValue)] \($0.message)" }
        return (["Fizze Assistant setup report:"] + lines).joined(separator: "\n")
    }
}

struct PermissionReportBuilder {
    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let logger: Logger

    func build() async throws -> PermissionReport {
        var issues: [PermissionReport.Issue] = [
            .init(severity: .info, message: "Reminder: enable the `Server Members Intent` and `Message Content Intent` in the Discord Developer Portal for this bot."),
        ]

        let me = try await restClient.getCurrentUser()
        let guild = try await restClient.getGuild(id: configuration.guildID)
        let botMember = try await restClient.getGuildMember(guildID: configuration.guildID, userID: me.id)
        let roles = try await restClient.getGuildRoles(guildID: configuration.guildID)

        let guildPermissions = PermissionCalculator.guildPermissions(memberRoleIDs: botMember.roles, roles: roles)
        let topRolePosition = roles
            .filter { botMember.roles.contains($0.id) }
            .map(\.position)
            .max() ?? 0

        if !guildPermissions.contains(.manageRoles) {
            issues.append(.init(severity: .blocking, message: "The bot is missing `Manage Roles`, so auto-role assignment will fail."))
        }

        if !guildPermissions.contains(.viewAuditLog) {
            issues.append(.init(severity: .blocking, message: "The bot is missing `View Audit Log`, so it cannot safely distinguish voluntary leaves from kicks/bans."))
        }

        if let defaultRole = roles.first(where: { $0.id == configuration.defaultMemberRoleID }), defaultRole.position >= topRolePosition {
            issues.append(.init(severity: .blocking, message: "The default member role must be below the bot's highest role in the role hierarchy."))
        }

        let welcomeChannel = try await restClient.getChannel(id: configuration.welcomeChannelID)
        let leaveChannel = try await restClient.getChannel(id: configuration.leaveChannelID)
        let modLogChannel = try await restClient.getChannel(id: configuration.modLogChannelID)

        for channel in [welcomeChannel, leaveChannel, modLogChannel] {
            let permissions = PermissionCalculator.channelPermissions(
                member: botMember,
                roles: roles,
                overwrites: channel.permissionOverwrites ?? [],
                everyoneID: configuration.guildID
            )

            if !permissions.contains(.viewChannel) {
                issues.append(.init(severity: .blocking, message: "The bot cannot view channel \(channel.name ?? channel.id)."))
            }

            if !permissions.contains(.sendMessages) {
                issues.append(.init(severity: .blocking, message: "The bot cannot send messages in channel \(channel.name ?? channel.id)."))
            }
        }

        issues.append(.init(severity: .info, message: "Connected to guild `\(guild.name)` as `\(me.displayName)`."))        

        return PermissionReport(issues: issues)
    }
}

enum PermissionCalculator {
    static func guildPermissions(memberRoleIDs: [DiscordSnowflake], roles: [DiscordRole]) -> PermissionSet {
        let raw = roles
            .filter { memberRoleIDs.contains($0.id) }
            .reduce(UInt64(0)) { partial, role in
                partial | (UInt64(role.permissions) ?? 0)
            }
        return PermissionSet(rawValue: raw)
    }

    static func channelPermissions(member: DiscordMember, roles: [DiscordRole], overwrites: [DiscordPermissionOverwrite], everyoneID: String) -> PermissionSet {
        var permissions = guildPermissions(memberRoleIDs: member.roles, roles: roles)
        if permissions.contains(.administrator) {
            return permissions
        }

        if let everyone = overwrites.first(where: { $0.id == everyoneID && $0.type == 0 }) {
            permissions.remove(PermissionSet(rawValue: UInt64(everyone.deny) ?? 0))
            permissions.formUnion(PermissionSet(rawValue: UInt64(everyone.allow) ?? 0))
        }

        let roleOverwrites = overwrites.filter { $0.type == 0 && member.roles.contains($0.id) }
        let denied = roleOverwrites.reduce(UInt64(0)) { $0 | (UInt64($1.deny) ?? 0) }
        let allowed = roleOverwrites.reduce(UInt64(0)) { $0 | (UInt64($1.allow) ?? 0) }
        permissions.remove(PermissionSet(rawValue: denied))
        permissions.formUnion(PermissionSet(rawValue: allowed))

        if let memberOverwrite = overwrites.first(where: { $0.type == 1 && $0.id == member.user?.id }) {
            permissions.remove(PermissionSet(rawValue: UInt64(memberOverwrite.deny) ?? 0))
            permissions.formUnion(PermissionSet(rawValue: UInt64(memberOverwrite.allow) ?? 0))
        }

        return permissions
    }
}

struct PermissionSet: OptionSet, Sendable {
    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static let viewChannel = PermissionSet(rawValue: DiscordPermission.viewChannel.rawValue)
    static let sendMessages = PermissionSet(rawValue: DiscordPermission.sendMessages.rawValue)
    static let manageRoles = PermissionSet(rawValue: DiscordPermission.manageRoles.rawValue)
    static let viewAuditLog = PermissionSet(rawValue: DiscordPermission.viewAuditLog.rawValue)
    static let administrator = PermissionSet(rawValue: DiscordPermission.administrator.rawValue)
}

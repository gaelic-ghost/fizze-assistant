import Foundation
import Logging

struct PermissionReport: Sendable {
    struct Issue: Hashable, Sendable {
        enum Severity: String, Sendable {
            case info = "INFO"
            case warning = "WARN"
        }

        var severity: Severity
        var message: String
    }

    var issues: [Issue]

    func renderText() -> String {
        let warningCount = issues.filter { $0.severity == .warning }.count
        let statusLine = if warningCount == 0 {
            "Startup looks good."
        } else {
            "Startup can continue. The warnings below can be fixed from Discord whenever you're ready."
        }
        let lines = issues.map { "[\($0.severity.rawValue)] \($0.message)" }
        return (["Fizze Assistant setup report:", statusLine] + lines).joined(separator: "\n")
    }
}

struct PermissionReportBuilder {
    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let logger: Logger

    func build() async throws -> PermissionReport {
        var issues: [PermissionReport.Issue] = [
            .init(severity: .info, message: "Before full use, enable `Server Members Intent` and `Message Content Intent` in the Discord Developer Portal."),
        ]

        let me = try await restClient.getCurrentUser()
        let guild = try await restClient.getGuild(id: configuration.guild_id)
        let botMember = try await restClient.getGuildMember(guild_id: configuration.guild_id, user_id: me.id)
        let roles = try await restClient.getGuildRoles(guild_id: configuration.guild_id)

        let guildPermissions = PermissionCalculator.guildPermissions(memberRoleIDs: botMember.roles, roles: roles)
        let topRolePosition = roles
            .filter { botMember.roles.contains($0.id) }
            .map(\.position)
            .max() ?? 0

        if !guildPermissions.contains(.manageRoles) {
            issues.append(.init(severity: .warning, message: "Auto-role assignment is unavailable until the bot has `Manage Roles`."))
        }

        if !guildPermissions.contains(.viewAuditLog) {
            issues.append(.init(severity: .warning, message: "Leave versus kick or ban detection is unavailable until the bot has `View Audit Log`."))
        }

        if roles.first(where: { $0.id == configuration.default_member_role_id }) == nil {
            issues.append(.init(severity: .warning, message: "Auto-role assignment is unavailable until the configured default member role exists in the server."))
        } else if let defaultRole = roles.first(where: { $0.id == configuration.default_member_role_id }), defaultRole.position >= topRolePosition {
            issues.append(.init(severity: .warning, message: "Auto-role assignment is paused until the bot role is moved above the default member role in the server role list."))
        }

        for roleID in configuration.allowed_staff_role_ids where roles.first(where: { $0.id == roleID }) == nil {
            issues.append(.init(severity: .warning, message: "Configured staff role ID \(roleID) is not currently present in the server."))
        }

        for roleID in configuration.allowed_config_role_ids where roles.first(where: { $0.id == roleID }) == nil {
            issues.append(.init(severity: .warning, message: "Configured config-owner role ID \(roleID) is not currently present in the server."))
        }

        let configuredChannels: [(String, String?)] = [
            ("welcome", configuration.welcome_channel_id),
            ("leave", configuration.leave_channel_id),
            ("mod-log", configuration.mod_log_channel_id),
        ]

        var reportedChannelWarnings = Set<String>()
        for (label, id) in configuredChannels {
            guard let id else {
                issues.append(.init(severity: .warning, message: "No \(label) channel is configured yet, so that announcement feature will stay off for now."))
                continue
            }

            let channel = try await restClient.getChannel(id: id)
            let permissions = PermissionCalculator.channelPermissions(
                member: botMember,
                roles: roles,
                overwrites: channel.permission_overwrites ?? [],
                everyoneID: configuration.guild_id
            )

            if !permissions.contains(.viewChannel) {
                let key = "view:\(channel.id)"
                if reportedChannelWarnings.insert(key).inserted {
                    issues.append(.init(severity: .warning, message: "The bot can't view channel \(channel.name ?? channel.id) yet, so any features routed there will stay paused until that permission is allowed."))
                }
            }

            if !permissions.contains(.sendMessages) {
                let key = "send:\(channel.id)"
                if reportedChannelWarnings.insert(key).inserted {
                    issues.append(.init(severity: .warning, message: "The bot can't send messages in channel \(channel.name ?? channel.id) yet, so any configured posts there will stay paused until that permission is allowed."))
                }
            }
        }

        issues.append(.init(severity: .info, message: "Connected to guild `\(guild.name)` as `\(me.displayName)`."))
        issues.append(.init(severity: .info, message: "Invite URL: \(configuration.install_url)"))
        issues.append(.init(severity: .info, message: "Permission integer: \(AppConfiguration.required_permission_integer) (`View Channel`, `Send Messages`, `Manage Roles`, `View Audit Log`)."))

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
    static let manageGuild = PermissionSet(rawValue: DiscordPermission.manageGuild.rawValue)
    static let manageRoles = PermissionSet(rawValue: DiscordPermission.manageRoles.rawValue)
    static let viewAuditLog = PermissionSet(rawValue: DiscordPermission.viewAuditLog.rawValue)
    static let administrator = PermissionSet(rawValue: DiscordPermission.administrator.rawValue)
}

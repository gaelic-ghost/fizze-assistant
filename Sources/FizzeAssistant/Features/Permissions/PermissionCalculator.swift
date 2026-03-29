import Foundation

enum PermissionCalculator {
    // MARK: Permission Calculation

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
    // MARK: Stored Properties

    let rawValue: UInt64

    // MARK: Lifecycle

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    // MARK: Flags

    static let viewChannel = PermissionSet(rawValue: DiscordPermission.viewChannel.rawValue)
    static let sendMessages = PermissionSet(rawValue: DiscordPermission.sendMessages.rawValue)
    static let manageGuild = PermissionSet(rawValue: DiscordPermission.manageGuild.rawValue)
    static let manageRoles = PermissionSet(rawValue: DiscordPermission.manageRoles.rawValue)
    static let viewAuditLog = PermissionSet(rawValue: DiscordPermission.viewAuditLog.rawValue)
    static let administrator = PermissionSet(rawValue: DiscordPermission.administrator.rawValue)
}

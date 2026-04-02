import Foundation

extension DiscordInteractionRouter {
    // MARK: Authorization

    func ensureStaffAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isStaffAuthorized(for: configuration) == true else {
            throw UserFacingError("DiscordInteractionRouter.ensureStaffAuthorized: this command is limited to configured staff roles, or members with Discord `Administrator` or `Manage Server` permissions. The most likely cause is that your server roles do not match `allowed_staff_role_ids` in the active JSON config file yet.")
        }
    }

    func ensureConfigAuthorized(member: DiscordInteractionMember?, configuration: AppConfiguration) throws {
        guard member?.isConfigAuthorized(for: configuration) == true else {
            throw UserFacingError("DiscordInteractionRouter.ensureConfigAuthorized: `/config` and other owner-only bot controls are limited to the explicitly configured config-owner roles in `allowed_config_role_ids`. The most likely cause is that your Discord roles do not include the owner role ID expected by the active JSON config file.")
        }
    }
}

extension DiscordInteractionMember {
    // MARK: Authorization Checks

    func isStaffAuthorized(for configuration: AppConfiguration) -> Bool {
        hasServerManagementPrivileges || !Set(roles).isDisjoint(with: configuration.allowed_staff_role_ids)
    }

    func isConfigAuthorized(for configuration: AppConfiguration) -> Bool {
        !Set(roles).isDisjoint(with: configuration.allowed_config_role_ids)
    }

    var hasServerManagementPrivileges: Bool {
        let permissions = permissionSet
        return permissions.contains(.administrator) || permissions.contains(.manageGuild)
    }
}

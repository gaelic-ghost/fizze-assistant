import Foundation
import Logging

struct PermissionReportBuilder {
    // MARK: Nested Types

    private struct ChannelPermissionProbe {
        let label: String
        let id: String
        let isConfiguredFeatureChannel: Bool
        let reportsSuccessfulSend: Bool
    }

    // MARK: Stored Properties

    private static let startupPostingProbeChannels: [ChannelPermissionProbe] = [
        .init(
            label: "manual posting check",
            id: "1493200053852966952",
            isConfiguredFeatureChannel: false,
            reportsSuccessfulSend: true
        ),
    ]

    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let logger: Logger

    // MARK: Public API

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

        let configuredChannels: [ChannelPermissionProbe] = [
            .init(label: "welcome", id: configuration.welcome_channel_id ?? "", isConfiguredFeatureChannel: true, reportsSuccessfulSend: false),
            .init(label: "leave", id: configuration.leave_channel_id ?? "", isConfiguredFeatureChannel: true, reportsSuccessfulSend: false),
            .init(label: "mod-log", id: configuration.mod_log_channel_id ?? "", isConfiguredFeatureChannel: true, reportsSuccessfulSend: false),
        ]

        var reportedChannelWarnings = Set<String>()
        for probe in configuredChannels + Self.startupPostingProbeChannels {
            guard !probe.id.isEmpty else {
                if probe.isConfiguredFeatureChannel {
                    issues.append(.init(severity: .warning, message: "No \(probe.label) channel is configured yet, so that announcement feature will stay off for now."))
                }
                continue
            }

            let channel: DiscordChannel
            do {
                channel = try await restClient.getChannel(id: probe.id)
            } catch {
                let key = "inspect:\(probe.id)"
                guard reportedChannelWarnings.insert(key).inserted else {
                    continue
                }

                issues.append(.init(severity: .warning, message: "PermissionReportBuilder.build: the bot could not inspect \(probe.label) channel `\(probe.id)`, so startup cannot confirm whether it can post there yet. The most likely cause is that the channel ID is wrong, the bot does not have `View Channel`, or Discord denied the lookup. Underlying error: \(Self.describe(error))"))
                continue
            }

            let permissions = PermissionCalculator.channelPermissions(
                member: botMember,
                roles: roles,
                overwrites: channel.permission_overwrites ?? [],
                everyoneID: configuration.guild_id
            )

            if !permissions.contains(.viewChannel) {
                let key = "view:\(channel.id)"
                if reportedChannelWarnings.insert(key).inserted {
                    issues.append(.init(severity: .warning, message: "PermissionReportBuilder.build: the bot does not have `View Channel` for \(channel.name ?? channel.id), so any feature routed there will stay paused until that Discord permission is allowed. The most likely cause is a channel override or category override in the server."))
                }
            }

            if !permissions.contains(.sendMessages) {
                let key = "send:\(channel.id)"
                if reportedChannelWarnings.insert(key).inserted {
                    issues.append(.init(severity: .warning, message: "PermissionReportBuilder.build: the bot does not have `Send Messages` for \(channel.name ?? channel.id), so configured posts there will stay paused until that Discord permission is allowed. The most likely cause is a channel override or category override in the server."))
                }
                continue
            }

            if probe.reportsSuccessfulSend {
                issues.append(.init(severity: .info, message: "PermissionReportBuilder.build: the bot can currently post in \(channel.name ?? channel.id) (`\(channel.id)`)."))
            }
        }

        issues.append(.init(severity: .info, message: "Connected to guild `\(guild.name)` as `\(me.displayName)`."))
        issues.append(.init(severity: .info, message: "Invite URL: \(configuration.install_url)"))
        issues.append(.init(severity: .info, message: "Permission integer: \(AppConfiguration.required_permission_integer) (`View Channel`, `Send Messages`, `Manage Roles`, `View Audit Log`)."))

        return PermissionReport(issues: issues)
    }

    // MARK: Private Helpers

    private static func describe(_ error: Error) -> String {
        if let localized = (error as? LocalizedError)?.errorDescription {
            return localized
        }

        return String(describing: error)
    }
}

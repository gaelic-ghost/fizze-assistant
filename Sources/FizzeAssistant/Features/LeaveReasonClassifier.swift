import Foundation

actor ModerationEventCache {
    private var banEvents: [String: Date] = [:]

    func recordBan(for user_id: String, at date: Date = Date()) {
        banEvents[user_id] = date
    }

    func recentBan(for user_id: String, within seconds: TimeInterval, now: Date = Date()) -> Bool {
        guard let date = banEvents[user_id] else {
            return false
        }

        return now.timeIntervalSince(date) <= seconds
    }
}

enum LeaveReason: String, Sendable {
    case voluntary
    case kicked
    case banned
    case unknown
}

struct LeaveReasonClassifier {
    let restClient: DiscordRESTClient
    let configuration: AppConfiguration
    let banCache: ModerationEventCache

    func classify(user_id: String, now: Date = Date()) async throws -> LeaveReason {
        if await banCache.recentBan(for: user_id, within: configuration.leave_audit_log_lookback_seconds, now: now) {
            return .banned
        }

        let kicks = try await restClient.getAuditLogEntries(
            guild_id: configuration.guild_id,
            action_type: DiscordAuditLogActionType.memberKick
        )
        if kicks.contains(where: { $0.target_id == user_id }) {
            return .kicked
        }

        let bans = try await restClient.getAuditLogEntries(
            guild_id: configuration.guild_id,
            action_type: DiscordAuditLogActionType.memberBanAdd
        )
        if bans.contains(where: { $0.target_id == user_id }) {
            return .banned
        }

        return .voluntary
    }
}

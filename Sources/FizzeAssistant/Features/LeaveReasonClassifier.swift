import Foundation

actor ModerationEventCache {
    private var banEvents: [String: Date] = [:]

    func recordBan(for userID: String, at date: Date = Date()) {
        banEvents[userID] = date
    }

    func recentBan(for userID: String, within seconds: TimeInterval, now: Date = Date()) -> Bool {
        guard let date = banEvents[userID] else {
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

    func classify(userID: String, now: Date = Date()) async throws -> LeaveReason {
        if await banCache.recentBan(for: userID, within: configuration.leaveAuditLogLookbackSeconds, now: now) {
            return .banned
        }

        let kicks = try await restClient.getAuditLogEntries(
            guildID: configuration.guildID,
            actionType: DiscordAuditLogActionType.memberKick
        )
        if kicks.contains(where: { $0.targetID == userID }) {
            return .kicked
        }

        let bans = try await restClient.getAuditLogEntries(
            guildID: configuration.guildID,
            actionType: DiscordAuditLogActionType.memberBanAdd
        )
        if bans.contains(where: { $0.targetID == userID }) {
            return .banned
        }

        return .voluntary
    }
}

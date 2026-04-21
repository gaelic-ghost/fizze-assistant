import Foundation

actor ResponseCooldownGate {
    enum MentionBurstDecision {
        case sendStandardReply
        case sendCooldownNotice
        case suppress
    }

    // MARK: Stored Properties

    private var fireDates: [String: [Date]] = [:]

    // MARK: Public API

    func allowsResponse(for trigger: String, cooldown: TimeInterval, now: Date = Date()) -> Bool {
        let key = trigger.lowercased()
        let recentDates = prunedDates(for: key, cooldown: cooldown, now: now)
        guard recentDates.isEmpty else {
            return false
        }

        fireDates[key] = [now]
        return true
    }

    func mentionBurstDecision(
        for key: String,
        cooldown: TimeInterval,
        now: Date = Date()
    ) -> MentionBurstDecision {
        let normalizedKey = key.lowercased()
        let recentDates = prunedDates(for: normalizedKey, cooldown: cooldown, now: now)

        switch recentDates.count {
        case 0, 1:
            fireDates[normalizedKey] = recentDates + [now]
            return .sendStandardReply
        case 2:
            fireDates[normalizedKey] = recentDates + [now]
            return .sendCooldownNotice
        default:
            fireDates[normalizedKey] = recentDates
            return .suppress
        }
    }

    // MARK: Private Helpers

    private func prunedDates(for key: String, cooldown: TimeInterval, now: Date) -> [Date] {
        let normalizedKey = key.lowercased()
        let dates = fireDates[normalizedKey] ?? []
        let recentDates = dates.filter { now.timeIntervalSince($0) < cooldown }
        fireDates[normalizedKey] = recentDates
        return recentDates
    }
}

struct IconicResponseEngine {
    // MARK: Stored Properties

    let messagesByTrigger: [String: IconicMessageConfiguration]
    let cooldownGate: ResponseCooldownGate
    let cooldown: TimeInterval
    let matchingMode: IconicTriggerMatchingMode

    // MARK: Public API

    func matchedResponse(for content: String) -> (trigger: String, response: IconicMessageConfiguration)? {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let matchedTrigger = matchingTrigger(for: normalized),
              let match = messagesByTrigger[matchedTrigger]
        else {
            return nil
        }

        return (matchedTrigger, match)
    }

    func response(
        for content: String,
        cooldownKey: String? = nil
    ) async -> IconicMessageConfiguration? {
        guard let matched = matchedResponse(for: content)
        else {
            return nil
        }

        let effectiveCooldownKey = cooldownKey ?? matched.trigger
        guard await cooldownGate.allowsResponse(for: effectiveCooldownKey, cooldown: cooldown) else {
            return nil
        }

        return matched.response
    }

    // MARK: Private Helpers

    private func matchingTrigger(for normalizedContent: String) -> String? {
        switch matchingMode {
        case .exact:
            return messagesByTrigger[normalizedContent] == nil ? nil : normalizedContent
        case .fuzze:
            return messagesByTrigger.keys
                .filter { normalizedContent.contains($0) }
                .max { lhs, rhs in
                    if lhs.count == rhs.count {
                        return lhs > rhs
                    }
                    return lhs.count < rhs.count
                }
        }
    }
}

import Foundation

actor TriggerCooldownStore {
    // MARK: Stored Properties

    private var fireDates: [String: Date] = [:]

    // MARK: Public API

    func canFire(trigger: String, cooldown: TimeInterval, now: Date = Date()) -> Bool {
        let key = trigger.lowercased()
        if let lastDate = fireDates[key], now.timeIntervalSince(lastDate) < cooldown {
            return false
        }

        fireDates[key] = now
        return true
    }
}

struct IconicResponseEngine {
    // MARK: Stored Properties

    let messagesByTrigger: [String: IconicMessageConfiguration]
    let cooldownStore: TriggerCooldownStore
    let cooldown: TimeInterval
    let matchingMode: IconicTriggerMatchingMode

    // MARK: Public API

    func response(for content: String) async -> IconicMessageConfiguration? {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let matchedTrigger = matchingTrigger(for: normalized),
              let match = messagesByTrigger[matchedTrigger]
        else {
            return nil
        }

        guard await cooldownStore.canFire(trigger: matchedTrigger, cooldown: cooldown) else {
            return nil
        }

        return match
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

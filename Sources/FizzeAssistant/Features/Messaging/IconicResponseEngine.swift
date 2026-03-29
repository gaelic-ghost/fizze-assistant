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

    let triggers: [IconicTriggerConfiguration]
    let cooldownStore: TriggerCooldownStore
    let cooldown: TimeInterval

    // MARK: Public API

    func response(for content: String) async -> String? {
        let normalized = content.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let match = triggers.first(where: { $0.trigger.lowercased() == normalized }) else {
            return nil
        }

        guard await cooldownStore.canFire(trigger: match.trigger, cooldown: cooldown) else {
            return nil
        }

        return match.response
    }
}

import Foundation

struct IconicWizardDraft: Sendable {
    // MARK: Stored Properties

    var trigger: String
    var userID: DiscordSnowflake
    var createdAt: Date
}

actor IconicWizardStateStore {
    // MARK: Stored Properties

    private var draftsBySessionID: [String: IconicWizardDraft] = [:]
    private let lifetime: TimeInterval = 15 * 60

    // MARK: Public API

    func save(trigger: String, userID: DiscordSnowflake, now: Date = Date()) -> String {
        purgeExpiredDrafts(now: now)

        let sessionID = UUID().uuidString.lowercased()
        draftsBySessionID[sessionID] = IconicWizardDraft(trigger: trigger, userID: userID, createdAt: now)
        return sessionID
    }

    func draft(sessionID: String, userID: DiscordSnowflake, now: Date = Date()) throws -> IconicWizardDraft {
        purgeExpiredDrafts(now: now)

        guard let draft = draftsBySessionID[sessionID] else {
            throw UserFacingError("IconicWizardStateStore.draft: this `this-is-iconic` draft has expired or is missing, so the bot cannot continue the wizard. The most likely cause is that too much time passed between steps; start `/this-is-iconic` again.")
        }

        guard draft.userID == userID else {
            throw UserFacingError("IconicWizardStateStore.draft: only the person who started this `this-is-iconic` draft can continue it. The most likely cause is that someone else clicked the button for a private wizard step.")
        }

        return draft
    }

    func remove(sessionID: String) {
        draftsBySessionID.removeValue(forKey: sessionID)
    }

    // MARK: Private Helpers

    private func purgeExpiredDrafts(now: Date) {
        draftsBySessionID = draftsBySessionID.filter { _, draft in
            now.timeIntervalSince(draft.createdAt) < lifetime
        }
    }
}

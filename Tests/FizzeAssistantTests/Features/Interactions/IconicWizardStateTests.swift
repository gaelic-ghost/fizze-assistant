import Foundation
import Testing
@testable import FizzeAssistant

struct IconicWizardStateTests {
    @Test
    func savedDraftCanBeLoadedBySameUser() async throws {
        let store = IconicWizardStateStore()
        let sessionID = await store.save(trigger: "fizze time", userID: "user-1")

        let draft = try await store.draft(sessionID: sessionID, userID: "user-1")
        #expect(draft.trigger == "fizze time")
        #expect(draft.userID == "user-1")
    }

    @Test
    func draftRequiresSameUser() async throws {
        let store = IconicWizardStateStore()
        let sessionID = await store.save(trigger: "fizze time", userID: "user-1")

        await #expect(throws: UserFacingError.self) {
            _ = try await store.draft(sessionID: sessionID, userID: "user-2")
        }
    }

    @Test
    func expiredDraftIsPurgedOnLookup() async throws {
        let store = IconicWizardStateStore()
        let createdAt = Date(timeIntervalSince1970: 0)
        let sessionID = await store.save(trigger: "fizze time", userID: "user-1", now: createdAt)

        await #expect(throws: UserFacingError.self) {
            _ = try await store.draft(
                sessionID: sessionID,
                userID: "user-1",
                now: createdAt.addingTimeInterval((15 * 60) + 1)
            )
        }
    }

    @Test
    func removeDeletesDraft() async throws {
        let store = IconicWizardStateStore()
        let sessionID = await store.save(trigger: "fizze time", userID: "user-1")

        await store.remove(sessionID: sessionID)

        await #expect(throws: UserFacingError.self) {
            _ = try await store.draft(sessionID: sessionID, userID: "user-1")
        }
    }
}

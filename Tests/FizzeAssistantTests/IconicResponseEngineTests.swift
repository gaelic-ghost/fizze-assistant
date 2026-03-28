import Foundation
import Testing
@testable import FizzeAssistant

struct IconicResponseEngineTests {
    @Test
    func exactMatchIsCaseInsensitive() async {
        let engine = IconicResponseEngine(
            triggers: [
                IconicTriggerConfiguration(trigger: "fizze time", response: "sparkle"),
            ],
            cooldownStore: TriggerCooldownStore(),
            cooldown: 30
        )

        let response = await engine.response(for: "  FIZZE TIME ")
        #expect(response == "sparkle")
    }

    @Test
    func cooldownBlocksSecondImmediateResponse() async {
        let store = TriggerCooldownStore()
        let engine = IconicResponseEngine(
            triggers: [
                IconicTriggerConfiguration(trigger: "fizze time", response: "sparkle"),
            ],
            cooldownStore: store,
            cooldown: 30
        )

        _ = await engine.response(for: "fizze time")
        let second = await engine.response(for: "fizze time")
        #expect(second == nil)
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct IconicResponseEngineTests {
    // MARK: Tests

    @Test
    func exactMatchIsCaseInsensitive() async {
        let engine = IconicResponseEngine(
            messagesByTrigger: [
                "fizze time": IconicMessageConfiguration(content: "sparkle", embeds: nil),
            ],
            cooldownStore: TriggerCooldownStore(),
            cooldown: 30,
            matchingMode: .exact
        )

        let response = await engine.response(for: "  FIZZE TIME ")
        #expect(response?.content == "sparkle")
    }

    @Test
    func cooldownBlocksSecondImmediateResponse() async {
        let store = TriggerCooldownStore()
        let engine = IconicResponseEngine(
            messagesByTrigger: [
                "fizze time": IconicMessageConfiguration(content: "sparkle", embeds: nil),
            ],
            cooldownStore: store,
            cooldown: 30,
            matchingMode: .exact
        )

        _ = await engine.response(for: "fizze time")
        let second = await engine.response(for: "fizze time")
        #expect(second == nil)
    }

    @Test
    func embedOnlyMessageCanMatch() async {
        let engine = IconicResponseEngine(
            messagesByTrigger: [
                "fizze card": IconicMessageConfiguration(
                    content: nil,
                    embeds: [
                        DiscordEmbed(
                            title: "Fizze",
                            type: nil,
                            description: "Card",
                            url: nil,
                            color: 123,
                            footer: nil,
                            image: nil
                        ),
                    ]
                ),
            ],
            cooldownStore: TriggerCooldownStore(),
            cooldown: 30,
            matchingMode: .exact
        )

        let response = await engine.response(for: "fizze card")
        #expect(response?.content == nil)
        #expect(response?.embeds?.count == 1)
    }

    @Test
    func fuzzeModeMatchesSubstringUsingLongestTrigger() async {
        let engine = IconicResponseEngine(
            messagesByTrigger: [
                "fizze": IconicMessageConfiguration(content: "base", embeds: nil),
                "fizze time": IconicMessageConfiguration(content: "longest", embeds: nil),
            ],
            cooldownStore: TriggerCooldownStore(),
            cooldown: 30,
            matchingMode: .fuzze
        )

        let response = await engine.response(for: "wow fizze time right now")
        #expect(response?.content == "longest")
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordInteractionComponentParsingTests {
    @Test
    func requireComponentValueFindsNestedTextInputValue() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let router = try await makeRouter(rootURL: rootURL, restClient: DiscordRESTClient(token: "token", logger: .init(label: "test")))
        let components = [
            DiscordComponent(
                type: DiscordComponentType.actionRow,
                components: [
                    DiscordComponent(
                        type: DiscordComponentType.textInput,
                        components: nil,
                        custom_id: "field-1",
                        style: DiscordTextInputStyle.short,
                        label: nil,
                        title: nil,
                        description: nil,
                        value: "sparkle",
                        url: nil,
                        placeholder: nil,
                        required: nil,
                        min_length: nil,
                        max_length: nil
                    ),
                ],
                custom_id: nil,
                style: nil,
                label: nil,
                title: nil,
                description: nil,
                value: nil,
                url: nil,
                placeholder: nil,
                required: nil,
                min_length: nil,
                max_length: nil
            ),
        ]

        let value = try await router.requireComponentValue(customID: "field-1", from: components, interactionName: "wizard")
        #expect(value == "sparkle")
    }

    @Test
    func requireComponentValueThrowsForMissingField() async throws {
        let rootURL = try makeTemporaryTestDirectory()
        let router = try await makeRouter(rootURL: rootURL, restClient: DiscordRESTClient(token: "token", logger: .init(label: "test")))

        await #expect(throws: UserFacingError.self) {
            _ = try await router.requireComponentValue(customID: "missing", from: nil, interactionName: "wizard")
        }
    }
}

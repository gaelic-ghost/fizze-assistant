import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordInteractionOptionParsingTests {
    // MARK: Tests

    @Test
    func stringValueRequiredTurnsWholeNumbersIntoStrings() throws {
        let value = JSONValue.number(42)
        let rendered = try value.stringValueRequired(commandName: "config set", optionName: "value")
        #expect(rendered == "42")
    }

    @Test
    func stringValueRequiredRejectsBooleanValues() {
        #expect(throws: UserFacingError.self) {
            _ = try JSONValue.bool(true).stringValueRequired(commandName: "config set", optionName: "value")
        }
    }
}

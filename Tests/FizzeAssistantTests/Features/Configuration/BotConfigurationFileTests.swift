import Foundation
import Testing
@testable import FizzeAssistant

struct BotConfigurationFileTests {
    // MARK: Tests

    @Test
    func warningsMentionMissingOptionalChannels() {
        let configuration = BotConfigurationFile.defaults
        #expect(configuration.warnings.contains("Welcome channel is not configured yet. New-member welcome messages will be skipped."))
        #expect(configuration.warnings.contains("No config owner role IDs are configured yet."))
    }

    @Test
    func prettyPrintedJSONIncludesMatchingModeField() throws {
        let json = try BotConfigurationFile.defaults.prettyPrintedJSON()
        #expect(json.contains("\"trigger_matching_mode\""))
        #expect(json.contains("\"exact\""))
    }
}

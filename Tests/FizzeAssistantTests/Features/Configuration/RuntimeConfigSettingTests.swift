import Foundation
import Testing
@testable import FizzeAssistant

struct RuntimeConfigSettingTests {
    // MARK: Tests

    @Test
    func allowedKeysTextIncludesTriggerMatchingMode() {
        #expect(RuntimeConfigSetting.allowedKeysText.contains("trigger_matching_mode"))
    }
}

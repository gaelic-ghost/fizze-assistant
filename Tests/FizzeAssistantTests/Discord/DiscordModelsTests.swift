import Foundation
import Testing
@testable import FizzeAssistant

struct DiscordModelsTests {
    // MARK: Tests

    @Test
    func modalInteractionDecodesCustomIDAndComponents() throws {
        let data = """
        {
          "id": "interaction-1",
          "application_id": "app-1",
          "type": 5,
          "token": "token-1",
          "member": {
            "roles": ["config-role"],
            "permissions": "0"
          },
          "data": {
            "custom_id": "this-is-iconic:trigger-modal",
            "components": [
              {
                "type": 1,
                "components": [
                  {
                    "type": 4,
                    "custom_id": "this-is-iconic:trigger",
                    "value": "fizze time"
                  }
                ]
              }
            ]
          }
        }
        """.data(using: .utf8)!

        let interaction = try JSONDecoder().decode(DiscordInteraction.self, from: data)

        #expect(interaction.type == DiscordInteractionType.modalSubmit)
        #expect(interaction.data?.custom_id == "this-is-iconic:trigger-modal")
        #expect(interaction.data?.components?.first?.components?.first?.value == "fizze time")
    }
}

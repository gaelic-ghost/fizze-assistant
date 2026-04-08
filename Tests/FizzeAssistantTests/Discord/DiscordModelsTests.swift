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

    @Test
    func interactionDataIDDecodesWhenDiscordSendsANumber() throws {
        let data = """
        {
          "id": "interaction-1",
          "application_id": "app-1",
          "type": 2,
          "token": "token-1",
          "member": {
            "roles": ["config-role"],
            "permissions": "0"
          },
          "data": {
            "id": 1487254261594325000,
            "name": "this-is-iconic"
          }
        }
        """.data(using: .utf8)!

        let interaction = try JSONDecoder().decode(DiscordInteraction.self, from: data)

        #expect(interaction.data?.id == "1487254261594325000")
        #expect(interaction.data?.name == "this-is-iconic")
    }

    @Test
    func interactionDataIDRejectsFractionalNumbers() {
        let data = """
        {
          "id": "interaction-1",
          "application_id": "app-1",
          "type": 2,
          "token": "token-1",
          "member": {
            "roles": ["config-role"],
            "permissions": "0"
          },
          "data": {
            "id": 1487254261594325.5,
            "name": "this-is-iconic"
          }
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DiscordInteraction.self, from: data)
        }
    }
}

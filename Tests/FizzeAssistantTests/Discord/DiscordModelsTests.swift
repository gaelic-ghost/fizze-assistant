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

    @Test
    func interactionTopLevelAndMemberSnowflakesDecodeWhenDiscordSendsNumbers() throws {
        let data = """
        {
          "id": 1487254261594325001,
          "application_id": 1487254261594325002,
          "type": 2,
          "token": "token-1",
          "channel_id": 1487254261594325003,
          "member": {
            "user": {
              "id": 1487254261594325004,
              "username": "gale",
              "global_name": "Gale"
            },
            "roles": [1487254261594325005, "1487254261594325006"],
            "permissions": "0"
          },
          "data": {
            "id": 1487254261594325007,
            "name": "this-is-iconic"
          }
        }
        """.data(using: .utf8)!

        let interaction = try JSONDecoder().decode(DiscordInteraction.self, from: data)

        #expect(interaction.id == "1487254261594325001")
        #expect(interaction.application_id == "1487254261594325002")
        #expect(interaction.channel_id == "1487254261594325003")
        #expect(interaction.member?.user?.id == "1487254261594325004")
        #expect(interaction.member?.roles == ["1487254261594325005", "1487254261594325006"])
        #expect(interaction.data?.id == "1487254261594325007")
    }

    @Test
    func messageEventSnowflakesDecodeWhenDiscordSendsNumbers() throws {
        let data = """
        {
          "id": 1487254261594325101,
          "channel_id": 1487254261594325102,
          "guild_id": 1487254261594325103,
          "content": "fizze",
          "author": {
            "id": 1487254261594325104,
            "username": "gale",
            "global_name": "Gale"
          },
          "webhook_id": 1487254261594325105
        }
        """.data(using: .utf8)!

        let event = try JSONDecoder().decode(DiscordMessageEvent.self, from: data)

        #expect(event.id == "1487254261594325101")
        #expect(event.channel_id == "1487254261594325102")
        #expect(event.guild_id == "1487254261594325103")
        #expect(event.author.id == "1487254261594325104")
        #expect(event.webhook_id == "1487254261594325105")
    }

    @Test
    func snowflakeFieldsRejectFractionalNumbers() {
        let data = """
        {
          "id": 1487254261594325001.5,
          "application_id": "app-1",
          "type": 2,
          "token": "token-1",
          "member": {
            "roles": ["config-role"],
            "permissions": "0"
          },
          "data": {
            "name": "this-is-iconic"
          }
        }
        """.data(using: .utf8)!

        #expect(throws: DecodingError.self) {
            _ = try JSONDecoder().decode(DiscordInteraction.self, from: data)
        }
    }
}

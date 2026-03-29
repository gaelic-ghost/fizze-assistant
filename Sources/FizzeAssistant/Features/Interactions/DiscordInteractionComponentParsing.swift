import Foundation

extension DiscordInteractionRouter {
    // MARK: Component Parsing

    func requireComponentValue(
        customID: String,
        from components: [DiscordComponent]?,
        interactionName: String
    ) throws -> String {
        guard let value = componentValue(customID: customID, from: components) else {
            throw UserFacingError("DiscordInteractionRouter.requireComponentValue: `\(interactionName)` did not include the expected field `\(customID)`, so the bot cannot continue. The most likely cause is that the interaction payload shape from Discord changed or the modal response was submitted from an outdated client view.")
        }
        return value
    }

    // MARK: Private Helpers

    private func componentValue(customID: String, from components: [DiscordComponent]?) -> String? {
        guard let components else {
            return nil
        }

        for component in components {
            if component.custom_id == customID, let value = component.value {
                return value
            }

            if let nestedValue = componentValue(customID: customID, from: component.components) {
                return nestedValue
            }
        }

        return nil
    }
}

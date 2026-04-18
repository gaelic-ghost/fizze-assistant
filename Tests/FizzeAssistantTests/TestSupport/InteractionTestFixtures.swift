import Foundation
@testable import FizzeAssistant

func slashInteraction(
    id: String,
    name: String,
    memberRoles: [String],
    channelID: String = "source-channel",
    options: [DiscordInteractionOption]? = nil
) -> DiscordInteraction {
    DiscordInteraction(
        id: id,
        application_id: "app",
        type: DiscordInteractionType.applicationCommand,
        token: "token-\(id)",
        channel_id: channelID,
        member: DiscordInteractionMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: memberRoles,
            permissions: "0"
        ),
        data: DiscordInteractionData(id: "command-\(id)", name: name, custom_id: nil, component_type: nil, options: options, components: nil)
    )
}

func modalInteraction(
    id: String,
    customID: String,
    memberRoles: [String],
    fieldCustomID: String,
    value: String
) -> DiscordInteraction {
    modalInteraction(
        id: id,
        customID: customID,
        memberRoles: memberRoles,
        fields: [(fieldCustomID, value)]
    )
}

func modalInteraction(
    id: String,
    customID: String,
    memberRoles: [String],
    fields: [(customID: String, value: String)]
) -> DiscordInteraction {
    DiscordInteraction(
        id: id,
        application_id: "app",
        type: DiscordInteractionType.modalSubmit,
        token: "token-\(id)",
        channel_id: "source-channel",
        member: DiscordInteractionMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: memberRoles,
            permissions: "0"
        ),
        data: DiscordInteractionData(
            id: nil,
            name: nil,
            custom_id: customID,
            component_type: nil,
            options: nil,
            components: fields.map { field in
                DiscordComponent(
                    type: DiscordComponentType.actionRow,
                    components: [
                        DiscordComponent(
                            type: DiscordComponentType.textInput,
                            components: nil,
                            custom_id: field.customID,
                            style: DiscordTextInputStyle.short,
                            label: nil,
                            title: nil,
                            description: nil,
                            value: field.value,
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
                )
            }
        )
    )
}

func buttonInteraction(id: String, customID: String, memberRoles: [String]) -> DiscordInteraction {
    DiscordInteraction(
        id: id,
        application_id: "app",
        type: DiscordInteractionType.messageComponent,
        token: "token-\(id)",
        channel_id: "source-channel",
        member: DiscordInteractionMember(
            user: DiscordUser(id: "user-1", username: "gale", global_name: "Gale"),
            roles: memberRoles,
            permissions: "0"
        ),
        data: DiscordInteractionData(id: nil, name: nil, custom_id: customID, component_type: DiscordComponentType.button, options: nil, components: nil)
    )
}

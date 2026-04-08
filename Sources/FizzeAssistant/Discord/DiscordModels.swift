import Foundation

// MARK: - Core Discord Types

typealias DiscordSnowflake = String

struct DiscordUser: Codable, Sendable {
    var id: DiscordSnowflake
    var username: String
    var global_name: String?

    var displayName: String {
        global_name ?? username
    }

    init(id: DiscordSnowflake, username: String, global_name: String?) {
        self.id = id
        self.username = username
        self.global_name = global_name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeDiscordSnowflake(forKey: .id)
        username = try container.decode(String.self, forKey: .username)
        global_name = try container.decodeIfPresent(String.self, forKey: .global_name)
    }
}

// MARK: - Guild and Channel Models

struct DiscordRole: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String
    var permissions: String
    var position: Int
}

struct DiscordGuild: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String
    var owner_id: DiscordSnowflake?
}

struct DiscordChannel: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String?
    var type: Int
    var permission_overwrites: [DiscordPermissionOverwrite]?
}

struct DiscordPermissionOverwrite: Codable, Sendable {
    var id: DiscordSnowflake
    var type: Int
    var allow: String
    var deny: String
}

struct DiscordMember: Codable, Sendable {
    var user: DiscordUser?
    var roles: [DiscordSnowflake]
}

struct DiscordGatewayBotResponse: Codable, Sendable {
    var url: String
}

struct DiscordAuditLogResponse: Codable, Sendable {
    var audit_log_entries: [DiscordAuditLogEntry]
}

struct DiscordAuditLogEntry: Codable, Sendable {
    var id: DiscordSnowflake
    var action_type: Int
    var target_id: DiscordSnowflake?
    var user_id: DiscordSnowflake?
}

// MARK: - Slash Command Models

struct DiscordSlashCommand: Codable, Sendable {
    var name: String
    var description: String
    var type: Int = 1
    var options: [DiscordApplicationCommandOption]?
}

struct DiscordApplicationCommandOption: Codable, Sendable {
    var type: Int
    var name: String
    var description: String
    var required: Bool?
    var channel_types: [Int]?
    var options: [DiscordApplicationCommandOption]? = nil
}

// MARK: - Interaction Models

struct DiscordInteraction: Codable, Sendable {
    var id: DiscordSnowflake
    var application_id: DiscordSnowflake
    var type: Int
    var token: String
    var channel_id: DiscordSnowflake?
    var member: DiscordInteractionMember?
    var data: DiscordInteractionData?

    init(
        id: DiscordSnowflake,
        application_id: DiscordSnowflake,
        type: Int,
        token: String,
        channel_id: DiscordSnowflake?,
        member: DiscordInteractionMember?,
        data: DiscordInteractionData?
    ) {
        self.id = id
        self.application_id = application_id
        self.type = type
        self.token = token
        self.channel_id = channel_id
        self.member = member
        self.data = data
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeDiscordSnowflake(forKey: .id)
        application_id = try container.decodeDiscordSnowflake(forKey: .application_id)
        type = try container.decode(Int.self, forKey: .type)
        token = try container.decode(String.self, forKey: .token)
        channel_id = try container.decodeDiscordSnowflakeIfPresent(forKey: .channel_id)
        member = try container.decodeIfPresent(DiscordInteractionMember.self, forKey: .member)
        data = try container.decodeIfPresent(DiscordInteractionData.self, forKey: .data)
    }
}

struct DiscordInteractionMember: Codable, Sendable {
    var user: DiscordUser?
    var roles: [DiscordSnowflake]
    var permissions: String?

    var permissionSet: PermissionSet {
        PermissionSet(rawValue: UInt64(permissions ?? "") ?? 0)
    }

    init(user: DiscordUser?, roles: [DiscordSnowflake], permissions: String?) {
        self.user = user
        self.roles = roles
        self.permissions = permissions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user = try container.decodeIfPresent(DiscordUser.self, forKey: .user)
        roles = try container.decodeDiscordSnowflakeArray(forKey: .roles)
        permissions = try container.decodeIfPresent(String.self, forKey: .permissions)
    }
}

struct DiscordInteractionData: Codable, Sendable {
    var id: DiscordSnowflake?
    var name: String?
    var custom_id: String?
    var component_type: Int?
    var options: [DiscordInteractionOption]?
    var components: [DiscordComponent]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case custom_id
        case component_type
        case options
        case components
    }

    init(
        id: DiscordSnowflake?,
        name: String?,
        custom_id: String?,
        component_type: Int?,
        options: [DiscordInteractionOption]?,
        components: [DiscordComponent]?
    ) {
        self.id = id
        self.name = name
        self.custom_id = custom_id
        self.component_type = component_type
        self.options = options
        self.components = components
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeDiscordSnowflakeIfPresent(forKey: .id)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        custom_id = try container.decodeIfPresent(String.self, forKey: .custom_id)
        component_type = try container.decodeIfPresent(Int.self, forKey: .component_type)
        options = try container.decodeIfPresent([DiscordInteractionOption].self, forKey: .options)
        components = try container.decodeIfPresent([DiscordComponent].self, forKey: .components)
    }
}

struct DiscordInteractionOption: Codable, Sendable {
    var name: String
    var type: Int
    var value: JSONValue?
    var options: [DiscordInteractionOption]? = nil
}

struct DiscordMessageCreate: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var content: String?
    var embeds: [DiscordEmbed]?
    var components: [DiscordComponent]?
    var flags: Int?
}

struct DiscordMessage: Codable, Sendable {
    // MARK: Stored Properties

    var id: DiscordSnowflake
    var channel_id: DiscordSnowflake?
    var content: String
    var author: DiscordUser
    var embeds: [DiscordEmbed]?
    var flags: Int?

    init(
        id: DiscordSnowflake,
        channel_id: DiscordSnowflake?,
        content: String,
        author: DiscordUser,
        embeds: [DiscordEmbed]?,
        flags: Int?
    ) {
        self.id = id
        self.channel_id = channel_id
        self.content = content
        self.author = author
        self.embeds = embeds
        self.flags = flags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeDiscordSnowflake(forKey: .id)
        channel_id = try container.decodeDiscordSnowflakeIfPresent(forKey: .channel_id)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decode(DiscordUser.self, forKey: .author)
        embeds = try container.decodeIfPresent([DiscordEmbed].self, forKey: .embeds)
        flags = try container.decodeIfPresent(Int.self, forKey: .flags)
    }
}

struct DiscordEmbed: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var title: String?
    var type: String?
    var description: String?
    var url: String?
    var color: Int?
    var footer: DiscordEmbedFooter?
    var image: DiscordEmbedImage?
}

struct DiscordEmbedFooter: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var text: String
    var icon_url: String?
}

struct DiscordEmbedImage: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var url: String
    var height: Int?
    var width: Int?
}

struct DiscordCreateDMRequest: Codable, Sendable {
    var recipient_id: DiscordSnowflake
}

struct DiscordComponent: Codable, Hashable, Sendable {
    // MARK: Stored Properties

    var type: Int
    var components: [DiscordComponent]?
    var custom_id: String?
    var style: Int?
    var label: String?
    var title: String?
    var description: String?
    var value: String?
    var url: String?
    var placeholder: String?
    var required: Bool?
    var min_length: Int?
    var max_length: Int?
}

// MARK: - Gateway Event Models

struct DiscordGatewayEnvelope: Codable, Sendable {
    var op: Int
    var d: JSONValue?
    var s: Int?
    var t: String?
}

struct DiscordHello: Codable, Sendable {
    var heartbeat_interval: Int
}

struct DiscordGatewayReady: Codable, Sendable {
    var session_id: String
    var resume_gateway_url: String
}

struct DiscordGuildMemberAddEvent: Codable, Sendable {
    var user: DiscordUser
}

struct DiscordGuildMemberRemoveEvent: Codable, Sendable {
    var user: DiscordUser
}

struct DiscordGuildBanAddEvent: Codable, Sendable {
    var user: DiscordUser
}

struct DiscordMessageEvent: Codable, Sendable {
    var id: DiscordSnowflake
    var channel_id: DiscordSnowflake
    var guild_id: DiscordSnowflake?
    var content: String
    var author: DiscordUser
    var webhook_id: DiscordSnowflake?

    init(
        id: DiscordSnowflake,
        channel_id: DiscordSnowflake,
        guild_id: DiscordSnowflake?,
        content: String,
        author: DiscordUser,
        webhook_id: DiscordSnowflake?
    ) {
        self.id = id
        self.channel_id = channel_id
        self.guild_id = guild_id
        self.content = content
        self.author = author
        self.webhook_id = webhook_id
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeDiscordSnowflake(forKey: .id)
        channel_id = try container.decodeDiscordSnowflake(forKey: .channel_id)
        guild_id = try container.decodeDiscordSnowflakeIfPresent(forKey: .guild_id)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decode(DiscordUser.self, forKey: .author)
        webhook_id = try container.decodeDiscordSnowflakeIfPresent(forKey: .webhook_id)
    }
}

private extension KeyedDecodingContainer {
    func decodeDiscordSnowflake(forKey key: Key) throws -> DiscordSnowflake {
        if let stringValue = try? decode(String.self, forKey: key) {
            return stringValue
        }
        if let decimalValue = try? decode(Decimal.self, forKey: key) {
            if let wholeNumber = Self.wholeNumberString(from: decimalValue) {
                return wholeNumber
            }
            throw DecodingError.typeMismatch(
                String.self,
                DecodingError.Context(
                    codingPath: codingPath + [key],
                    debugDescription: "Expected Discord snowflake fields to be strings or whole numbers."
                )
            )
        }

        throw DecodingError.typeMismatch(
            String.self,
            DecodingError.Context(
                codingPath: codingPath + [key],
                debugDescription: "Expected Discord snowflake fields to be strings or whole numbers."
            )
        )
    }

    func decodeDiscordSnowflakeIfPresent(forKey key: Key) throws -> DiscordSnowflake? {
        guard contains(key), try decodeNil(forKey: key) == false else {
            return nil
        }
        return try decodeDiscordSnowflake(forKey: key)
    }

    func decodeDiscordSnowflakeArray(forKey key: Key) throws -> [DiscordSnowflake] {
        var container = try nestedUnkeyedContainer(forKey: key)
        var values: [DiscordSnowflake] = []
        var index = 0

        while !container.isAtEnd {
            if let stringValue = try? container.decode(String.self) {
                values.append(stringValue)
            } else if let decimalValue = try? container.decode(Decimal.self) {
                if let wholeNumber = Self.wholeNumberString(from: decimalValue) {
                    values.append(wholeNumber)
                } else {
                    throw DecodingError.typeMismatch(
                        String.self,
                        DecodingError.Context(
                            codingPath: codingPath + [key, DiscordArrayIndexCodingKey(index: index)],
                            debugDescription: "Expected Discord snowflake fields to be strings or whole numbers."
                        )
                    )
                }
            } else {
                throw DecodingError.typeMismatch(
                    String.self,
                    DecodingError.Context(
                        codingPath: codingPath + [key, DiscordArrayIndexCodingKey(index: index)],
                        debugDescription: "Expected Discord snowflake fields to be strings or whole numbers."
                    )
                )
            }

            index += 1
        }

        return values
    }

    private static func wholeNumberString(from decimal: Decimal) -> String? {
        var original = decimal
        var rounded = Decimal()
        NSDecimalRound(&rounded, &original, 0, .plain)
        guard rounded == decimal else {
            return nil
        }
        return NSDecimalNumber(decimal: rounded).stringValue
    }
}

private struct DiscordArrayIndexCodingKey: CodingKey {
    let intValue: Int?
    let stringValue: String

    init(index: Int) {
        intValue = index
        stringValue = String(index)
    }

    init?(intValue: Int) {
        self.intValue = intValue
        stringValue = String(intValue)
    }

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = Int(stringValue)
    }
}

// MARK: - JSON Support

enum JSONValue: Codable, Sendable {
    case string(String)
    case integer(Int64)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(
                JSONValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported JSON value.")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        switch self {
        case let .string(value):
            try container.encode(value)
        case let .integer(value):
            try container.encode(value)
        case let .number(value):
            try container.encode(value)
        case let .bool(value):
            try container.encode(value)
        case let .object(value):
            try container.encode(value)
        case let .array(value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case let .string(value) = self {
            return value
        }

        if case let .integer(value) = self {
            return String(value)
        }

        if case let .number(value) = self {
            if value.rounded() == value {
                return String(Int(value))
            }
            return String(value)
        }

        return nil
    }
}

enum DiscordAuditLogActionType {
    static let memberKick = 20
    static let memberBanAdd = 22
}

enum DiscordGatewayOpCode {
    static let dispatch = 0
    static let heartbeat = 1
    static let identify = 2
    static let resume = 6
    static let reconnect = 7
    static let invalidSession = 9
    static let hello = 10
    static let heartbeatAck = 11
}

enum DiscordPermission: UInt64 {
    case viewChannel = 1024
    case sendMessages = 2048
    case manageGuild = 32
    case manageRoles = 268435456
    case viewAuditLog = 128
    case administrator = 8
}

enum DiscordInteractionType {
    static let ping = 1
    static let applicationCommand = 2
    static let messageComponent = 3
    static let modalSubmit = 5
}

enum DiscordInteractionCallbackType {
    static let channelMessageWithSource = 4
    static let deferredChannelMessageWithSource = 5
    static let modal = 9
}

enum DiscordComponentType {
    static let actionRow = 1
    static let button = 2
    static let textInput = 4
}

enum DiscordButtonStyle {
    static let primary = 1
}

enum DiscordTextInputStyle {
    static let short = 1
    static let paragraph = 2
}

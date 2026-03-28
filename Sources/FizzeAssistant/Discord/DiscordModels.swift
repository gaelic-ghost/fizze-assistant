import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

typealias DiscordSnowflake = String

struct DiscordUser: Codable, Sendable {
    var id: DiscordSnowflake
    var username: String
    var globalName: String?

    var displayName: String {
        globalName ?? username
    }
}

struct DiscordRole: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String
    var permissions: String
    var position: Int
}

struct DiscordGuild: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String
    var ownerID: DiscordSnowflake?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case ownerID = "owner_id"
    }
}

struct DiscordChannel: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String?
    var type: Int
    var permissionOverwrites: [DiscordPermissionOverwrite]?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case type
        case permissionOverwrites = "permission_overwrites"
    }
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
    var auditLogEntries: [DiscordAuditLogEntry]

    enum CodingKeys: String, CodingKey {
        case auditLogEntries = "audit_log_entries"
    }
}

struct DiscordAuditLogEntry: Codable, Sendable {
    var id: DiscordSnowflake
    var actionType: Int
    var targetID: DiscordSnowflake?
    var userID: DiscordSnowflake?

    enum CodingKeys: String, CodingKey {
        case id
        case actionType = "action_type"
        case targetID = "target_id"
        case userID = "user_id"
    }
}

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
    var channelTypes: [Int]?

    enum CodingKeys: String, CodingKey {
        case type
        case name
        case description
        case required
        case channelTypes = "channel_types"
    }
}

struct DiscordInteraction: Codable, Sendable {
    var id: DiscordSnowflake
    var applicationID: DiscordSnowflake
    var type: Int
    var token: String
    var member: DiscordInteractionMember?
    var data: DiscordInteractionData?

    enum CodingKeys: String, CodingKey {
        case id
        case applicationID = "application_id"
        case type
        case token
        case member
        case data
    }
}

struct DiscordInteractionMember: Codable, Sendable {
    var user: DiscordUser?
    var roles: [DiscordSnowflake]
}

struct DiscordInteractionData: Codable, Sendable {
    var id: DiscordSnowflake
    var name: String
    var options: [DiscordInteractionOption]?
}

struct DiscordInteractionOption: Codable, Sendable {
    var name: String
    var type: Int
    var value: JSONValue?
}

struct DiscordMessageCreate: Codable, Sendable {
    var content: String
    var flags: Int?
}

struct DiscordCreateDMRequest: Codable, Sendable {
    var recipientID: DiscordSnowflake

    enum CodingKeys: String, CodingKey {
        case recipientID = "recipient_id"
    }
}

struct DiscordGatewayEnvelope: Codable, Sendable {
    var op: Int
    var d: JSONValue?
    var s: Int?
    var t: String?
}

struct DiscordHello: Codable, Sendable {
    var heartbeatInterval: Int

    enum CodingKeys: String, CodingKey {
        case heartbeatInterval = "heartbeat_interval"
    }
}

struct DiscordGatewayReady: Codable, Sendable {
    var sessionID: String
    var resumeGatewayURL: String

    enum CodingKeys: String, CodingKey {
        case sessionID = "session_id"
        case resumeGatewayURL = "resume_gateway_url"
    }
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
    var channelID: DiscordSnowflake
    var guildID: DiscordSnowflake?
    var content: String
    var author: DiscordUser
    var webhookID: DiscordSnowflake?

    enum CodingKeys: String, CodingKey {
        case id
        case channelID = "channel_id"
        case guildID = "guild_id"
        case content
        case author
        case webhookID = "webhook_id"
    }
}

enum JSONValue: Codable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let value = try? container.decode(String.self) {
            self = .string(value)
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
    case manageRoles = 268435456
    case viewAuditLog = 128
    case administrator = 8
}

import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct DiscordRESTClient {
    // MARK: Stored Properties

    private let token: String
    private let baseURL = URL(string: "https://discord.com/api/v10")!
    private let logger: Logger
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    // MARK: Lifecycle

    init(token: String, logger: Logger) {
        self.token = token
        self.logger = logger
        self.session = URLSession(configuration: .ephemeral)

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder
    }

    // MARK: REST Helpers

    func getCurrentUser() async throws -> DiscordUser {
        try await request(path: "/users/@me", method: "GET")
    }

    func getGatewayBot() async throws -> DiscordGatewayBotResponse {
        try await request(path: "/gateway/bot", method: "GET")
    }

    func getGuild(id: DiscordSnowflake) async throws -> DiscordGuild {
        try await request(path: "/guilds/\(id)", method: "GET")
    }

    func getChannel(id: DiscordSnowflake) async throws -> DiscordChannel {
        try await request(path: "/channels/\(id)", method: "GET")
    }

    func getGuildRoles(guildID: DiscordSnowflake) async throws -> [DiscordRole] {
        try await request(path: "/guilds/\(guildID)/roles", method: "GET")
    }

    func getGuildMember(guildID: DiscordSnowflake, userID: DiscordSnowflake) async throws -> DiscordMember {
        try await request(path: "/guilds/\(guildID)/members/\(userID)", method: "GET")
    }

    func addRole(to userID: DiscordSnowflake, guildID: DiscordSnowflake, roleID: DiscordSnowflake) async throws {
        _ = try await emptyRequest(path: "/guilds/\(guildID)/members/\(userID)/roles/\(roleID)", method: "PUT")
    }

    func createMessage(channelID: DiscordSnowflake, content: String, flags: Int? = nil) async throws {
        let payload = DiscordMessageCreate(content: content, flags: flags)
        _ = try await emptyRequest(path: "/channels/\(channelID)/messages", method: "POST", body: payload)
    }

    func createDMChannel(recipientID: DiscordSnowflake) async throws -> DiscordChannel {
        try await request(path: "/users/@me/channels", method: "POST", body: DiscordCreateDMRequest(recipientID: recipientID))
    }

    func upsertGuildCommands(applicationID: DiscordSnowflake, guildID: DiscordSnowflake, commands: [DiscordSlashCommand]) async throws {
        _ = try await emptyRequest(path: "/applications/\(applicationID)/guilds/\(guildID)/commands", method: "PUT", body: commands)
    }

    func createInteractionResponse(interactionID: DiscordSnowflake, token: String, payload: InteractionCallbackPayload) async throws {
        let path = "/interactions/\(interactionID)/\(token)/callback"
        _ = try await emptyRequest(path: path, method: "POST", body: payload, requiresBotAuthorization: false)
    }

    func getAuditLogEntries(guildID: DiscordSnowflake, actionType: Int, limit: Int = 10) async throws -> [DiscordAuditLogEntry] {
        let response: DiscordAuditLogResponse = try await request(
            path: "/guilds/\(guildID)/audit-logs",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "action_type", value: String(actionType)),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
        return response.auditLogEntries
    }

    // MARK: Low-Level Requests

    private func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        requiresBotAuthorization: Bool = true
    ) async throws -> T {
        try await request(path: path, method: method, queryItems: queryItems, body: Optional<Data>.none, requiresBotAuthorization: requiresBotAuthorization)
    }

    private func request<T: Decodable, Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        requiresBotAuthorization: Bool = true
    ) async throws -> T {
        let data = try encoder.encode(body)
        return try await request(path: path, method: method, body: data, requiresBotAuthorization: requiresBotAuthorization)
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data?,
        requiresBotAuthorization: Bool = true
    ) async throws -> T {
        let data = try await rawRequest(path: path, method: method, queryItems: queryItems, body: body, requiresBotAuthorization: requiresBotAuthorization)
        return try decoder.decode(T.self, from: data)
    }

    private func emptyRequest<Body: Encodable>(
        path: String,
        method: String,
        body: Body,
        requiresBotAuthorization: Bool = true
    ) async throws -> Data {
        try await rawRequest(path: path, method: method, body: try encoder.encode(body), requiresBotAuthorization: requiresBotAuthorization)
    }

    private func emptyRequest(
        path: String,
        method: String,
        requiresBotAuthorization: Bool = true
    ) async throws -> Data {
        try await rawRequest(path: path, method: method, body: nil, requiresBotAuthorization: requiresBotAuthorization)
    }

    private func rawRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data?,
        requiresBotAuthorization: Bool = true
    ) async throws -> Data {
        let normalizedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        var components = URLComponents(url: baseURL.appendingPathComponent(normalizedPath), resolvingAgainstBaseURL: false)
        if !queryItems.isEmpty {
            components?.queryItems = queryItems
        }

        guard let url = components?.url else {
            throw RESTError.invalidURL(path)
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if requiresBotAuthorization {
            request.setValue("Bot \(token)", forHTTPHeaderField: "Authorization")
        }

        logger.debug("Discord REST request", metadata: [
            "method": .string(method),
            "path": .string(path),
        ])

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RESTError.invalidResponse
        }

        guard (200 ... 299).contains(http.statusCode) else {
            throw RESTError.discordError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "<unreadable>")
        }

        return data
    }
}

enum RESTError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case discordError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            return "Invalid Discord URL for path \(path)."
        case .invalidResponse:
            return "Discord returned an invalid response."
        case let .discordError(statusCode, body):
            return "Discord API error \(statusCode): \(body)"
        }
    }
}

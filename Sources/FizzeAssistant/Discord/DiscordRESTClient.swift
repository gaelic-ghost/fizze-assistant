import Foundation
import Logging

struct DiscordRESTClient {
    // MARK: Stored Properties

    private let token: String
    private let baseURL: URL
    private let logger: Logger
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let maxRetryAttempts = 5

    // MARK: Lifecycle

    init(token: String, logger: Logger) {
        self.init(
            token: token,
            logger: logger,
            session: URLSession(configuration: .ephemeral),
            baseURL: URL(string: "https://discord.com/api/v10")!
        )
    }

    init(token: String, logger: Logger, session: URLSession, baseURL: URL) {
        self.token = token
        self.logger = logger
        self.session = session
        self.baseURL = baseURL

        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
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

    func getGuildRoles(guild_id: DiscordSnowflake) async throws -> [DiscordRole] {
        try await request(path: "/guilds/\(guild_id)/roles", method: "GET")
    }

    func getGuildMember(guild_id: DiscordSnowflake, user_id: DiscordSnowflake) async throws -> DiscordMember {
        try await request(path: "/guilds/\(guild_id)/members/\(user_id)", method: "GET")
    }

    func addRole(to user_id: DiscordSnowflake, guild_id: DiscordSnowflake, role_id: DiscordSnowflake) async throws {
        _ = try await emptyRequest(path: "/guilds/\(guild_id)/members/\(user_id)/roles/\(role_id)", method: "PUT")
    }

    func removeRole(from user_id: DiscordSnowflake, guild_id: DiscordSnowflake, role_id: DiscordSnowflake) async throws {
        _ = try await emptyRequest(path: "/guilds/\(guild_id)/members/\(user_id)/roles/\(role_id)", method: "DELETE")
    }

    func createMessage(channel_id: DiscordSnowflake, payload: DiscordMessageCreate) async throws {
        _ = try await emptyRequest(path: "/channels/\(channel_id)/messages", method: "POST", body: payload)
    }

    func createMessage(channel_id: DiscordSnowflake, content: String, flags: Int? = nil) async throws {
        try await createMessage(
            channel_id: channel_id,
            payload: DiscordMessageCreate(content: content, embeds: nil, flags: flags)
        )
    }

    func createDMChannel(recipient_id: DiscordSnowflake) async throws -> DiscordChannel {
        try await request(path: "/users/@me/channels", method: "POST", body: DiscordCreateDMRequest(recipient_id: recipient_id))
    }

    func upsertGuildCommands(application_id: DiscordSnowflake, guild_id: DiscordSnowflake, commands: [DiscordSlashCommand]) async throws {
        _ = try await emptyRequest(path: "/applications/\(application_id)/guilds/\(guild_id)/commands", method: "PUT", body: commands)
    }

    func createInteractionResponse(interaction_id: DiscordSnowflake, token: String, payload: InteractionCallbackPayload) async throws {
        let path = "/interactions/\(interaction_id)/\(token)/callback"
        _ = try await emptyRequest(path: path, method: "POST", body: payload, requiresBotAuthorization: false)
    }

    func getAuditLogEntries(guild_id: DiscordSnowflake, action_type: Int, limit: Int = 10) async throws -> [DiscordAuditLogEntry] {
        let response: DiscordAuditLogResponse = try await request(
            path: "/guilds/\(guild_id)/audit-logs",
            method: "GET",
            queryItems: [
                URLQueryItem(name: "action_type", value: String(action_type)),
                URLQueryItem(name: "limit", value: String(limit)),
            ]
        )
        return response.audit_log_entries
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

        return try await performRawRequest(request, path: path, attempt: 0)
    }

    private func performRawRequest(_ request: URLRequest, path: String, attempt: Int) async throws -> Data {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw RESTError.invalidResponse
        }

        if (200 ... 299).contains(http.statusCode) {
            return data
        }

        if http.statusCode == 429, attempt < maxRetryAttempts {
            let delay = rateLimitDelay(response: http, body: data)
            logger.warning("DiscordRESTClient.performRawRequest: Discord asked the bot to slow down on this API route, so the request will pause briefly and retry.", metadata: [
                "path": .string(path),
                "retry_after_seconds": .string(String(delay)),
                "attempt": .string(String(attempt + 1)),
            ])
            try await Task.sleep(for: .seconds(delay))
            return try await performRawRequest(request, path: path, attempt: attempt + 1)
        }

        if (500 ... 599).contains(http.statusCode), attempt < maxRetryAttempts {
            let delay = min(pow(2.0, Double(attempt)), 30.0)
            logger.warning("DiscordRESTClient.performRawRequest: Discord returned a temporary server error for this API route, so the request will retry with backoff.", metadata: [
                "path": .string(path),
                "status_code": .string(String(http.statusCode)),
                "retry_after_seconds": .string(String(delay)),
                "attempt": .string(String(attempt + 1)),
            ])
            try await Task.sleep(for: .seconds(delay))
            return try await performRawRequest(request, path: path, attempt: attempt + 1)
        }

        throw RESTError.discordError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "<unreadable>")
    }

    func rateLimitDelay(response: HTTPURLResponse, body: Data) -> Double {
        if let header = response.value(forHTTPHeaderField: "Retry-After"), let value = Double(header) {
            return max(value, 1)
        }

        if let header = response.value(forHTTPHeaderField: "X-RateLimit-Reset-After"), let value = Double(header) {
            return max(value, 1)
        }

        if
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let retryAfter = object["retry_after"] as? Double
        {
            return max(retryAfter, 1)
        }

        return 1
    }
}

enum RESTError: LocalizedError {
    case invalidURL(String)
    case invalidResponse
    case discordError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            return "DiscordRESTClient.request: the bot could not build a valid Discord URL for path `\(path)`. The most likely cause is a malformed route string in the code."
        case .invalidResponse:
            return "DiscordRESTClient.performRawRequest: Discord returned a response that was not valid HTTP. The most likely cause is a transport-level failure between the bot and the Discord API."
        case let .discordError(statusCode, body):
            return "DiscordRESTClient.performRawRequest: Discord responded with HTTP \(statusCode) for this API call. Response body: \(body). The most likely cause is a missing permission, an unknown resource ID, or a rate-limit response that exceeded the retry policy."
        }
    }
}

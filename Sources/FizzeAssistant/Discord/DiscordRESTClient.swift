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
    private let rateLimitCoordinator: DiscordRateLimitCoordinator
    private let invalidRequestTracker: DiscordInvalidRequestTracker
    private let maxRetryAttempts = 5
    private let requestTimeoutSeconds: TimeInterval = 15
    private let userAgent = "DiscordBot (https://github.com/gaelic-ghost/fizze-assistant, 1.0)"

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
        self.rateLimitCoordinator = DiscordRateLimitCoordinator()
        self.invalidRequestTracker = DiscordInvalidRequestTracker()
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

    func editOriginalInteractionResponse(
        application_id: DiscordSnowflake,
        token: String,
        payload: DiscordMessageCreate
    ) async throws {
        let path = "/webhooks/\(application_id)/\(token)/messages/@original"
        _ = try await emptyRequest(path: path, method: "PATCH", body: payload, requiresBotAuthorization: false)
    }

    func createInteractionFollowup(
        application_id: DiscordSnowflake,
        token: String,
        payload: DiscordMessageCreate
    ) async throws {
        let path = "/webhooks/\(application_id)/\(token)"
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
        let descriptor = RequestDescriptor(path: path, method: method, requiresBotAuthorization: requiresBotAuthorization)
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
        request.timeoutInterval = requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        if requiresBotAuthorization {
            request.setValue("Bot \(token)", forHTTPHeaderField: "Authorization")
        }

        logger.debug("Discord REST request", metadata: [
            "method": .string(method),
            "path": .string(path),
        ])

        return try await performRawRequest(request, descriptor: descriptor, attempt: 0)
    }

    private func performRawRequest(_ request: URLRequest, descriptor: RequestDescriptor, attempt: Int) async throws -> Data {
        try await rateLimitCoordinator.waitIfNeeded(for: descriptor)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as CancellationError {
            throw error
        } catch {
            if shouldRetryTransportError(error, descriptor: descriptor, attempt: attempt) {
                let delay = transportRetryDelaySeconds(forAttempt: attempt)
                logger.warning("DiscordRESTClient.performRawRequest: the network dropped during a Discord API call, so the bot will retry this idempotent route with backoff.", metadata: [
                    "path": .string(descriptor.path),
                    "retry_after_seconds": .string(String(delay)),
                    "attempt": .string(String(attempt + 1)),
                    "error": .string(String(describing: error)),
                ])
                try await Task.sleep(for: .seconds(delay))
                return try await performRawRequest(request, descriptor: descriptor, attempt: attempt + 1)
            }
            throw error
        }
        guard let http = response as? HTTPURLResponse else {
            throw RESTError.invalidResponse
        }

        let rateLimit = RateLimitObservation(response: http, body: data)
        await rateLimitCoordinator.record(rateLimit, for: descriptor)

        if http.statusCode == 401, descriptor.requiresBotAuthorization {
            await rateLimitCoordinator.markBotAuthorizationRejected()
        }
        await logInvalidRequestIfNeeded(statusCode: http.statusCode, scope: rateLimit.scope, descriptor: descriptor)

        if (200 ... 299).contains(http.statusCode) {
            return data
        }

        if http.statusCode == 429, attempt < maxRetryAttempts {
            let delay = rateLimitDelay(response: http, body: data)
            logger.warning("DiscordRESTClient.performRawRequest: Discord asked the bot to slow down on this API route, so the request will pause briefly and retry.", metadata: [
                "path": .string(descriptor.path),
                "rate_limit_scope": .string(rateLimit.scope ?? "unknown"),
                "retry_after_seconds": .string(String(delay)),
                "attempt": .string(String(attempt + 1)),
            ])
            try await Task.sleep(for: .seconds(delay))
            return try await performRawRequest(request, descriptor: descriptor, attempt: attempt + 1)
        }

        if (500 ... 599).contains(http.statusCode), descriptor.policy.allowsServerRetry, attempt < maxRetryAttempts {
            let delay = min(pow(2.0, Double(attempt)), 30.0)
            logger.warning("DiscordRESTClient.performRawRequest: Discord returned a temporary server error for this API route, so the request will retry with backoff.", metadata: [
                "path": .string(descriptor.path),
                "status_code": .string(String(http.statusCode)),
                "retry_after_seconds": .string(String(delay)),
                "attempt": .string(String(attempt + 1)),
            ])
            try await Task.sleep(for: .seconds(delay))
            return try await performRawRequest(request, descriptor: descriptor, attempt: attempt + 1)
        }

        throw RESTError.discordError(statusCode: http.statusCode, body: String(data: data, encoding: .utf8) ?? "<unreadable>")
    }

    private func shouldRetryTransportError(_ error: Error, descriptor: RequestDescriptor, attempt: Int) -> Bool {
        guard attempt < maxRetryAttempts else { return false }
        guard descriptor.policy.allowsTransportRetry else { return false }

        if let urlError = error as? URLError {
            switch urlError.code {
            case .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }

        let nsError = error as NSError
        guard nsError.domain == NSURLErrorDomain else { return false }
        switch nsError.code {
        case NSURLErrorNetworkConnectionLost, NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed, NSURLErrorNotConnectedToInternet:
            return true
        default:
            return false
        }
    }

    private func logInvalidRequestIfNeeded(statusCode: Int, scope: String?, descriptor: RequestDescriptor) async {
        if let count = await invalidRequestTracker.record(statusCode: statusCode, scope: scope) {
            logger.warning("DiscordRESTClient.performRawRequest: the bot is accumulating invalid Discord API requests unusually quickly, which can lead to a temporary Cloudflare restriction if it continues.", metadata: [
                "invalid_request_count_10m": .string(String(count)),
                "path": .string(descriptor.path),
                "status_code": .string(String(statusCode)),
                "rate_limit_scope": .string(scope ?? "none"),
            ])
        }
    }

    private func transportRetryDelaySeconds(forAttempt attempt: Int) -> Double {
        min(pow(2.0, Double(attempt)), 5.0)
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
    case authenticationRejected
    case discordError(statusCode: Int, body: String)

    var errorDescription: String? {
        switch self {
        case let .invalidURL(path):
            return "DiscordRESTClient.request: the bot could not build a valid Discord URL for path `\(path)`. The most likely cause is a malformed route string in the code."
        case .invalidResponse:
            return "DiscordRESTClient.performRawRequest: Discord returned a response that was not valid HTTP. The most likely cause is a transport-level failure between the bot and the Discord API."
        case .authenticationRejected:
            return "DiscordRESTClient.performRawRequest: Discord rejected the bot token with HTTP 401, so further authenticated API calls are paused for this process. The most likely cause is that the configured bot token is invalid, revoked, or belongs to a different application."
        case let .discordError(statusCode, body):
            return "DiscordRESTClient.performRawRequest: Discord responded with HTTP \(statusCode) for this API call. Response body: \(body). The most likely cause is a missing permission, an unknown resource ID, or a rate-limit response that exceeded the retry policy."
        }
    }
}

private struct RequestDescriptor: Sendable {
    // MARK: Stored Properties

    let path: String
    let method: String
    let requiresBotAuthorization: Bool
    let routeKey: String
    let partitionKey: String?
    let routeThrottleKey: String
    let policy: RequestPolicy

    // MARK: Lifecycle

    init(path: String, method: String, requiresBotAuthorization: Bool) {
        self.path = path
        self.method = method.uppercased()
        self.requiresBotAuthorization = requiresBotAuthorization
        self.partitionKey = Self.partitionKey(for: path)
        self.routeKey = "\(self.method) \(Self.canonicalRoutePath(path))"
        self.routeThrottleKey = "\(routeKey)|\(partitionKey ?? "-")"
        self.policy = RequestPolicy(path: path, method: self.method, requiresBotAuthorization: requiresBotAuthorization)
    }

    // MARK: Private Helpers

    private static func partitionKey(for path: String) -> String? {
        let segments = path.split(separator: "/")
        guard let resource = segments.first else { return nil }

        switch resource {
        case "channels" where segments.count > 1:
            return "channel:\(segments[1])"
        case "guilds" where segments.count > 1:
            return "guild:\(segments[1])"
        case "webhooks" where segments.count > 2:
            return "webhook:\(segments[1]):\(segments[2])"
        default:
            return nil
        }
    }

    private static func canonicalRoutePath(_ path: String) -> String {
        var segments = path.split(separator: "/").map(String.init)
        guard segments.count > 1 else {
            return "/" + segments.joined(separator: "/")
        }

        switch segments[0] {
        case "applications":
            segments[1] = "{application_id}"
            if segments.count > 3, segments[2] == "guilds" {
                segments[3] = "{guild_id}"
            }
            if segments.count > 5, segments[4] == "commands" {
                segments[5] = "{command_id}"
            }
        case "channels":
            segments[1] = "{channel_id}"
            if segments.count > 3, segments[2] == "messages" {
                segments[3] = "{message_id}"
            }
        case "guilds":
            segments[1] = "{guild_id}"
            if segments.count > 3, segments[2] == "members" {
                segments[3] = "{user_id}"
                if segments.count > 5, segments[4] == "roles" {
                    segments[5] = "{role_id}"
                }
            }
            if segments.count > 3, segments[2] == "roles" {
                segments[3] = "{role_id}"
            }
            if segments.count > 5, segments[2] == "commands", segments[4] == "permissions" {
                segments[3] = "{command_id}"
                segments[5] = "{permissions_id}"
            }
        case "interactions":
            segments[1] = "{interaction_id}"
            if segments.count > 2 {
                segments[2] = "{interaction_token}"
            }
        case "webhooks":
            segments[1] = "{webhook_id}"
            if segments.count > 2 {
                segments[2] = "{webhook_token}"
            }
            if segments.count > 4, segments[3] == "messages", segments[4] != "@original" {
                segments[4] = "{message_id}"
            }
        default:
            break
        }

        return "/" + segments.joined(separator: "/")
    }
}

private struct RequestPolicy: Sendable {
    // MARK: Stored Properties

    let allowsTransportRetry: Bool
    let allowsServerRetry: Bool
    let bypassBotGlobalLimit: Bool

    // MARK: Lifecycle

    init(path: String, method: String, requiresBotAuthorization: Bool) {
        let normalizedMethod = method.uppercased()
        let isInteractionCallback = path.hasPrefix("/interactions/")
        let isInteractionWebhook = path.hasPrefix("/webhooks/")
        let isInteractionWebhookEdit = isInteractionWebhook && (normalizedMethod == "PATCH" || normalizedMethod == "DELETE")
        let isIdempotentStandard = ["GET", "PUT", "DELETE"].contains(normalizedMethod)

        self.allowsTransportRetry = isIdempotentStandard || isInteractionWebhookEdit
        self.allowsServerRetry = isIdempotentStandard || isInteractionWebhookEdit
        self.bypassBotGlobalLimit = !requiresBotAuthorization || isInteractionCallback || isInteractionWebhook
    }
}

private struct RateLimitObservation: Sendable {
    // MARK: Stored Properties

    let bucket: String?
    let remaining: Int?
    let resetAfter: Double?
    let retryAfter: Double?
    let scope: String?
    let isGlobal: Bool

    // MARK: Lifecycle

    init(response: HTTPURLResponse, body: Data) {
        self.bucket = response.value(forHTTPHeaderField: "X-RateLimit-Bucket")
        self.remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining").flatMap(Int.init)
        self.resetAfter = response.value(forHTTPHeaderField: "X-RateLimit-Reset-After").flatMap(Double.init)
        self.retryAfter = RateLimitObservation.retryAfter(response: response, body: body)
        self.scope = response.value(forHTTPHeaderField: "X-RateLimit-Scope")
        self.isGlobal = response.value(forHTTPHeaderField: "X-RateLimit-Global")?.lowercased() == "true"
    }

    private static func retryAfter(response: HTTPURLResponse, body: Data) -> Double? {
        if let header = response.value(forHTTPHeaderField: "Retry-After"), let value = Double(header) {
            return value
        }

        if
            let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
            let retryAfter = object["retry_after"] as? Double
        {
            return retryAfter
        }

        return nil
    }
}

private actor DiscordRateLimitCoordinator {
    // MARK: Stored Properties

    private var bucketIDByRouteKey: [String: String] = [:]
    private var blockedUntilByBucketKey: [String: Date] = [:]
    private var blockedUntilByRouteKey: [String: Date] = [:]
    private var globalBlockedUntil: Date?
    private var botAuthorizationRejected = false

    // MARK: Public API

    func waitIfNeeded(for descriptor: RequestDescriptor) async throws {
        if descriptor.requiresBotAuthorization && botAuthorizationRejected {
            throw RESTError.authenticationRejected
        }

        let now = Date()
        let waitUntil = [
            applicableGlobalBlock(for: descriptor),
            applicableBucketBlock(for: descriptor),
            blockedUntilByRouteKey[descriptor.routeThrottleKey],
        ]
        .compactMap { $0 }
        .max() ?? now

        guard waitUntil > now else { return }
        try await Task.sleep(for: .seconds(waitUntil.timeIntervalSince(now)))
    }

    func record(_ observation: RateLimitObservation, for descriptor: RequestDescriptor) {
        let now = Date()

        if let bucket = observation.bucket {
            bucketIDByRouteKey[descriptor.routeKey] = bucket
        }

        if observation.isGlobal, let retryAfter = observation.retryAfter {
            globalBlockedUntil = now.addingTimeInterval(retryAfter)
        }

        if let retryAfter = observation.retryAfter {
            let until = now.addingTimeInterval(retryAfter)
            if let bucket = observation.bucket {
                blockedUntilByBucketKey[scopedBucketKey(bucketID: bucket, partitionKey: descriptor.partitionKey)] = until
                blockedUntilByRouteKey.removeValue(forKey: descriptor.routeThrottleKey)
            } else {
                blockedUntilByRouteKey[descriptor.routeThrottleKey] = until
            }
            return
        }

        if let bucket = observation.bucket, let remaining = observation.remaining, remaining == 0, let resetAfter = observation.resetAfter {
            blockedUntilByBucketKey[scopedBucketKey(bucketID: bucket, partitionKey: descriptor.partitionKey)] = now.addingTimeInterval(resetAfter)
        }
    }

    func markBotAuthorizationRejected() {
        botAuthorizationRejected = true
    }

    // MARK: Private Helpers

    private func applicableGlobalBlock(for descriptor: RequestDescriptor) -> Date? {
        guard !descriptor.policy.bypassBotGlobalLimit else { return nil }
        return globalBlockedUntil
    }

    private func applicableBucketBlock(for descriptor: RequestDescriptor) -> Date? {
        guard let bucketID = bucketIDByRouteKey[descriptor.routeKey] else { return nil }
        return blockedUntilByBucketKey[scopedBucketKey(bucketID: bucketID, partitionKey: descriptor.partitionKey)]
    }

    private func scopedBucketKey(bucketID: String, partitionKey: String?) -> String {
        if let partitionKey {
            return "\(bucketID)|\(partitionKey)"
        }
        return bucketID
    }
}

private actor DiscordInvalidRequestTracker {
    // MARK: Stored Properties

    private var timestamps: [Date] = []
    private var lastWarningAt: Date?
    private let threshold = 100
    private let windowSeconds: TimeInterval = 600
    private let warningCooldownSeconds: TimeInterval = 60

    // MARK: Public API

    func record(statusCode: Int, scope: String?) -> Int? {
        guard shouldCount(statusCode: statusCode, scope: scope) else { return nil }

        let now = Date()
        timestamps.append(now)
        timestamps.removeAll { now.timeIntervalSince($0) > windowSeconds }

        guard timestamps.count >= threshold else { return nil }
        guard lastWarningAt.map({ now.timeIntervalSince($0) > warningCooldownSeconds }) ?? true else { return nil }

        lastWarningAt = now
        return timestamps.count
    }

    // MARK: Private Helpers

    private func shouldCount(statusCode: Int, scope: String?) -> Bool {
        switch statusCode {
        case 401, 403:
            return true
        case 429:
            return scope?.lowercased() != "shared"
        default:
            return false
        }
    }
}

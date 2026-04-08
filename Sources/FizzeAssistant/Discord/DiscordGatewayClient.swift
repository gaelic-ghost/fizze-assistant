import Foundation
import Logging

protocol DiscordGatewaySocket: Sendable {
    func resume()
    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
    func send(_ message: URLSessionWebSocketTask.Message) async throws
    func receive() async throws -> URLSessionWebSocketTask.Message
}

extension URLSessionWebSocketTask: DiscordGatewaySocket {}
extension URLSessionWebSocketTask: @unchecked Sendable {}

actor DiscordGatewayClient {
    // MARK: Types

    enum Event: Sendable {
        case memberJoined(DiscordGuildMemberAddEvent)
        case memberRemoved(DiscordGuildMemberRemoveEvent)
        case memberBanned(DiscordGuildBanAddEvent)
        case interaction(DiscordInteraction)
        case message(DiscordMessageEvent)
    }

    // MARK: Stored Properties

    private let token: String
    private let gatewayURL: URL
    private let intents: Int
    private let logger: Logger
    private let onEvent: @Sendable (Event) async -> Void
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let makeSocket: @Sendable (URL) -> any DiscordGatewaySocket
    private let sleep: @Sendable (Duration) async throws -> Void
    private let reconnectDelayProvider: @Sendable (Int) -> Double

    private var webSocketTask: (any DiscordGatewaySocket)?
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var sequenceNumber: Int?
    private var session_id: String?
    private var resumeURL: URL?
    private var heartbeat_interval_nanoseconds: UInt64 = 30_000_000_000
    private var awaitingHeartbeatACK = false
    private var isRunning = false
    private var isReconnecting = false
    private var reconnectAttempt = 0

    // MARK: Lifecycle

    init(
        token: String,
        gatewayURL: URL,
        intents: Int,
        logger: Logger,
        onEvent: @escaping @Sendable (Event) async -> Void
    ) {
        let session = URLSession(configuration: .ephemeral)
        self.init(
            token: token,
            gatewayURL: gatewayURL,
            intents: intents,
            logger: logger,
            makeSocket: { [session] url in
                session.webSocketTask(with: url)
            },
            sleep: { duration in
                try await Task.sleep(for: duration)
            },
            reconnectDelayProvider: { attempt in
                Self.defaultReconnectDelaySeconds(forAttempt: attempt)
            },
            onEvent: onEvent
        )
    }

    init(
        token: String,
        gatewayURL: URL,
        intents: Int,
        logger: Logger,
        makeSocket: @escaping @Sendable (URL) -> any DiscordGatewaySocket,
        sleep: @escaping @Sendable (Duration) async throws -> Void,
        reconnectDelayProvider: @escaping @Sendable (Int) -> Double,
        onEvent: @escaping @Sendable (Event) async -> Void
    ) {
        self.token = token
        self.gatewayURL = gatewayURL
        self.intents = intents
        self.logger = logger
        self.makeSocket = makeSocket
        self.sleep = sleep
        self.reconnectDelayProvider = reconnectDelayProvider
        self.onEvent = onEvent

        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }

    // MARK: Public API

    func start() async throws {
        isRunning = true
        try await connect(using: gatewayURL)
    }

    func stop() async {
        isRunning = false
        heartbeatTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
    }

    // MARK: Connection Management

    private func connect(using url: URL) async throws {
        logger.info("DiscordGatewayClient.connect: opening the live Discord Gateway connection for event streaming.", metadata: ["url": .string(url.absoluteString)])

        let task = makeSocket(url)
        webSocketTask = task
        task.resume()

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func reconnect() async {
        guard isRunning else { return }
        guard !isReconnecting else { return }
        isReconnecting = true
        defer { isReconnecting = false }

        heartbeatTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        awaitingHeartbeatACK = false

        let targetURL = resumeURL ?? gatewayURL
        do {
            let delay = reconnectDelayProvider(reconnectAttempt)
            if delay > 0 {
                logger.warning("DiscordGatewayClient.reconnect: the Gateway connection needs to reopen, so the bot is waiting briefly before the next attempt.", metadata: [
                    "delay_seconds": .string(String(format: "%.2f", delay)),
                    "attempt": .string(String(reconnectAttempt + 1)),
                ])
                try await sleep(.seconds(delay))
            }
            reconnectAttempt += 1
            try await connect(using: targetURL)
        } catch is CancellationError {
            logger.debug("DiscordGatewayClient.reconnect: this reconnect attempt was cancelled before the new socket opened, so the bot will wait for the next recovery trigger.")
        } catch {
            logger.warning("DiscordGatewayClient.reconnect: this reconnect attempt did not complete, but the bot will keep trying while it stays running.", metadata: ["error": .string(String(describing: error))])
        }
    }

    private func scheduleReconnect() {
        guard isRunning else { return }

        Task { [weak self] in
            await self?.reconnect()
        }
    }

    private func receiveLoop() async {
        while isRunning, let task = webSocketTask {
            do {
                let message = try await task.receive()
                switch message {
                case let .string(text):
                    try await handle(messageData: Data(text.utf8))
                case let .data(data):
                    try await handle(messageData: data)
                @unknown default:
                    logger.warning("DiscordGatewayClient.receiveLoop: Discord sent a WebSocket message type this client does not decode yet, so that frame will be skipped while the connection stays open.")
                }
            } catch is CancellationError {
                return
            } catch let error as NSError where error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled {
                logger.debug("DiscordGatewayClient.receiveLoop: the previous Gateway receive task was cancelled because the connection is being refreshed.")
                return
            } catch {
                logger.warning("DiscordGatewayClient.receiveLoop: the live Gateway connection dropped, so the bot is opening a fresh connection.", metadata: ["error": .string(String(describing: error))])
                scheduleReconnect()
                return
            }
        }
    }

    private func handle(messageData: Data) async throws {
        let envelope = try decoder.decode(DiscordGatewayEnvelope.self, from: messageData)
        sequenceNumber = envelope.s ?? sequenceNumber
        reconnectAttempt = 0

        switch envelope.op {
        case DiscordGatewayOpCode.hello:
            heartbeat_interval_nanoseconds = try parseHeartbeatInterval(from: envelope.d)
            logger.info("DiscordGatewayClient.handle: Discord sent HELLO, so the bot now knows the heartbeat interval and can begin session setup.", metadata: [
                "heartbeat_interval_nanoseconds": .string(String(heartbeat_interval_nanoseconds)),
            ])
            heartbeatTask?.cancel()
            heartbeatTask = Task { [weak self] in
                await self?.heartbeatLoop()
            }
            try await sendIdentifyOrResume()

        case DiscordGatewayOpCode.dispatch:
            try await handleDispatch(eventName: envelope.t, payload: envelope.d)

        case DiscordGatewayOpCode.reconnect:
            scheduleReconnect()

        case DiscordGatewayOpCode.invalidSession:
            session_id = nil
            resumeURL = nil
            scheduleReconnect()

        case DiscordGatewayOpCode.heartbeatAck:
            awaitingHeartbeatACK = false
            logger.debug("DiscordGatewayClient.handle: Discord acknowledged the latest heartbeat, so the Gateway session is still healthy.")

        default:
            break
        }
    }

    // MARK: Heartbeats And Session Setup

    private func heartbeatLoop() async {
        while isRunning {
            do {
                if awaitingHeartbeatACK {
                    logger.warning("DiscordGatewayClient.heartbeatLoop: Discord stopped acknowledging heartbeats in time, so the bot is refreshing the Gateway connection.")
                    scheduleReconnect()
                    return
                }

                awaitingHeartbeatACK = true
                try await send(payload: [
                    "op": .number(Double(DiscordGatewayOpCode.heartbeat)),
                    "d": sequenceNumber.map { .number(Double($0)) } ?? .null,
                ])

                try await sleep(.nanoseconds(heartbeat_interval_nanoseconds))
            } catch is CancellationError {
                return
            } catch {
                logger.warning("DiscordGatewayClient.heartbeatLoop: the heartbeat send cycle did not complete cleanly, so the bot is reopening the Gateway connection.", metadata: ["error": .string(String(describing: error))])
                scheduleReconnect()
                return
            }
        }
    }

    private func sendIdentifyOrResume() async throws {
        if let session_id, let resumeURL {
            self.resumeURL = resumeURL
            logger.info("DiscordGatewayClient.sendIdentifyOrResume: the bot has an existing session, so it is sending a resume request to Discord Gateway.", metadata: [
                "session_id": .string(session_id),
                "resume_url": .string(resumeURL.absoluteString),
            ])
            try await send(payload: [
                "op": .number(Double(DiscordGatewayOpCode.resume)),
                "d": .object([
                    "token": .string(token),
                    "session_id": .string(session_id),
                    "seq": sequenceNumber.map { .number(Double($0)) } ?? .null,
                ]),
            ])
            return
        }

        logger.info("DiscordGatewayClient.sendIdentifyOrResume: the bot is sending a fresh identify request to Discord Gateway to start a new session.")
        try await send(payload: [
            "op": .number(Double(DiscordGatewayOpCode.identify)),
            "d": .object([
                "token": .string(token),
                "intents": .number(Double(intents)),
                "properties": .object([
                    "os": .string("macOS"),
                    "browser": .string("fizze-assistant"),
                    "device": .string("fizze-assistant"),
                ]),
            ]),
        ])
    }

    private func send(payload: [String: JSONValue]) async throws {
        let data = try encoder.encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw GatewayError.encodingFailed
        }
        try await webSocketTask?.send(.string(text))
    }

    private func handleDispatch(eventName: String?, payload: JSONValue?) async throws {
        switch eventName {
        case "READY":
            let ready = try parseReadyPayload(from: payload)
            session_id = ready.session_id
            resumeURL = URL(string: "\(ready.resume_gateway_url)?v=10&encoding=json")
            logger.info("DiscordGatewayClient.handleDispatch: Discord sent READY, so the Gateway session is established and the bot is now online for events.", metadata: [
                "session_id": .string(ready.session_id),
                "resume_gateway_url": .string(ready.resume_gateway_url),
            ])

        case "GUILD_MEMBER_ADD":
            try await decodeAndForwardDispatch(
                eventName: "GUILD_MEMBER_ADD",
                payload: payload,
                safeToDropOnDecodeFailure: true,
                decode: { try decodePayload(DiscordGuildMemberAddEvent.self, from: $0) },
                forward: { await onEvent(.memberJoined($0)) }
            )

        case "GUILD_MEMBER_REMOVE":
            try await decodeAndForwardDispatch(
                eventName: "GUILD_MEMBER_REMOVE",
                payload: payload,
                safeToDropOnDecodeFailure: true,
                decode: { try decodePayload(DiscordGuildMemberRemoveEvent.self, from: $0) },
                forward: { await onEvent(.memberRemoved($0)) }
            )

        case "GUILD_BAN_ADD":
            try await decodeAndForwardDispatch(
                eventName: "GUILD_BAN_ADD",
                payload: payload,
                safeToDropOnDecodeFailure: true,
                decode: { try decodePayload(DiscordGuildBanAddEvent.self, from: $0) },
                forward: { await onEvent(.memberBanned($0)) }
            )

        case "INTERACTION_CREATE":
            try await decodeAndForwardDispatch(
                eventName: "INTERACTION_CREATE",
                payload: payload,
                safeToDropOnDecodeFailure: true,
                decode: { try decodePayload(DiscordInteraction.self, from: $0) },
                forward: { await onEvent(.interaction($0)) }
            )

        case "MESSAGE_CREATE":
            try await decodeAndForwardDispatch(
                eventName: "MESSAGE_CREATE",
                payload: payload,
                safeToDropOnDecodeFailure: true,
                decode: { try decodePayload(DiscordMessageEvent.self, from: $0) },
                forward: { await onEvent(.message($0)) }
            )

        default:
            break
        }
    }

    private func decodeAndForwardDispatch<EventPayload>(
        eventName: String,
        payload: JSONValue?,
        safeToDropOnDecodeFailure: Bool,
        decode: (JSONValue?) throws -> EventPayload,
        forward: (EventPayload) async -> Void
    ) async throws {
        do {
            let event = try decode(payload)
            await forward(event)
        } catch {
            guard safeToDropOnDecodeFailure else {
                throw error
            }

            logger.warning(
                "DiscordGatewayClient.handleDispatch: Discord sent a dispatch payload this bot could not decode cleanly, so that single event will be dropped while the Gateway session stays online.",
                metadata: [
                    "event_name": .string(eventName),
                    "error": .string((error as? LocalizedError)?.errorDescription ?? String(describing: error)),
                ]
            )
        }
    }

    // MARK: Gateway Payload Parsing

    private func decodePayload<T: Decodable>(_ type: T.Type, from payload: JSONValue?) throws -> T {
        guard let payload else {
            throw GatewayError.missingPayload
        }
        let data = try encoder.encode(payload)
        return try decoder.decode(type, from: data)
    }

    private func parseHeartbeatInterval(from payload: JSONValue?) throws -> UInt64 {
        guard case let .object(object)? = payload else {
            throw GatewayError.missingPayload
        }

        guard let heartbeatValue = object["heartbeat_interval"] else {
            throw GatewayError.missingHeartbeatInterval
        }

        switch heartbeatValue {
        case let .integer(value):
            return UInt64(value) * 1_000_000
        case let .number(value):
            return UInt64(value) * 1_000_000
        case let .string(value):
            guard let parsed = Double(value) else {
                throw GatewayError.invalidHeartbeatInterval
            }
            return UInt64(parsed) * 1_000_000
        default:
            throw GatewayError.invalidHeartbeatInterval
        }
    }

    private func parseReadyPayload(from payload: JSONValue?) throws -> DiscordGatewayReady {
        guard case let .object(object)? = payload else {
            throw GatewayError.missingPayload
        }

        guard let session_id = stringValue(from: object["session_id"]) else {
            throw GatewayError.missingSessionID
        }

        guard let resume_gateway_url = stringValue(from: object["resume_gateway_url"]) else {
            throw GatewayError.missingResumeGatewayURL
        }

        return DiscordGatewayReady(session_id: session_id, resume_gateway_url: resume_gateway_url)
    }

    private func stringValue(from value: JSONValue?) -> String? {
        switch value {
        case let .string(string):
            return string
        case let .integer(number):
            return String(number)
        case let .number(number):
            if number.rounded() == number {
                return String(Int(number))
            }
            return String(number)
        default:
            return nil
        }
    }

    private static func defaultReconnectDelaySeconds(forAttempt attempt: Int) -> Double {
        let exponential = min(pow(2.0, Double(attempt)), 30.0)
        let jitter = Double.random(in: 0 ... 0.5)
        return attempt == 0 ? 0.5 + jitter : exponential + jitter
    }
}

enum GatewayError: LocalizedError {
    case encodingFailed
    case missingPayload
    case missingHeartbeatInterval
    case invalidHeartbeatInterval
    case missingSessionID
    case missingResumeGatewayURL

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "DiscordGatewayClient.send: the bot could not encode a Discord Gateway payload before sending it. The most likely cause is an unexpected value in the outbound payload dictionary."
        case .missingPayload:
            return "DiscordGatewayClient.handle: Discord sent a Gateway event without the expected payload body. The most likely cause is an unexpected event shape from the Gateway."
        case .missingHeartbeatInterval:
            return "DiscordGatewayClient.parseHeartbeatInterval: the Discord HELLO event did not include `heartbeat_interval`, so the bot does not know how often to heartbeat. The most likely cause is an unexpected Gateway payload shape."
        case .invalidHeartbeatInterval:
            return "DiscordGatewayClient.parseHeartbeatInterval: the Discord HELLO event included an unreadable `heartbeat_interval`, so the bot could not start heartbeating. The most likely cause is an unexpected Gateway payload value."
        case .missingSessionID:
            return "DiscordGatewayClient.parseReadyPayload: the Discord READY event did not include `session_id`, so the bot cannot resume this session later. The most likely cause is an unexpected READY payload shape."
        case .missingResumeGatewayURL:
            return "DiscordGatewayClient.parseReadyPayload: the Discord READY event did not include `resume_gateway_url`, so the bot cannot resume this session later. The most likely cause is an unexpected READY payload shape."
        }
    }
}

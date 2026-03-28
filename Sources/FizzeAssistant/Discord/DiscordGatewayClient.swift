import Foundation
import Logging

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

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
    private let session = URLSession(configuration: .ephemeral)

    private var webSocketTask: URLSessionWebSocketTask?
    private var heartbeatTask: Task<Void, Never>?
    private var receiveTask: Task<Void, Never>?
    private var sequenceNumber: Int?
    private var sessionID: String?
    private var resumeURL: URL?
    private var heartbeatIntervalNanoseconds: UInt64 = 30_000_000_000
    private var awaitingHeartbeatACK = false
    private var isRunning = false

    // MARK: Lifecycle

    init(
        token: String,
        gatewayURL: URL,
        intents: Int,
        logger: Logger,
        onEvent: @escaping @Sendable (Event) async -> Void
    ) {
        self.token = token
        self.gatewayURL = gatewayURL
        self.intents = intents
        self.logger = logger
        self.onEvent = onEvent

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        self.decoder = decoder

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        self.encoder = encoder
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
        logger.info("Connecting to Discord Gateway.", metadata: ["url": .string(url.absoluteString)])

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()

        receiveTask?.cancel()
        receiveTask = Task { [weak self] in
            await self?.receiveLoop()
        }
    }

    private func reconnect() async {
        guard isRunning else { return }

        heartbeatTask?.cancel()
        receiveTask?.cancel()
        webSocketTask?.cancel(with: .goingAway, reason: nil)

        let targetURL = resumeURL ?? gatewayURL
        do {
            try await connect(using: targetURL)
        } catch {
            logger.error("Failed to reconnect to Discord Gateway.", metadata: ["error": .string(String(describing: error))])
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
                    logger.warning("Received unsupported WebSocket message type.")
                }
            } catch is CancellationError {
                return
            } catch {
                logger.error("Gateway receive failed; reconnecting.", metadata: ["error": .string(String(describing: error))])
                await reconnect()
                return
            }
        }
    }

    private func handle(messageData: Data) async throws {
        let envelope = try decoder.decode(DiscordGatewayEnvelope.self, from: messageData)
        sequenceNumber = envelope.s ?? sequenceNumber

        switch envelope.op {
        case DiscordGatewayOpCode.hello:
            let hello = try decodePayload(DiscordHello.self, from: envelope.d)
            heartbeatIntervalNanoseconds = UInt64(hello.heartbeatInterval) * 1_000_000
            heartbeatTask?.cancel()
            heartbeatTask = Task { [weak self] in
                await self?.heartbeatLoop()
            }
            try await sendIdentifyOrResume()

        case DiscordGatewayOpCode.dispatch:
            try await handleDispatch(eventName: envelope.t, payload: envelope.d)

        case DiscordGatewayOpCode.reconnect:
            await reconnect()

        case DiscordGatewayOpCode.invalidSession:
            sessionID = nil
            resumeURL = nil
            await reconnect()

        case DiscordGatewayOpCode.heartbeatAck:
            awaitingHeartbeatACK = false

        default:
            break
        }
    }

    private func heartbeatLoop() async {
        while isRunning {
            do {
                if awaitingHeartbeatACK {
                    logger.warning("Heartbeat ACK timed out; reconnecting.")
                    await reconnect()
                    return
                }

                awaitingHeartbeatACK = true
                try await send(payload: [
                    "op": .number(Double(DiscordGatewayOpCode.heartbeat)),
                    "d": sequenceNumber.map { .number(Double($0)) } ?? .null,
                ])

                try await Task.sleep(nanoseconds: heartbeatIntervalNanoseconds)
            } catch is CancellationError {
                return
            } catch {
                logger.error("Heartbeat failed.", metadata: ["error": .string(String(describing: error))])
                await reconnect()
                return
            }
        }
    }

    private func sendIdentifyOrResume() async throws {
        if let sessionID, let resumeURL {
            self.resumeURL = resumeURL
            try await send(payload: [
                "op": .number(Double(DiscordGatewayOpCode.resume)),
                "d": .object([
                    "token": .string(token),
                    "session_id": .string(sessionID),
                    "seq": sequenceNumber.map { .number(Double($0)) } ?? .null,
                ]),
            ])
            return
        }

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
            let ready = try decodePayload(DiscordGatewayReady.self, from: payload)
            sessionID = ready.sessionID
            resumeURL = URL(string: "\(ready.resumeGatewayURL)?v=10&encoding=json")

        case "GUILD_MEMBER_ADD":
            let event = try decodePayload(DiscordGuildMemberAddEvent.self, from: payload)
            await onEvent(.memberJoined(event))

        case "GUILD_MEMBER_REMOVE":
            let event = try decodePayload(DiscordGuildMemberRemoveEvent.self, from: payload)
            await onEvent(.memberRemoved(event))

        case "GUILD_BAN_ADD":
            let event = try decodePayload(DiscordGuildBanAddEvent.self, from: payload)
            await onEvent(.memberBanned(event))

        case "INTERACTION_CREATE":
            let event = try decodePayload(DiscordInteraction.self, from: payload)
            await onEvent(.interaction(event))

        case "MESSAGE_CREATE":
            let event = try decodePayload(DiscordMessageEvent.self, from: payload)
            await onEvent(.message(event))

        default:
            break
        }
    }

    private func decodePayload<T: Decodable>(_ type: T.Type, from payload: JSONValue?) throws -> T {
        guard let payload else {
            throw GatewayError.missingPayload
        }
        let data = try encoder.encode(payload)
        return try decoder.decode(type, from: data)
    }
}

enum GatewayError: LocalizedError {
    case encodingFailed
    case missingPayload

    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode a Gateway payload."
        case .missingPayload:
            return "Missing Gateway payload."
        }
    }
}

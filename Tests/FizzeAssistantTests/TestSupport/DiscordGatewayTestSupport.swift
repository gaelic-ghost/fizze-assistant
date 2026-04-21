import Foundation
import Testing
@testable import FizzeAssistant

final class StubDiscordGatewaySocket: @unchecked Sendable, DiscordGatewaySocket {
    private let lock = NSLock()

    enum ReceiveStep {
        case message(URLSessionWebSocketTask.Message)
        case error(Error)
    }

    private var receiveSteps: [ReceiveStep]
    private var sentMessages: [URLSessionWebSocketTask.Message] = []
    private(set) var resumeCount = 0
    private(set) var cancelCount = 0

    init(receiveSteps: [ReceiveStep] = []) {
        self.receiveSteps = receiveSteps
    }

    func resume() {
        lock.withLock {
            resumeCount += 1
        }
    }

    func cancel(with closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        lock.withLock {
            cancelCount += 1
        }
    }

    func send(_ message: URLSessionWebSocketTask.Message) async throws {
        lock.withLock {
            sentMessages.append(message)
        }
    }

    func receive() async throws -> URLSessionWebSocketTask.Message {
        try lock.withLock {
            guard !receiveSteps.isEmpty else {
                throw CancellationError()
            }
            let step = receiveSteps.removeFirst()
            switch step {
            case let .message(message):
                return message
            case let .error(error):
                throw error
            }
        }
    }

    func sentPayloadObjects() async throws -> [[String: JSONValue]] {
        let messages = lock.withLock { sentMessages }
        return try messages.map { message in
            guard case let .string(text) = message else {
                throw UserFacingError("StubDiscordGatewaySocket.sentPayloadObjects: expected outbound Gateway payloads to be encoded as text frames.")
            }
            return try JSONDecoder().decode([String: JSONValue].self, from: Data(text.utf8))
        }
    }
}

final class StubDiscordGatewaySocketFactory: @unchecked Sendable {
    private let lock = NSLock()
    private var sockets: [StubDiscordGatewaySocket]
    private var _requestedURLs: [URL] = []

    init(sockets: [StubDiscordGatewaySocket]) {
        self.sockets = sockets
    }

    func makeSocket(url: URL) -> any DiscordGatewaySocket {
        lock.withLock {
            _requestedURLs.append(url)
            if sockets.isEmpty {
                return StubDiscordGatewaySocket()
            }
            return sockets.removeFirst()
        }
    }

    var requestedURLs: [URL] {
        lock.withLock { _requestedURLs }
    }
}

func eventually(
    timeout: Duration = .seconds(1),
    pollInterval: Duration = .milliseconds(10),
    _ predicate: @escaping @Sendable () async throws -> Bool
) async throws {
    let start = ContinuousClock.now
    while try await !predicate() {
        if start.duration(to: .now) > timeout {
            Issue.record("Timed out waiting for asynchronous test condition.")
            return
        }
        try await Task.sleep(for: pollInterval)
    }
}

func gatewayMessage(_ json: String) -> URLSessionWebSocketTask.Message {
    .string(json)
}

actor GatewayEventRecorder {
    private var events: [DiscordGatewayClient.Event] = []

    func append(_ event: DiscordGatewayClient.Event) {
        events.append(event)
    }

    func snapshot() -> [DiscordGatewayClient.Event] {
        events
    }
}

actor AsyncGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        if isOpen {
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func open() {
        isOpen = true
        let pendingWaiters = waiters
        waiters.removeAll()
        for waiter in pendingWaiters {
            waiter.resume()
        }
    }
}

func gatewayOpcode(_ value: JSONValue?) -> Int? {
    switch value {
    case let .integer(number)?:
        return Int(number)
    case let .number(number)?:
        return Int(number)
    default:
        return nil
    }
}

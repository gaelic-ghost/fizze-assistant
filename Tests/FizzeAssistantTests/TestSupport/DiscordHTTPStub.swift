import Foundation
import Logging
import Testing
@testable import FizzeAssistant

final class DiscordHTTPStubURLProtocol: URLProtocol, @unchecked Sendable {
    // MARK: Stored Properties

    private static let lock = NSLock()
    nonisolated(unsafe) private static var handlersByHost: [String: (URLRequest) throws -> (HTTPURLResponse, Data)] = [:]
    nonisolated(unsafe) private static var requestsByHost: [String: [URLRequest]] = [:]

    // MARK: URLProtocol

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host?.hasSuffix(".discord.test") == true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let host = request.url?.host else {
            client?.urlProtocol(self, didFailWithError: UserFacingError("DiscordHTTPStubURLProtocol.startLoading: missing host on stubbed request URL."))
            return
        }

        Self.lock.lock()
        let handler = Self.handlersByHost[host]
        Self.requestsByHost[host, default: []].append(request)
        Self.lock.unlock()

        do {
            guard let handler else {
                throw UserFacingError("DiscordHTTPStubURLProtocol.startLoading: no request handler was configured for host `\(host)`.")
            }

            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    // MARK: Stub Management

    static func install(host: String, handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) {
        lock.lock()
        defer { lock.unlock() }
        handlersByHost[host] = handler
        requestsByHost[host] = []
    }

    static func requests(for host: String) -> [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return requestsByHost[host] ?? []
    }
}

struct StubbedDiscordRESTClient {
    // MARK: Stored Properties

    let client: DiscordRESTClient
    let host: String

    // MARK: Public API

    func requests() -> [URLRequest] {
        DiscordHTTPStubURLProtocol.requests(for: host)
    }
}

func makeDiscordRESTClient(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> StubbedDiscordRESTClient {
    let host = "discord-\(UUID().uuidString.lowercased()).discord.test"
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [DiscordHTTPStubURLProtocol.self]
    DiscordHTTPStubURLProtocol.install(host: host, handler: handler)

    return StubbedDiscordRESTClient(
        client: DiscordRESTClient(
            token: "token",
            logger: .init(label: "test"),
            session: URLSession(configuration: configuration),
            baseURL: URL(string: "https://\(host)/api/v10")!
        ),
        host: host
    )
}

func decodeRequestBody<T: Decodable>(_ type: T.Type, from request: URLRequest) throws -> T {
    try JSONDecoder().decode(T.self, from: try requestBodyData(from: request))
}

private func requestBodyData(from request: URLRequest) throws -> Data {
    if let body = request.httpBody {
        return body
    }

    guard let stream = request.httpBodyStream else {
        throw UserFacingError("DiscordHTTPStub.requestBodyData: the stubbed request did not include an HTTP body or body stream.")
    }

    stream.open()
    defer { stream.close() }

    let bufferSize = 1_024
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }

    var data = Data()
    while stream.hasBytesAvailable {
        let bytesRead = stream.read(buffer, maxLength: bufferSize)
        if bytesRead < 0 {
            throw stream.streamError ?? UserFacingError("DiscordHTTPStub.requestBodyData: the stubbed request body stream failed while being read for test inspection.")
        }
        if bytesRead == 0 {
            break
        }
        data.append(buffer, count: bytesRead)
    }

    return data
}

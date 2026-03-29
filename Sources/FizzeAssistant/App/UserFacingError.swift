import Foundation

struct UserFacingError: LocalizedError, Sendable {
    // MARK: Stored Properties

    let message: String

    // MARK: Lifecycle

    init(_ message: String) {
        self.message = message
    }

    // MARK: LocalizedError

    var errorDescription: String? {
        message
    }
}

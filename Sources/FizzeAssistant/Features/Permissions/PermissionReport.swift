import Foundation

struct PermissionReport: Sendable {
    struct Issue: Hashable, Sendable {
        enum Severity: String, Sendable {
            case info = "INFO"
            case warning = "WARN"
        }

        var severity: Severity
        var message: String
    }

    // MARK: Stored Properties

    var issues: [Issue]

    // MARK: Public API

    func renderText() -> String {
        let warningCount = issues.filter { $0.severity == .warning }.count
        let statusLine = if warningCount == 0 {
            "Startup looks good."
        } else {
            "Startup can continue. The warnings below can be fixed from Discord whenever you're ready."
        }
        let lines = issues.map { "[\($0.severity.rawValue)] \($0.message)" }
        return (["Fizze Assistant setup report:", statusLine] + lines).joined(separator: "\n")
    }
}

import Foundation
import Testing
@testable import FizzeAssistant

struct PermissionReportTests {
    @Test
    func blockingIssuesAreDetected() {
        let report = PermissionReport(issues: [
            .init(severity: .info, message: "hello"),
            .init(severity: .blocking, message: "bad"),
        ])

        #expect(report.hasBlockingIssue)
        #expect(report.renderText().contains("BLOCKING"))
    }
}

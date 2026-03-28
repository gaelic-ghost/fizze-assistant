import Foundation
import Testing
@testable import FizzeAssistant

struct PermissionReportTests {
    @Test
    func setupReportUsesFriendlyWarningLanguage() {
        let report = PermissionReport(issues: [
            .init(severity: .info, message: "hello"),
            .init(severity: .warning, message: "Heads up"),
        ])

        #expect(report.renderText().contains("Startup can continue."))
        #expect(report.renderText().contains("WARN"))
    }
}

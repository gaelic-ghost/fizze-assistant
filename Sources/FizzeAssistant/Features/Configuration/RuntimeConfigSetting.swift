import Foundation

enum RuntimeConfigSetting: String, CaseIterable, Sendable {
    // MARK: Cases

    case welcome_channel_id = "welcome_channel_id"
    case leave_channel_id = "leave_channel_id"
    case mod_log_channel_id = "mod_log_channel_id"
    case suggestions_channel_id = "suggestions_channel_id"
    case warn_users_via_dm = "warn_users_via_dm"
    case welcome_message = "welcome_message"
    case voluntary_leave_message = "voluntary_leave_message"
    case kick_message = "kick_message"
    case ban_message = "ban_message"
    case unknown_removal_message = "unknown_removal_message"
    case role_assignment_failure_message = "role_assignment_failure_message"
    case warning_dm_template = "warning_dm_template"
    case trigger_cooldown_seconds = "trigger_cooldown_seconds"
    case leave_audit_log_lookback_seconds = "leave_audit_log_lookback_seconds"

    // MARK: Public API

    static var allowedKeysText: String {
        allCases.map(\.rawValue).joined(separator: ", ")
    }
}

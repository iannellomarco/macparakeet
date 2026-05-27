import Foundation
import MacParakeetCore

public enum JournalCaptureInterval: Int, CaseIterable, Sendable {
    case seconds30 = 30
    case minute1 = 60
    case minutes2 = 120
    case minutes5 = 300
    case minutes10 = 600

    public var label: String {
        switch self {
        case .seconds30: return "30 seconds"
        case .minute1: return "1 minute"
        case .minutes2: return "2 minutes"
        case .minutes5: return "5 minutes"
        case .minutes10: return "10 minutes"
        }
    }
}

public enum JournalAnalysisInterval: Int, CaseIterable, Sendable {
    case minutes15 = 15
    case minutes30 = 30
    case minutes60 = 60

    public var label: String {
        switch self {
        case .minutes15: return "15 minutes"
        case .minutes30: return "30 minutes"
        case .minutes60: return "60 minutes"
        }
    }
}

public enum JournalRetention: Int, CaseIterable, Sendable {
    case days7 = 7
    case days30 = 30
    case days90 = 90
    case forever = 0

    public var label: String {
        switch self {
        case .days7: return "7 days"
        case .days30: return "30 days"
        case .days90: return "90 days"
        case .forever: return "Forever"
        }
    }
}

public enum JournalIdleThreshold: Int, CaseIterable, Sendable {
    case seconds30 = 30
    case seconds60 = 60
    case seconds120 = 120

    public var label: String {
        switch self {
        case .seconds30: return "30 seconds"
        case .seconds60: return "1 minute"
        case .seconds120: return "2 minutes"
        }
    }
}

private enum JournalDefaults {
    static let captureIntervalKey = "journal_capture_interval_secs"
    static let analysisIntervalKey = "journal_analysis_interval_mins"
    static let idleSkipEnabledKey = "journal_idle_skip_enabled"
    static let idleThresholdKey = "journal_idle_threshold_secs"
    static let retentionDaysKey = "journal_retention_days"
}

@Observable
public final class JournalSettingsViewModel {
    public var captureInterval: JournalCaptureInterval = .minutes2
    public var analysisInterval: JournalAnalysisInterval = .minutes30
    public var idleSkipEnabled: Bool = false
    public var idleThreshold: JournalIdleThreshold = .seconds120
    public var retention: JournalRetention = .days30
    public var hasScreenRecordingPermission: Bool = false

    private let permissionService: PermissionServiceProtocol
    private let defaults: UserDefaults

    public init(
        permissionService: PermissionServiceProtocol = PermissionService(),
        defaults: UserDefaults = .standard
    ) {
        self.permissionService = permissionService
        self.defaults = defaults
        loadSettings()
        refreshPermissions()
    }

    private func loadSettings() {
        let rawCapture = defaults.integer(forKey: JournalDefaults.captureIntervalKey)
        if rawCapture > 0, let interval = JournalCaptureInterval(rawValue: rawCapture) {
            captureInterval = interval
        }

        let rawAnalysis = defaults.integer(forKey: JournalDefaults.analysisIntervalKey)
        if rawAnalysis > 0, let interval = JournalAnalysisInterval(rawValue: rawAnalysis) {
            analysisInterval = interval
        }

        idleSkipEnabled = defaults.bool(forKey: JournalDefaults.idleSkipEnabledKey)

        let rawThreshold = defaults.integer(forKey: JournalDefaults.idleThresholdKey)
        if rawThreshold > 0, let threshold = JournalIdleThreshold(rawValue: rawThreshold) {
            idleThreshold = threshold
        }

        let rawRetention = defaults.integer(forKey: JournalDefaults.retentionDaysKey)
        if let retention = JournalRetention(rawValue: rawRetention) {
            self.retention = retention
        }
    }

    public func saveCaptureInterval(_ interval: JournalCaptureInterval) {
        captureInterval = interval
        defaults.set(interval.rawValue, forKey: JournalDefaults.captureIntervalKey)
    }

    public func saveAnalysisInterval(_ interval: JournalAnalysisInterval) {
        analysisInterval = interval
        defaults.set(interval.rawValue, forKey: JournalDefaults.analysisIntervalKey)
    }

    public func saveIdleSkipEnabled(_ enabled: Bool) {
        idleSkipEnabled = enabled
        defaults.set(enabled, forKey: JournalDefaults.idleSkipEnabledKey)
    }

    public func saveIdleThreshold(_ threshold: JournalIdleThreshold) {
        idleThreshold = threshold
        defaults.set(threshold.rawValue, forKey: JournalDefaults.idleThresholdKey)
    }

    public func saveRetention(_ retention: JournalRetention) {
        self.retention = retention
        defaults.set(retention.rawValue, forKey: JournalDefaults.retentionDaysKey)
    }

    public func refreshPermissions() {
        hasScreenRecordingPermission = permissionService.checkScreenRecordingPermission()
    }

    public func requestScreenRecordingPermission() -> Bool {
        let granted = permissionService.requestScreenRecordingPermission()
        hasScreenRecordingPermission = granted
        return granted
    }
}

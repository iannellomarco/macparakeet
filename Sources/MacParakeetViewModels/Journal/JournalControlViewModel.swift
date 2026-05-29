import Foundation
import MacParakeetCore
import OSLog

@MainActor @Observable
public final class JournalControlViewModel {
    public var isJournaling: Bool = false
    public var isReviewing: Bool = false
    public var isComputing: Bool = false
    public var activeSessionId: UUID?
    public var screenshotCount: Int = 0
    public var lastAnalysisAt: Date?
    public var elapsedSeconds: Int = 0
    /// Set when a start attempt was blocked because Screen Recording permission
    /// is missing — the tile surfaces a prompt instead of silently capturing nothing.
    public var needsScreenRecordingPermission: Bool = false

    public var onReviewStarted: (@MainActor (UUID) -> Void)?
    public var onSessionFinalized: (@MainActor () -> Void)?

    /// Call this from outside to trigger a library reload after finalization.
    public var onLibraryRefreshNeeded: (@MainActor () -> Void)?

    private var journalService: JournalServiceProtocol?
    private var permissionService: PermissionServiceProtocol?
    private weak var settingsViewModel: JournalSettingsViewModel?
    private var captureIntervalSecs: Int = 120
    private var analysisIntervalMins: Int = 30
    private var idleSkipEnabled: Bool = false
    private var idleThresholdSecs: Int = 120
    private var retentionDays: Int = 30
    private var elapsedTimer: Timer?

    private let logger = Logger(
        subsystem: "com.macparakeet.viewmodels",
        category: "JournalControl"
    )

    public init() {}

    public func configure(
        journalService: JournalServiceProtocol?,
        captureIntervalSecs: Int = 120,
        analysisIntervalMins: Int = 30,
        idleSkipEnabled: Bool = false,
        idleThresholdSecs: Int = 120,
        retentionDays: Int = 30,
        permissionService: PermissionServiceProtocol? = nil,
        settingsViewModel: JournalSettingsViewModel? = nil
    ) {
        self.journalService = journalService
        self.captureIntervalSecs = captureIntervalSecs
        self.analysisIntervalMins = analysisIntervalMins
        self.idleSkipEnabled = idleSkipEnabled
        self.idleThresholdSecs = idleThresholdSecs
        self.retentionDays = retentionDays
        self.permissionService = permissionService
        self.settingsViewModel = settingsViewModel
    }

    public func startJournaling() async {
        guard let service = journalService, !isJournaling else { return }

        // Gate on Screen Recording permission — without it captureAllDisplays()
        // returns nothing and the user would record a whole empty session.
        if let permission = permissionService, !permission.checkScreenRecordingPermission() {
            let granted = permission.requestScreenRecordingPermission()
            guard granted else {
                needsScreenRecordingPermission = true
                logger.error("Screen Recording permission denied; not starting journal")
                return
            }
        }
        needsScreenRecordingPermission = false

        // Read settings live so changes made in Settings after launch take effect.
        let captureSecs = settingsViewModel?.captureInterval.rawValue ?? captureIntervalSecs
        let analysisMins = settingsViewModel?.analysisInterval.rawValue ?? analysisIntervalMins
        let idleSkip = settingsViewModel?.idleSkipEnabled ?? idleSkipEnabled
        let idleThresh = settingsViewModel?.idleThreshold.rawValue ?? idleThresholdSecs
        let retention = settingsViewModel?.retention.rawValue ?? retentionDays

        // Sweep screenshots that have aged past the retention policy before
        // starting a new day's captures.
        await service.enforceRetention(retentionDays: retention)
        do {
            let session = try await service.startSession(
                captureIntervalSecs: captureSecs,
                analysisIntervalMins: analysisMins,
                idleSkipEnabled: idleSkip,
                idleThresholdSecs: idleThresh
            )
            activeSessionId = session.id
            isJournaling = true
            isReviewing = false
            screenshotCount = 0
            elapsedSeconds = 0
            startElapsedTimer()
            logger.info("Journaling started: \(session.id)")
        } catch {
            logger.error("Failed to start journaling: \(error.localizedDescription)")
        }
    }

    public func stopJournaling() async {
        guard let service = journalService, isJournaling else { return }
        isComputing = true
        do {
            let session = try await service.stopSession()
            isJournaling = false
            isComputing = false
            isReviewing = true
            stopElapsedTimer()
            onReviewStarted?(session.id)
            logger.info("Journaling stopped, entering review")
        } catch {
            isComputing = false
            logger.error("Failed to stop journaling: \(error.localizedDescription)")
        }
    }

    public func cancelJournaling() async {
        // Discard is valid while recording OR while reviewing (the chat panel's
        // discard fires after the session has moved to .reviewing).
        guard let service = journalService, isJournaling || isReviewing else { return }
        do {
            try await service.cancelSession()
            resetState()
            logger.info("Journaling cancelled")
        } catch {
            logger.error("Failed to cancel journaling: \(error.localizedDescription)")
        }
    }

    public func finalizeSession(userNotes: String) async {
        guard let service = journalService, isReviewing else { return }
        isComputing = true
        do {
            _ = try await service.finalizeSession(userNotes: userNotes)
            isComputing = false
            resetState()
            onSessionFinalized?()
            onLibraryRefreshNeeded?()
            logger.info("Journal session finalized")
        } catch {
            isComputing = false
            logger.error("Failed to finalize session: \(error.localizedDescription)")
        }
    }

    private func resetState() {
        isJournaling = false
        isReviewing = false
        isComputing = false
        activeSessionId = nil
        screenshotCount = 0
        elapsedSeconds = 0
        lastAnalysisAt = nil
        stopElapsedTimer()
    }

    private func startElapsedTimer() {
        stopElapsedTimer()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.elapsedSeconds += 1
                // Reflect the live capture count from the service (the actor owns
                // the counter; the VM mirrors it for the recording tile).
                if let service = self.journalService {
                    self.screenshotCount = await service.currentScreenshotCount
                }
            }
        }
        // Ensure timer fires during menu tracking
        if let timer = elapsedTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopElapsedTimer() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }
}

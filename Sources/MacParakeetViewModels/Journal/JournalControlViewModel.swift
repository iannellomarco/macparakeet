import Foundation
import MacParakeetCore
import OSLog

@MainActor @Observable
public final class JournalControlViewModel {
    public var isJournaling: Bool = false
    public var isReviewing: Bool = false
    public var activeSessionId: UUID?
    public var screenshotCount: Int = 0
    public var lastAnalysisAt: Date?
    public var elapsedSeconds: Int = 0

    public var onReviewStarted: (@MainActor (UUID) -> Void)?
    public var onSessionFinalized: (@MainActor () -> Void)?

    private var journalService: JournalServiceProtocol?
    private var captureIntervalSecs: Int = 120
    private var analysisIntervalMins: Int = 30
    private var idleSkipEnabled: Bool = false
    private var idleThresholdSecs: Int = 120
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
        idleThresholdSecs: Int = 120
    ) {
        self.journalService = journalService
        self.captureIntervalSecs = captureIntervalSecs
        self.analysisIntervalMins = analysisIntervalMins
        self.idleSkipEnabled = idleSkipEnabled
        self.idleThresholdSecs = idleThresholdSecs
    }

    public func startJournaling() async {
        guard let service = journalService, !isJournaling else { return }
        do {
            let session = try await service.startSession(
                captureIntervalSecs: captureIntervalSecs,
                analysisIntervalMins: analysisIntervalMins,
                idleSkipEnabled: idleSkipEnabled,
                idleThresholdSecs: idleThresholdSecs
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
        do {
            let session = try await service.stopSession()
            isJournaling = false
            isReviewing = true
            stopElapsedTimer()
            onReviewStarted?(session.id)
            logger.info("Journaling stopped, entering review")
        } catch {
            logger.error("Failed to stop journaling: \(error.localizedDescription)")
        }
    }

    public func cancelJournaling() async {
        guard let service = journalService, isJournaling else { return }
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
        do {
            _ = try await service.finalizeSession(userNotes: userNotes)
            resetState()
            onSessionFinalized?()
            logger.info("Journal session finalized")
        } catch {
            logger.error("Failed to finalize session: \(error.localizedDescription)")
        }
    }

    private func resetState() {
        isJournaling = false
        isReviewing = false
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
                self?.elapsedSeconds += 1
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

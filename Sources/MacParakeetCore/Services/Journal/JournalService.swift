import Foundation
import OSLog

// MARK: - Journal State

public enum JournalState: Sendable, Equatable {
    case idle
    case recording(sessionId: UUID)
    case reviewing(sessionId: UUID)
}

// MARK: - Protocol

public protocol JournalServiceProtocol: Sendable {
    var currentState: JournalState { get async }

    func startSession(
        captureIntervalSecs: Int,
        analysisIntervalMins: Int,
        idleSkipEnabled: Bool,
        idleThresholdSecs: Int
    ) async throws -> JournalSession

    func stopSession() async throws -> JournalSession
    func cancelSession() async throws
    func startReview() async throws -> JournalSession
    func finalizeSession(userNotes: String) async throws -> JournalSession
}

// MARK: - Implementation

public actor JournalService: JournalServiceProtocol {
    private let captureService: ScreenshotCaptureServiceProtocol
    private let ocrService: ScreenshotOCRServiceProtocol
    private let batchAnalyzer: JournalBatchAnalyzerProtocol
    private let idleDetector: JournalIdleDetectorProtocol
    private let storageManager: JournalStorageManagerProtocol
    private let sessionRepo: JournalSessionRepositoryProtocol
    private let screenshotRepo: JournalScreenshotRepositoryProtocol

    public private(set) var currentState: JournalState = .idle

    private var captureTask: Task<Void, Never>?
    private var analysisTask: Task<Void, Never>?

    private static let logger = Logger(
        subsystem: "com.macparakeet.core",
        category: "Journal"
    )

    public init(
        captureService: ScreenshotCaptureServiceProtocol,
        ocrService: ScreenshotOCRServiceProtocol,
        batchAnalyzer: JournalBatchAnalyzerProtocol,
        idleDetector: JournalIdleDetectorProtocol,
        storageManager: JournalStorageManagerProtocol,
        sessionRepo: JournalSessionRepositoryProtocol,
        screenshotRepo: JournalScreenshotRepositoryProtocol
    ) {
        self.captureService = captureService
        self.ocrService = ocrService
        self.batchAnalyzer = batchAnalyzer
        self.idleDetector = idleDetector
        self.storageManager = storageManager
        self.sessionRepo = sessionRepo
        self.screenshotRepo = screenshotRepo
    }

    // MARK: - Start

    public func startSession(
        captureIntervalSecs: Int,
        analysisIntervalMins: Int,
        idleSkipEnabled: Bool,
        idleThresholdSecs: Int
    ) async throws -> JournalSession {
        // Only one session at a time
        guard case .idle = currentState else {
            throw JournalError.sessionAlreadyActive
        }

        let session = JournalSession(
            status: .recording,
            captureIntervalSecs: captureIntervalSecs,
            analysisIntervalMins: analysisIntervalMins
        )
        try sessionRepo.save(session)
        currentState = .recording(sessionId: session.id)

        // Start capture loop
        let sessionId = session.id
        captureTask = Task { [weak self] in
            await self?.runCaptureLoop(
                sessionId: sessionId,
                intervalSecs: captureIntervalSecs,
                idleSkipEnabled: idleSkipEnabled,
                idleThresholdSecs: idleThresholdSecs
            )
        }

        // Start analysis loop
        analysisTask = Task { [weak self] in
            await self?.runAnalysisLoop(
                sessionId: sessionId,
                intervalMins: analysisIntervalMins
            )
        }

        Self.logger.info("Journal session started: \(sessionId)")
        return session
    }

    // MARK: - Stop

    public func stopSession() async throws -> JournalSession {
        guard case .recording(let sessionId) = currentState else {
            throw JournalError.noSessionActive
        }

        // Cancel loops
        captureTask?.cancel()
        analysisTask?.cancel()
        captureTask = nil
        analysisTask = nil

        // Run a final catch-up analysis
        do {
            _ = try await batchAnalyzer.analyzeBatch(sessionId: sessionId)
        } catch {
            Self.logger.warning(
                "Final batch analysis failed (non-fatal): \(error.localizedDescription)"
            )
        }

        // Transition to reviewing
        try sessionRepo.updateStatus(
            id: sessionId,
            status: .reviewing,
            endedAt: nil
        )
        currentState = .reviewing(sessionId: sessionId)

        guard let session = try sessionRepo.fetch(id: sessionId) else {
            throw JournalError.sessionNotFound(sessionId)
        }

        Self.logger.info("Journal session stopped, entering review: \(sessionId)")
        return session
    }

    // MARK: - Cancel (discard all data)

    public func cancelSession() async throws {
        guard case .recording(let sessionId) = currentState else {
            throw JournalError.noSessionActive
        }

        captureTask?.cancel()
        analysisTask?.cancel()
        captureTask = nil
        analysisTask = nil

        // Delete all screenshots from disk
        try storageManager.deleteSessionFolder(sessionId: sessionId)

        // DB cascade-deletes screenshots, analysis runs, and questions
        try sessionRepo.updateStatus(
            id: sessionId,
            status: .cancelled,
            endedAt: Date()
        )

        currentState = .idle
        Self.logger.info("Journal session cancelled and discarded: \(sessionId)")
    }

    // MARK: - Review

    public func startReview() async throws -> JournalSession {
        guard case .recording(let sessionId) = currentState else {
            throw JournalError.noSessionActive
        }

        // Same as stop — transition to reviewing
        return try await stopSession()
    }

    // MARK: - Finalize

    public func finalizeSession(userNotes: String) async throws -> JournalSession {
        guard case .reviewing(let sessionId) = currentState else {
            throw JournalError.noSessionActive
        }

        guard let session = try sessionRepo.fetch(id: sessionId) else {
            throw JournalError.sessionNotFound(sessionId)
        }

        // Generate final snapshot
        let finalText: String
        do {
            finalText = try await generateFinalSnapshot(
                session: session,
                userNotes: userNotes
            )
        } catch {
            Self.logger.error(
                "Final snapshot generation failed: \(error.localizedDescription)"
            )
            // Use running summary as fallback
            finalText = session.runningSummary
                ?? "Day journal from \(ISO8601DateFormatter().string(from: session.createdAt))"
        }

        try sessionRepo.updateFinalSnapshot(
            id: sessionId,
            text: finalText,
            userNotes: userNotes
        )
        try sessionRepo.updateStatus(
            id: sessionId,
            status: .completed,
            endedAt: Date()
        )

        currentState = .idle

        guard let finalized = try sessionRepo.fetch(id: sessionId) else {
            throw JournalError.sessionNotFound(sessionId)
        }

        Self.logger.info("Journal session finalized: \(sessionId)")
        return finalized
    }

    // MARK: - Capture Loop

    private func runCaptureLoop(
        sessionId: UUID,
        intervalSecs: Int,
        idleSkipEnabled: Bool,
        idleThresholdSecs: Int
    ) async {
        let intervalNanos = UInt64(intervalSecs) * 1_000_000_000

        while !Task.isCancelled {
            do {
                // Check idle
                if idleSkipEnabled, idleDetector.isUserIdle(thresholdSeconds: idleThresholdSecs) {
                    try await Task.sleep(nanoseconds: UInt64(intervalSecs) * 1_000_000_000)
                    continue
                }

                // Capture
                let captures = try await captureService.captureAllDisplays()

                for capture in captures {
                    // OCR
                    let ocrResult: OCRResult
                    do {
                        ocrResult = try await ocrService.extractText(from: capture.imageData)
                    } catch {
                        Self.logger.warning(
                            "OCR failed for screenshot \(capture.id): \(error.localizedDescription)"
                        )
                        continue
                    }

                    // Save image to disk
                    let fileURL = try storageManager.saveScreenshot(
                        id: capture.id,
                        imageData: capture.imageData,
                        sessionId: sessionId
                    )

                    // Save screenshot row
                    let screenshot = JournalScreenshot(
                        id: capture.id,
                        sessionId: sessionId,
                        capturedAt: capture.capturedAt,
                        filePath: fileURL.path,
                        ocrText: ocrResult.text.isEmpty ? nil : ocrResult.text,
                        ocrConfidence: ocrResult.text.isEmpty ? nil : Double(ocrResult.confidence),
                        fileSizeBytes: capture.imageData.count,
                        displayName: capture.displayName,
                        displayWidth: capture.displayWidth,
                        displayHeight: capture.displayHeight
                    )
                    try screenshotRepo.save(screenshot)

                    // Update session counters
                    try sessionRepo.incrementScreenshotCount(
                        id: sessionId,
                        storageBytes: capture.imageData.count
                    )
                }

                if !captures.isEmpty {
                    Self.logger.debug(
                        "Captured \(captures.count) screenshot(s) for session \(sessionId)"
                    )
                }
            } catch {
                if !(error is CancellationError) {
                    Self.logger.error(
                        "Capture cycle error: \(error.localizedDescription)"
                    )
                }
            }

            // Sleep until next capture
            do {
                try await Task.sleep(nanoseconds: intervalNanos)
            } catch {
                break // Task cancelled
            }
        }
    }

    // MARK: - Analysis Loop

    private func runAnalysisLoop(
        sessionId: UUID,
        intervalMins: Int
    ) async {
        let intervalNanos = UInt64(intervalMins) * 60 * 1_000_000_000

        // Initial delay — give screenshots time to accumulate
        do {
            try await Task.sleep(nanoseconds: UInt64(intervalMins) * 60 * 1_000_000_000)
        } catch {
            return
        }

        while !Task.isCancelled {
            do {
                let run = try await batchAnalyzer.analyzeBatch(sessionId: sessionId)
                if run.wasUsed {
                    Self.logger.debug(
                        "Analysis batch complete: \(run.screenshotCount) screenshots, \(run.latencyMs ?? 0)ms"
                    )
                }
            } catch {
                if !(error is CancellationError) {
                    Self.logger.error(
                        "Analysis cycle error: \(error.localizedDescription)"
                    )
                }
            }

            do {
                try await Task.sleep(nanoseconds: intervalNanos)
            } catch {
                break
            }
        }
    }

    // MARK: - Final Snapshot Generation

    private func generateFinalSnapshot(
        session: JournalSession,
        userNotes: String
    ) async throws -> String {
        if let runningSummary = session.runningSummary, !runningSummary.isEmpty {
            var finalText = "# Day Journal\n\n"
            let formatter = DateFormatter()
            formatter.dateStyle = .full
            finalText += "*\(formatter.string(from: session.createdAt))*\n\n"
            finalText += runningSummary

            if !userNotes.isEmpty {
                finalText += "\n\n## Additional Notes\n\n\(userNotes)"
            }
            return finalText
        }

        return "Day journal from \(ISO8601DateFormatter().string(from: session.createdAt))"
    }
}

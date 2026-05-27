import Foundation
import OSLog

// MARK: - Protocol

public protocol JournalBatchAnalyzerProtocol: Sendable {
    func analyzeBatch(sessionId: UUID) async throws -> JournalAnalysisRun
}

// MARK: - Implementation

public final class JournalBatchAnalyzer: JournalBatchAnalyzerProtocol {
    private let llmService: LLMServiceProtocol
    private let screenshotRepo: JournalScreenshotRepositoryProtocol
    private let analysisRunRepo: JournalAnalysisRunRepositoryProtocol
    private let questionTracker: JournalQuestionTrackerProtocol
    private let sessionRepo: JournalSessionRepositoryProtocol
    private let questionRepo: JournalQuestionRepositoryProtocol
    private let transcriptionRepo: TranscriptionRepositoryProtocol?

    private static let logger = Logger(
        subsystem: "com.macparakeet.core",
        category: "JournalBatch"
    )

    // Context budget for OCR text (characters). Sized conservatively so
    // the prompt + running summary + response all fit within the LLM's
    // context window. ~50K chars ≈ 14K tokens for English text.
    private static let ocrContextBudget = 50_000

    public init(
        llmService: LLMServiceProtocol,
        screenshotRepo: JournalScreenshotRepositoryProtocol,
        analysisRunRepo: JournalAnalysisRunRepositoryProtocol,
        questionTracker: JournalQuestionTrackerProtocol,
        sessionRepo: JournalSessionRepositoryProtocol,
        questionRepo: JournalQuestionRepositoryProtocol,
        transcriptionRepo: TranscriptionRepositoryProtocol? = nil
    ) {
        self.llmService = llmService
        self.screenshotRepo = screenshotRepo
        self.analysisRunRepo = analysisRunRepo
        self.questionTracker = questionTracker
        self.sessionRepo = sessionRepo
        self.questionRepo = questionRepo
        self.transcriptionRepo = transcriptionRepo
    }

    public func analyzeBatch(sessionId: UUID) async throws -> JournalAnalysisRun {
        let startTime = Date()

        // 1. Fetch the session for running summary and context
        guard let session = try sessionRepo.fetch(id: sessionId) else {
            throw JournalError.sessionNotFound(sessionId)
        }

        // 2. Fetch unanalyzed screenshots (since last analysis run)
        let lastRun = try analysisRunRepo.fetchLatest(sessionId: sessionId)
        let sinceDate = lastRun?.runAt ?? session.createdAt
        let screenshots = try screenshotRepo.fetchUnanalyzed(
            sessionId: sessionId,
            since: sinceDate
        )

        // 3. Nothing to analyze
        if screenshots.isEmpty {
            let emptyRun = JournalAnalysisRun(
                sessionId: sessionId,
                screenshotCount: 0,
                ocrTextInput: "",
                analysis: "",
                wasUsed: false
            )
            try analysisRunRepo.save(emptyRun)
            return emptyRun
        }

        // 4. Concatenate OCR text, capped at budget
        let ocrText = concatenateOCRText(from: screenshots)

        // 5. Fetch pending questions
        let pendingQuestions = try questionRepo.fetchPending(sessionId: sessionId)
        let questionsText = formatPendingQuestions(pendingQuestions)

        // 5b. Fetch same-day meeting transcripts for richer context
        let meetingContext = fetchSameDayMeetings(session: session)

        // 6. Call the dedicated journal analysis method
        let analysisText: String
        let latencyMs: Int
        do {
            let llmResult = try await llmService.analyzeJournal(
                ocrText: ocrText,
                runningSummary: session.runningSummary ?? "(No observations yet — this is the first analysis of the day.)",
                meetingContext: meetingContext,
                pendingQuestions: questionsText,
                screenshotCount: screenshots.count
            )
            analysisText = llmResult.output
            latencyMs = llmResult.latencyMs
        } catch {
            Self.logger.error("LLM analysis failed: \(error.localizedDescription)")
            // Save a failed run with empty analysis so we don't retry
            // the same screenshots on the next batch
            let failedRun = JournalAnalysisRun(
                sessionId: sessionId,
                screenshotCount: screenshots.count,
                ocrTextInput: ocrText,
                analysis: "",
                wasUsed: false
            )
            try analysisRunRepo.save(failedRun)
            throw error
        }

        // 8. Extract running summary from analysis output
        let extractedSummary = extractSection("Updated Running Summary", from: analysisText)

        // 9. Extract questions
        let questions = questionTracker.extractQuestions(from: analysisText)

        // 10. Encode questions as JSON for the analysis run row
        let questionsJSON: String?
        if !questions.isEmpty,
           let data = try? JSONEncoder().encode(questions),
           let json = String(data: data, encoding: .utf8) {
            questionsJSON = json
        } else {
            questionsJSON = nil
        }

        // 11. Save analysis run
        let run = JournalAnalysisRun(
            sessionId: sessionId,
            runAt: startTime,
            screenshotCount: screenshots.count,
            ocrTextInput: ocrText,
            analysis: analysisText,
            questionsJSON: questionsJSON,
            latencyMs: latencyMs,
            wasUsed: true
        )
        try analysisRunRepo.save(run)

        // 12. Update running summary
        if let summary = extractedSummary, !summary.isEmpty {
            try sessionRepo.updateRunningSummary(id: sessionId, text: summary)
        }

        // 13. Sync questions
        try await questionTracker.syncQuestions(
            sessionId: sessionId,
            analysisRunId: run.id,
            questions: questions
        )

        return run
    }

    // MARK: - Private helpers

    private func concatenateOCRText(from screenshots: [JournalScreenshot]) -> String {
        var parts: [String] = []
        var totalChars = 0

        for screenshot in screenshots {
            guard let text = screenshot.ocrText, !text.isEmpty else { continue }
            let timestamp = ISO8601DateFormatter().string(from: screenshot.capturedAt)
            let header = "--- \(timestamp) | \(screenshot.displayName ?? "Display") ---"
            let block = "\(header)\n\(text)"

            if totalChars + block.count > Self.ocrContextBudget {
                let remaining = Self.ocrContextBudget - totalChars
                if remaining > 200 {
                    let truncated = String(block.prefix(remaining))
                    parts.append(truncated + "\n[...truncated...]")
                }
                break
            }
            parts.append(block)
            totalChars += block.count
        }
        return parts.joined(separator: "\n\n")
    }

    private func formatPendingQuestions(_ questions: [JournalQuestion]) -> String {
        if questions.isEmpty {
            return "(No pending questions.)"
        }
        return questions.enumerated().map { i, q in
            "\(i + 1). \(q.question)"
        }.joined(separator: "\n")
    }

    private func extractSection(_ header: String, from text: String) -> String? {
        guard let headerRange = text.range(of: "## \(header)") else {
            return nil
        }

        let afterHeader = text[headerRange.upperBound...]
        var lines: [String] = []

        for line in afterHeader.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("## ") {
                break
            }
            lines.append(String(line))
        }

        let content = lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return content.isEmpty ? nil : content
    }

    // MARK: - Meeting transcripts

    private func fetchSameDayMeetings(session: JournalSession) -> String {
        guard let repo = transcriptionRepo else { return "" }

        let calendar = Calendar.current
        let sessionDay = calendar.startOfDay(for: session.createdAt)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: sessionDay) ?? session.createdAt

        do {
            let allTranscriptions = try repo.fetchAll(limit: nil)
            let todayMeetings = allTranscriptions.filter {
                $0.sourceType == .meeting
                    && $0.status == .completed
                    && $0.createdAt >= sessionDay
                    && $0.createdAt < nextDay
                    && ($0.rawTranscript ?? $0.cleanTranscript)?.isEmpty == false
            }

            guard !todayMeetings.isEmpty else { return "" }

            var context = ""
            for (i, meeting) in todayMeetings.enumerated() {
                let formatter = DateFormatter()
                formatter.timeStyle = .short
                let time = formatter.string(from: meeting.createdAt)
                let title = meeting.fileName
                let transcript = meeting.cleanTranscript ?? meeting.rawTranscript ?? ""
                // Cap each meeting at ~3000 chars to avoid blowing the context budget
                let capped = String(transcript.prefix(3000))
                let suffix = transcript.count > 3000 ? "…" : ""

                context += "--- Meeting \(i + 1): \"\(title)\" at \(time) ---\n\(capped)\(suffix)\n\n"
            }
            return context
        } catch {
            Self.logger.warning("Failed to fetch same-day meetings: \(error.localizedDescription)")
            return ""
        }
    }
}

// MARK: - Journal Error

public enum JournalError: Error, LocalizedError {
    case sessionNotFound(UUID)
    case sessionAlreadyActive
    case noSessionActive
    case screenRecordingPermissionDenied
    case storageError(String)

    public var errorDescription: String? {
        switch self {
        case .sessionNotFound(let id):
            return "Journal session not found: \(id)"
        case .sessionAlreadyActive:
            return "A journal session is already recording"
        case .noSessionActive:
            return "No journal session is currently active"
        case .screenRecordingPermissionDenied:
            return "Screen Recording permission is required for Day Journal"
        case .storageError(let message):
            return "Journal storage error: \(message)"
        }
    }
}

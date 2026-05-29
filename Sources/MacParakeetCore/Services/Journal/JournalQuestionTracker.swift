import Foundation

// MARK: - Protocol

public protocol JournalQuestionTrackerProtocol: Sendable {
    func extractQuestions(from analysisText: String) -> [String]
    func syncQuestions(sessionId: UUID, analysisRunId: UUID?, questions: [String]) async throws
    func fetchPending(sessionId: UUID) async throws -> [JournalQuestion]
    func answer(questionId: UUID, answer: String) async throws
    func dismiss(questionId: UUID) async throws
}

// MARK: - Implementation

public final class JournalQuestionTracker: JournalQuestionTrackerProtocol {
    private let repository: JournalQuestionRepositoryProtocol

    public init(repository: JournalQuestionRepositoryProtocol) {
        self.repository = repository
    }

    /// Parse the pending-questions section from an AI analysis output.
    /// Tolerant of heading-level/casing/spacing drift (e.g. "## Pending Questions",
    /// "###  pending questions", "## Questions"): matches bullet lines (-, *, +)
    /// after the questions header until the next heading or end of text.
    public func extractQuestions(from analysisText: String) -> [String] {
        var questions: [String] = []
        var inSection = false

        for line in analysisText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("#") {
                if inSection { break } // next section ends the questions block
                let headingText = trimmed
                    .drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                    .lowercased()
                if headingText.contains("pending question") || headingText == "questions" {
                    inSection = true
                }
                continue
            }

            guard inSection else { continue }
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                let question = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !question.isEmpty {
                    questions.append(question)
                }
            }
        }

        return questions
    }

    public func syncQuestions(sessionId: UUID, analysisRunId: UUID?, questions: [String]) async throws {
        try repository.upsert(
            questions: questions,
            sessionId: sessionId,
            analysisRunId: analysisRunId
        )
    }

    public func fetchPending(sessionId: UUID) async throws -> [JournalQuestion] {
        try repository.fetchPending(sessionId: sessionId)
    }

    public func answer(questionId: UUID, answer: String) async throws {
        try repository.answer(id: questionId, answer: answer)
    }

    public func dismiss(questionId: UUID) async throws {
        try repository.dismiss(id: questionId)
    }
}

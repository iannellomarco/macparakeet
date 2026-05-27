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

    /// Parse the "## Pending Questions" section from an AI analysis output.
    /// Matches bullet-point lines (starting with `-` or `*`) after the
    /// "## Pending Questions" header until the next `## ` header or end of text.
    public func extractQuestions(from analysisText: String) -> [String] {
        guard let questionsHeader = analysisText.range(of: "## Pending Questions") else {
            return []
        }

        let afterHeader = analysisText[questionsHeader.upperBound...]
        var questions: [String] = []

        for line in afterHeader.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Stop at next section header
            if trimmed.hasPrefix("## ") {
                break
            }
            // Match bullet points
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
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

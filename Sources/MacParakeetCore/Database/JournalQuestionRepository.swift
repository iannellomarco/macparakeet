import Foundation
import GRDB

public protocol JournalQuestionRepositoryProtocol: Sendable {
    func save(_ question: JournalQuestion) throws
    func fetch(id: UUID) throws -> JournalQuestion?
    func fetchAll(sessionId: UUID) throws -> [JournalQuestion]
    func fetchPending(sessionId: UUID) throws -> [JournalQuestion]
    func answer(id: UUID, answer: String) throws
    func dismiss(id: UUID) throws
    func upsert(questions: [String], sessionId: UUID, analysisRunId: UUID?) throws
    func delete(id: UUID) throws -> Bool
}

public final class JournalQuestionRepository: JournalQuestionRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func save(_ question: JournalQuestion) throws {
        try dbQueue.write { db in
            try question.save(db)
        }
    }

    public func fetch(id: UUID) throws -> JournalQuestion? {
        try dbQueue.read { db in
            try JournalQuestion.fetchOne(db, key: id)
        }
    }

    public func fetchAll(sessionId: UUID) throws -> [JournalQuestion] {
        try dbQueue.read { db in
            try JournalQuestion
                .filter(JournalQuestion.Columns.sessionId == sessionId)
                .order(JournalQuestion.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    public func fetchPending(sessionId: UUID) throws -> [JournalQuestion] {
        try dbQueue.read { db in
            try JournalQuestion
                .filter(JournalQuestion.Columns.sessionId == sessionId)
                .filter(JournalQuestion.Columns.status == JournalQuestion.Status.pending.rawValue)
                .order(JournalQuestion.Columns.createdAt.asc)
                .fetchAll(db)
        }
    }

    public func answer(id: UUID, answer: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_questions
                    SET userAnswer = ?, answeredAt = ?, status = ?
                    WHERE id = ?
                    """,
                arguments: [answer, Date(), JournalQuestion.Status.answered.rawValue, id]
            )
        }
    }

    public func dismiss(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_questions
                    SET status = ?
                    WHERE id = ?
                    """,
                arguments: [JournalQuestion.Status.dismissed.rawValue, id]
            )
        }
    }

    public func upsert(questions: [String], sessionId: UUID, analysisRunId: UUID?) throws {
        try dbQueue.write { db in
            let existingQuestions = try JournalQuestion
                .filter(JournalQuestion.Columns.sessionId == sessionId)
                .fetchAll(db)

            let existingTexts = Set(existingQuestions.map { $0.question.lowercased() })
            let newTexts = Set(questions.map { $0.lowercased() })

            // Remove pending questions no longer in the new list
            for existing in existingQuestions
                where existing.status == .pending && !newTexts.contains(existing.question.lowercased()) {
                try existing.delete(db)
            }

            // Insert new questions not already present (across all statuses)
            for questionText in questions {
                if !existingTexts.contains(questionText.lowercased()) {
                    let question = JournalQuestion(
                        sessionId: sessionId,
                        analysisRunId: analysisRunId,
                        question: questionText,
                        status: .pending
                    )
                    try question.insert(db)
                }
            }
        }
    }

    public func delete(id: UUID) throws -> Bool {
        try dbQueue.write { db in
            guard try JournalQuestion.fetchOne(db, key: id) != nil else { return false }
            try JournalQuestion.deleteOne(db, key: id)
            return true
        }
    }
}

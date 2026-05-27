import Foundation
import GRDB

public struct JournalQuestion: Codable, Identifiable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var analysisRunId: UUID?
    public var question: String
    public var userAnswer: String?
    public var answeredAt: Date?
    public var status: Status
    public var createdAt: Date

    public enum Status: String, Codable, Sendable {
        case pending
        case answered
        case dismissed
    }

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        analysisRunId: UUID? = nil,
        question: String,
        userAnswer: String? = nil,
        answeredAt: Date? = nil,
        status: Status = .pending,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sessionId = sessionId
        self.analysisRunId = analysisRunId
        self.question = question
        self.userAnswer = userAnswer
        self.answeredAt = answeredAt
        self.status = status
        self.createdAt = createdAt
    }
}

extension JournalQuestion: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "journal_questions"

    public enum Columns: String, ColumnExpression {
        case id, sessionId, analysisRunId, question
        case userAnswer, answeredAt, status, createdAt
    }
}

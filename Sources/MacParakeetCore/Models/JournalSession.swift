import Foundation
import GRDB

public struct JournalSession: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var endedAt: Date?
    public var status: Status
    public var title: String?
    public var runningSummary: String?
    public var finalSnapshot: String?
    public var userNotes: String?
    public var screenshotCount: Int
    public var totalStorageBytes: Int
    public var captureIntervalSecs: Int
    public var analysisIntervalMins: Int
    public var updatedAt: Date

    public enum Status: String, Codable, Sendable {
        case recording
        case reviewing
        case completed
        case cancelled
    }

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        endedAt: Date? = nil,
        status: Status = .recording,
        title: String? = nil,
        runningSummary: String? = nil,
        finalSnapshot: String? = nil,
        userNotes: String? = nil,
        screenshotCount: Int = 0,
        totalStorageBytes: Int = 0,
        captureIntervalSecs: Int,
        analysisIntervalMins: Int,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.createdAt = createdAt
        self.endedAt = endedAt
        self.status = status
        self.title = title
        self.runningSummary = runningSummary
        self.finalSnapshot = finalSnapshot
        self.userNotes = userNotes
        self.screenshotCount = screenshotCount
        self.totalStorageBytes = totalStorageBytes
        self.captureIntervalSecs = captureIntervalSecs
        self.analysisIntervalMins = analysisIntervalMins
        self.updatedAt = updatedAt
    }
}

extension JournalSession: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "journal_sessions"

    public enum Columns: String, ColumnExpression {
        case id, createdAt, endedAt, status, title
        case runningSummary, finalSnapshot, userNotes
        case screenshotCount, totalStorageBytes
        case captureIntervalSecs, analysisIntervalMins
        case updatedAt
    }
}

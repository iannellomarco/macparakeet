import Foundation
import GRDB

public protocol JournalScreenshotRepositoryProtocol: Sendable {
    func save(_ screenshot: JournalScreenshot) throws
    func fetch(id: UUID) throws -> JournalScreenshot?
    func fetchAll(sessionId: UUID, limit: Int?) throws -> [JournalScreenshot]
    func fetchUnanalyzed(sessionId: UUID, since runAt: Date) throws -> [JournalScreenshot]
    func fetchCount(sessionId: UUID) throws -> Int
    func fetchTotalStorage(sessionId: UUID) throws -> Int
    func delete(id: UUID) throws -> Bool
    func deleteAll(sessionId: UUID) throws
}

public final class JournalScreenshotRepository: JournalScreenshotRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func save(_ screenshot: JournalScreenshot) throws {
        try dbQueue.write { db in
            try screenshot.save(db)
        }
    }

    public func fetch(id: UUID) throws -> JournalScreenshot? {
        try dbQueue.read { db in
            try JournalScreenshot.fetchOne(db, key: id)
        }
    }

    public func fetchAll(sessionId: UUID, limit: Int? = nil) throws -> [JournalScreenshot] {
        try dbQueue.read { db in
            var request = JournalScreenshot
                .filter(JournalScreenshot.Columns.sessionId == sessionId)
                .filter(JournalScreenshot.Columns.isDiscarded == false)
                .order(JournalScreenshot.Columns.capturedAt.asc)
            if let limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    public func fetchUnanalyzed(sessionId: UUID, since runAt: Date) throws -> [JournalScreenshot] {
        try dbQueue.read { db in
            try JournalScreenshot
                .filter(JournalScreenshot.Columns.sessionId == sessionId)
                .filter(JournalScreenshot.Columns.isDiscarded == false)
                .filter(JournalScreenshot.Columns.ocrText != nil)
                .filter(JournalScreenshot.Columns.capturedAt > runAt)
                .order(JournalScreenshot.Columns.capturedAt.asc)
                .fetchAll(db)
        }
    }

    public func fetchCount(sessionId: UUID) throws -> Int {
        try dbQueue.read { db in
            try JournalScreenshot
                .filter(JournalScreenshot.Columns.sessionId == sessionId)
                .filter(JournalScreenshot.Columns.isDiscarded == false)
                .fetchCount(db)
        }
    }

    public func fetchTotalStorage(sessionId: UUID) throws -> Int {
        try dbQueue.read { db in
            try Int.fetchOne(
                db,
                sql: """
                    SELECT COALESCE(SUM(fileSizeBytes), 0)
                    FROM journal_screenshots
                    WHERE sessionId = ? AND isDiscarded = 0
                    """,
                arguments: [sessionId]
            ) ?? 0
        }
    }

    public func delete(id: UUID) throws -> Bool {
        try dbQueue.write { db in
            guard try JournalScreenshot.fetchOne(db, key: id) != nil else { return false }
            try JournalScreenshot.deleteOne(db, key: id)
            return true
        }
    }

    public func deleteAll(sessionId: UUID) throws {
        try dbQueue.write { db in
            try JournalScreenshot
                .filter(JournalScreenshot.Columns.sessionId == sessionId)
                .deleteAll(db)
        }
    }
}

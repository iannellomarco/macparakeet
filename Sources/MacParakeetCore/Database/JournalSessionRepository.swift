import Foundation
import GRDB

public protocol JournalSessionRepositoryProtocol: Sendable {
    func save(_ session: JournalSession) throws
    func fetch(id: UUID) throws -> JournalSession?
    func fetchActive() throws -> JournalSession?
    func fetchAll(limit: Int?) throws -> [JournalSession]
    func updateStatus(id: UUID, status: JournalSession.Status, endedAt: Date?) throws
    func updateRunningSummary(id: UUID, text: String) throws
    func updateFinalSnapshot(id: UUID, text: String, userNotes: String?) throws
    func incrementScreenshotCount(id: UUID, storageBytes: Int) throws
    func delete(id: UUID) throws -> Bool
}

public final class JournalSessionRepository: JournalSessionRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func save(_ session: JournalSession) throws {
        try dbQueue.write { db in
            try session.save(db)
        }
    }

    public func fetch(id: UUID) throws -> JournalSession? {
        try dbQueue.read { db in
            try JournalSession.fetchOne(db, key: id)
        }
    }

    public func fetchActive() throws -> JournalSession? {
        try dbQueue.read { db in
            try JournalSession
                .filter(JournalSession.Columns.status == JournalSession.Status.recording.rawValue)
                .order(JournalSession.Columns.createdAt.desc)
                .fetchOne(db)
        }
    }

    public func fetchAll(limit: Int? = nil) throws -> [JournalSession] {
        try dbQueue.read { db in
            var request = JournalSession
                .order(JournalSession.Columns.createdAt.desc)
            if let limit {
                request = request.limit(limit)
            }
            return try request.fetchAll(db)
        }
    }

    public func updateStatus(id: UUID, status: JournalSession.Status, endedAt: Date?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_sessions
                    SET status = ?, endedAt = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [status.rawValue, endedAt, Date(), id]
            )
        }
    }

    public func updateRunningSummary(id: UUID, text: String) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_sessions
                    SET runningSummary = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [text, Date(), id]
            )
        }
    }

    public func updateFinalSnapshot(id: UUID, text: String, userNotes: String?) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_sessions
                    SET finalSnapshot = ?, userNotes = ?, updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [text, userNotes, Date(), id]
            )
        }
    }

    public func incrementScreenshotCount(id: UUID, storageBytes: Int) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: """
                    UPDATE journal_sessions
                    SET screenshotCount = screenshotCount + 1,
                        totalStorageBytes = totalStorageBytes + ?,
                        updatedAt = ?
                    WHERE id = ?
                    """,
                arguments: [storageBytes, Date(), id]
            )
        }
    }

    public func delete(id: UUID) throws -> Bool {
        try dbQueue.write { db in
            guard try JournalSession.fetchOne(db, key: id) != nil else { return false }
            // Screenshots and analysis runs cascade-delete via FK
            try JournalSession.deleteOne(db, key: id)
            return true
        }
    }
}

import Foundation
import GRDB

public protocol JournalAnalysisRunRepositoryProtocol: Sendable {
    func save(_ run: JournalAnalysisRun) throws
    func fetch(id: UUID) throws -> JournalAnalysisRun?
    func fetchAll(sessionId: UUID) throws -> [JournalAnalysisRun]
    func fetchLatest(sessionId: UUID) throws -> JournalAnalysisRun?
    func markUnused(id: UUID) throws
    func delete(id: UUID) throws -> Bool
}

public final class JournalAnalysisRunRepository: JournalAnalysisRunRepositoryProtocol {
    private let dbQueue: DatabaseQueue

    public init(dbQueue: DatabaseQueue) {
        self.dbQueue = dbQueue
    }

    public func save(_ run: JournalAnalysisRun) throws {
        try dbQueue.write { db in
            try run.save(db)
        }
    }

    public func fetch(id: UUID) throws -> JournalAnalysisRun? {
        try dbQueue.read { db in
            try JournalAnalysisRun.fetchOne(db, key: id)
        }
    }

    public func fetchAll(sessionId: UUID) throws -> [JournalAnalysisRun] {
        try dbQueue.read { db in
            try JournalAnalysisRun
                .filter(JournalAnalysisRun.Columns.sessionId == sessionId)
                .order(JournalAnalysisRun.Columns.runAt.asc)
                .fetchAll(db)
        }
    }

    public func fetchLatest(sessionId: UUID) throws -> JournalAnalysisRun? {
        try dbQueue.read { db in
            try JournalAnalysisRun
                .filter(JournalAnalysisRun.Columns.sessionId == sessionId)
                .order(JournalAnalysisRun.Columns.runAt.desc)
                .fetchOne(db)
        }
    }

    public func markUnused(id: UUID) throws {
        try dbQueue.write { db in
            try db.execute(
                sql: "UPDATE journal_analysis_runs SET wasUsed = 0 WHERE id = ?",
                arguments: [id]
            )
        }
    }

    public func delete(id: UUID) throws -> Bool {
        try dbQueue.write { db in
            guard try JournalAnalysisRun.fetchOne(db, key: id) != nil else { return false }
            try JournalAnalysisRun.deleteOne(db, key: id)
            return true
        }
    }
}

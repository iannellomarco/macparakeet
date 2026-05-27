import XCTest
import GRDB
@testable import MacParakeetCore

final class JournalScreenshotRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var sessionRepo: JournalSessionRepository!
    var repo: JournalScreenshotRepository!

    override func setUp() async throws {
        manager = try DatabaseManager()
        sessionRepo = JournalSessionRepository(dbQueue: manager.dbQueue)
        repo = JournalScreenshotRepository(dbQueue: manager.dbQueue)
    }

    private func createSession() throws -> JournalSession {
        let session = JournalSession(
            captureIntervalSecs: 120,
            analysisIntervalMins: 30
        )
        try sessionRepo.save(session)
        return session
    }

    func testSaveAndFetch() throws {
        let session = try createSession()
        let screenshot = JournalScreenshot(
            sessionId: session.id,
            filePath: "/tmp/test.jpg",
            ocrText: "Hello world",
            ocrConfidence: 0.95
        )
        try repo.save(screenshot)

        let fetched = try repo.fetch(id: screenshot.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.ocrText, "Hello world")
        XCTAssertEqual(fetched?.ocrConfidence, 0.95)
    }

    func testFetchAllExcludesDiscarded() throws {
        let session = try createSession()

        let s1 = JournalScreenshot(sessionId: session.id, filePath: "/tmp/1.jpg")
        let s2 = JournalScreenshot(sessionId: session.id, filePath: "/tmp/2.jpg", isDiscarded: true)
        try repo.save(s1)
        try repo.save(s2)

        let all = try repo.fetchAll(sessionId: session.id)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.id, s1.id)
    }

    func testFetchUnanalyzedSinceDate() throws {
        let session = try createSession()

        let past = Date().addingTimeInterval(-3600)
        let now = Date()

        let s1 = JournalScreenshot(
            sessionId: session.id,
            capturedAt: past,
            filePath: "/tmp/old.jpg",
            ocrText: "old"
        )
        let s2 = JournalScreenshot(
            sessionId: session.id,
            capturedAt: now,
            filePath: "/tmp/new.jpg",
            ocrText: "new"
        )
        try repo.save(s1)
        try repo.save(s2)

        // Fetch screenshots since 30min ago
        let since = Date().addingTimeInterval(-1800)
        let unanalyzed = try repo.fetchUnanalyzed(sessionId: session.id, since: since)
        XCTAssertEqual(unanalyzed.count, 1)
        XCTAssertEqual(unanalyzed.first?.ocrText, "new")
    }

    func testFetchUnanalyzedExcludesNilOCR() throws {
        let session = try createSession()

        let s1 = JournalScreenshot(
            sessionId: session.id,
            capturedAt: Date(),
            filePath: "/tmp/no_ocr.jpg",
            ocrText: nil
        )
        let s2 = JournalScreenshot(
            sessionId: session.id,
            capturedAt: Date().addingTimeInterval(1),
            filePath: "/tmp/with_ocr.jpg",
            ocrText: "some text"
        )
        try repo.save(s1)
        try repo.save(s2)

        let since = Date().addingTimeInterval(-600)
        let unanalyzed = try repo.fetchUnanalyzed(sessionId: session.id, since: since)
        XCTAssertEqual(unanalyzed.count, 1)
        XCTAssertEqual(unanalyzed.first?.id, s2.id)
    }

    func testFetchCountAndStorage() throws {
        let session = try createSession()

        try repo.save(JournalScreenshot(
            sessionId: session.id,
            filePath: "/tmp/a.jpg",
            fileSizeBytes: 1000
        ))
        try repo.save(JournalScreenshot(
            sessionId: session.id,
            filePath: "/tmp/b.jpg",
            fileSizeBytes: 2000
        ))

        let count = try repo.fetchCount(sessionId: session.id)
        XCTAssertEqual(count, 2)

        let storage = try repo.fetchTotalStorage(sessionId: session.id)
        XCTAssertEqual(storage, 3000)
    }

    func testDeleteAll() throws {
        let session = try createSession()

        try repo.save(JournalScreenshot(sessionId: session.id, filePath: "/tmp/1.jpg"))
        try repo.save(JournalScreenshot(sessionId: session.id, filePath: "/tmp/2.jpg"))

        try repo.deleteAll(sessionId: session.id)
        let remaining = try repo.fetchAll(sessionId: session.id)
        XCTAssertEqual(remaining.count, 0)
    }
}

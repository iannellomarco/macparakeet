import XCTest
import GRDB
@testable import MacParakeetCore

final class JournalSessionRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var repo: JournalSessionRepository!

    override func setUp() async throws {
        manager = try DatabaseManager()
        repo = JournalSessionRepository(dbQueue: manager.dbQueue)
    }

    func testSaveAndFetch() throws {
        let session = JournalSession(
            captureIntervalSecs: 120,
            analysisIntervalMins: 30
        )
        try repo.save(session)

        let fetched = try repo.fetch(id: session.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.id, session.id)
        XCTAssertEqual(fetched?.status, .recording)
        XCTAssertEqual(fetched?.captureIntervalSecs, 120)
        XCTAssertEqual(fetched?.analysisIntervalMins, 30)
        XCTAssertEqual(fetched?.screenshotCount, 0)
    }

    func testFetchActiveReturnsRecordingSession() throws {
        let session = JournalSession(
            captureIntervalSecs: 120,
            analysisIntervalMins: 30
        )
        try repo.save(session)

        let active = try repo.fetchActive()
        XCTAssertNotNil(active)
        XCTAssertEqual(active?.id, session.id)
    }

    func testFetchActiveNilWhenNoRecordingSession() throws {
        let session = JournalSession(
            status: .completed,
            captureIntervalSecs: 120,
            analysisIntervalMins: 30
        )
        try repo.save(session)

        let active = try repo.fetchActive()
        XCTAssertNil(active)
    }

    func testFetchAllOrderedByDate() throws {
        let s1 = JournalSession(
            createdAt: Date().addingTimeInterval(-3600),
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        let s2 = JournalSession(captureIntervalSecs: 120, analysisIntervalMins: 30)
        try repo.save(s1)
        try repo.save(s2)

        let all = try repo.fetchAll()
        XCTAssertEqual(all.count, 2)
        XCTAssertEqual(all.first?.id, s2.id) // newest first
    }

    func testUpdateStatus() throws {
        let session = JournalSession(
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        try repo.save(session)

        let now = Date()
        try repo.updateStatus(id: session.id, status: .completed, endedAt: now)

        let fetched = try repo.fetch(id: session.id)
        XCTAssertEqual(fetched?.status, .completed)
        XCTAssertNotNil(fetched?.endedAt)
    }

    func testUpdateRunningSummary() throws {
        let session = JournalSession(
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        try repo.save(session)

        try repo.updateRunningSummary(id: session.id, text: "User worked on project X")
        let fetched = try repo.fetch(id: session.id)
        XCTAssertEqual(fetched?.runningSummary, "User worked on project X")
    }

    func testUpdateFinalSnapshot() throws {
        let session = JournalSession(
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        try repo.save(session)

        try repo.updateFinalSnapshot(
            id: session.id,
            text: "Final day summary",
            userNotes: "User's notes"
        )
        let fetched = try repo.fetch(id: session.id)
        XCTAssertEqual(fetched?.finalSnapshot, "Final day summary")
        XCTAssertEqual(fetched?.userNotes, "User's notes")
    }

    func testIncrementScreenshotCount() throws {
        let session = JournalSession(
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        try repo.save(session)

        try repo.incrementScreenshotCount(id: session.id, storageBytes: 50000)
        try repo.incrementScreenshotCount(id: session.id, storageBytes: 75000)

        let fetched = try repo.fetch(id: session.id)
        XCTAssertEqual(fetched?.screenshotCount, 2)
        XCTAssertEqual(fetched?.totalStorageBytes, 125000)
    }

    func testDeleteCascadesToScreenshots() throws {
        let session = JournalSession(
            captureIntervalSecs: 60,
            analysisIntervalMins: 15
        )
        try repo.save(session)

        let screenshotRepo = JournalScreenshotRepository(dbQueue: manager.dbQueue)
        let screenshot = JournalScreenshot(
            sessionId: session.id,
            filePath: "/tmp/test.jpg"
        )
        try screenshotRepo.save(screenshot)

        let deleted = try repo.delete(id: session.id)
        XCTAssertTrue(deleted)

        let screenshots = try screenshotRepo.fetchAll(sessionId: session.id)
        XCTAssertEqual(screenshots.count, 0) // cascade deleted
    }

    func testDeleteNonexistentReturnsFalse() throws {
        let deleted = try repo.delete(id: UUID())
        XCTAssertFalse(deleted)
    }
}

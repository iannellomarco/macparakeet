import XCTest
import GRDB
@testable import MacParakeetCore

final class JournalQuestionRepositoryTests: XCTestCase {
    var manager: DatabaseManager!
    var sessionRepo: JournalSessionRepository!
    var repo: JournalQuestionRepository!

    override func setUp() async throws {
        manager = try DatabaseManager()
        sessionRepo = JournalSessionRepository(dbQueue: manager.dbQueue)
        repo = JournalQuestionRepository(dbQueue: manager.dbQueue)
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

        let question = JournalQuestion(
            sessionId: session.id,
            question: "What were you working on at 2pm?"
        )
        try repo.save(question)

        let fetched = try repo.fetch(id: question.id)
        XCTAssertNotNil(fetched)
        XCTAssertEqual(fetched?.question, "What were you working on at 2pm?")
        XCTAssertEqual(fetched?.status, .pending)
    }

    func testFetchPendingOnly() throws {
        let session = try createSession()

        try repo.save(JournalQuestion(
            sessionId: session.id,
            question: "Pending question"
        ))
        let answered = JournalQuestion(
            sessionId: session.id,
            question: "Already answered",
            status: .answered
        )
        try repo.save(answered)

        let pending = try repo.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.question, "Pending question")
    }

    func testAnswerQuestion() throws {
        let session = try createSession()

        let question = JournalQuestion(
            sessionId: session.id,
            question: "Test question"
        )
        try repo.save(question)

        try repo.answer(id: question.id, answer: "My answer")

        let fetched = try repo.fetch(id: question.id)
        XCTAssertEqual(fetched?.status, .answered)
        XCTAssertEqual(fetched?.userAnswer, "My answer")
        XCTAssertNotNil(fetched?.answeredAt)
    }

    func testDismissQuestion() throws {
        let session = try createSession()

        let question = JournalQuestion(
            sessionId: session.id,
            question: "Test question"
        )
        try repo.save(question)

        try repo.dismiss(id: question.id)

        let fetched = try repo.fetch(id: question.id)
        XCTAssertEqual(fetched?.status, .dismissed)
    }

    func testUpsertAddsNewQuestions() throws {
        let session = try createSession()

        try repo.upsert(
            questions: ["Q1: What is this?", "Q2: Explain that?"],
            sessionId: session.id,
            analysisRunId: nil
        )

        let all = try repo.fetchAll(sessionId: session.id)
        XCTAssertEqual(all.count, 2)
    }

    func testUpsertRemovesStaleQuestions() throws {
        let session = try createSession()

        // Seed with two pending questions
        try repo.upsert(
            questions: ["Q1: First question", "Q2: Second question"],
            sessionId: session.id,
            analysisRunId: nil
        )
        XCTAssertEqual(try repo.fetchPending(sessionId: session.id).count, 2)

        // Upsert with only one (Q2 is dropped)
        try repo.upsert(
            questions: ["Q1: First question"],
            sessionId: session.id,
            analysisRunId: nil
        )

        let pending = try repo.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.question, "Q1: First question")
    }

    func testUpsertPreservesExistingQuestions() throws {
        let session = try createSession()

        // Create a question that's been answered
        let answered = JournalQuestion(
            sessionId: session.id,
            question: "Already answered",
            status: .answered
        )
        try repo.save(answered)

        // Upsert a new set that includes the answered question
        try repo.upsert(
            questions: ["Already answered", "New question"],
            sessionId: session.id,
            analysisRunId: nil
        )

        // The answered one should not be affected (upsert only touches pending)
        let fetched = try repo.fetch(id: answered.id)
        XCTAssertEqual(fetched?.status, .answered)

        // New pending question should be added
        let pending = try repo.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(pending.first?.question, "New question")
    }
}

import XCTest
@testable import MacParakeetCore

final class JournalQuestionTrackerTests: XCTestCase {
    var manager: DatabaseManager!
    var sessionRepo: JournalSessionRepository!
    var questionRepo: JournalQuestionRepository!
    var tracker: JournalQuestionTracker!

    override func setUp() async throws {
        manager = try DatabaseManager()
        sessionRepo = JournalSessionRepository(dbQueue: manager.dbQueue)
        questionRepo = JournalQuestionRepository(dbQueue: manager.dbQueue)
        tracker = JournalQuestionTracker(repository: questionRepo)
    }

    private func createSession() throws -> JournalSession {
        let session = JournalSession(
            captureIntervalSecs: 120,
            analysisIntervalMins: 30
        )
        try sessionRepo.save(session)
        return session
    }

    // MARK: - Question extraction

    func testExtractQuestionsFromAnalysisOutput() {
        let analysis = """
            ## Updated Running Summary
            User worked on the budget spreadsheet and then switched to email.

            ## New Observations
            - Opened Numbers at 10:15am
            - Browsed Safari with financial sites

            ## Pending Questions
            - What budget spreadsheet were you working on?
            - Was the email about the Q3 review?
            - Who sent the calendar invite at 11am?
            """

        let questions = tracker.extractQuestions(from: analysis)
        XCTAssertEqual(questions.count, 3)
        XCTAssertEqual(questions[0], "What budget spreadsheet were you working on?")
        XCTAssertEqual(questions[1], "Was the email about the Q3 review?")
        XCTAssertEqual(questions[2], "Who sent the calendar invite at 11am?")
    }

    func testExtractQuestionsEmptyWhenNoSection() {
        let analysis = """
            ## Updated Running Summary
            Just a normal workday.

            ## New Observations
            - Nothing unusual
            """

        let questions = tracker.extractQuestions(from: analysis)
        XCTAssertEqual(questions.count, 0)
    }

    func testExtractQuestionsEmptyWhenSectionIsEmpty() {
        let analysis = """
            ## Updated Running Summary
            Normal day.

            ## Pending Questions

            ## Next Section
            More content
            """

        let questions = tracker.extractQuestions(from: analysis)
        XCTAssertEqual(questions.count, 0)
    }

    func testExtractQuestionsHandlesAsteriskBullets() {
        let analysis = """
            ## Pending Questions
            * What app is "SecretProject"?
            * Why did you switch between VS Code and Xcode so frequently?
            ## Next Section
            """

        let questions = tracker.extractQuestions(from: analysis)
        XCTAssertEqual(questions.count, 2)
        XCTAssertEqual(questions[0], "What app is \"SecretProject\"?")
    }

    func testExtractQuestionsStopsAtNextHeader() {
        let analysis = """
            ## Pending Questions
            - Question one?
            ## Updated Running Summary
            - This is NOT a question
            - Neither is this
            """

        let questions = tracker.extractQuestions(from: analysis)
        XCTAssertEqual(questions.count, 1)
        XCTAssertEqual(questions[0], "Question one?")
    }

    // MARK: - Sync questions

    func testSyncQuestionsAddsNewAndRemovesStale() async throws {
        let session = try createSession()

        // Add initial questions
        try await tracker.syncQuestions(
            sessionId: session.id,
            analysisRunId: nil,
            questions: ["Q1", "Q2", "Q3"]
        )
        var pending = try await tracker.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 3)

        // Sync with a reduced set
        try await tracker.syncQuestions(
            sessionId: session.id,
            analysisRunId: nil,
            questions: ["Q1", "Q3"]
        )
        pending = try await tracker.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 2)
    }

    func testAnswerAndDismiss() async throws {
        let session = try createSession()

        try await tracker.syncQuestions(
            sessionId: session.id,
            analysisRunId: nil,
            questions: ["Test question"]
        )

        let pending = try await tracker.fetchPending(sessionId: session.id)
        XCTAssertEqual(pending.count, 1)

        try await tracker.answer(questionId: pending[0].id, answer: "My answer")
        let stillPending = try await tracker.fetchPending(sessionId: session.id)
        XCTAssertEqual(stillPending.count, 0)
    }
}

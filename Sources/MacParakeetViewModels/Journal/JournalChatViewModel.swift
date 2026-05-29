import Foundation
import MacParakeetCore
import OSLog

public struct JournalChatMessage: Identifiable, Equatable {
    public let id: UUID
    public let role: ChatMessage.Role
    public var content: String
    public var isStreaming: Bool

    public init(
        id: UUID = UUID(),
        role: ChatMessage.Role,
        content: String,
        isStreaming: Bool = false
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.isStreaming = isStreaming
    }
}

@MainActor
@Observable
public final class JournalChatViewModel {
    public var messages: [JournalChatMessage] = []
    public var inputText: String = ""
    public var isStreaming: Bool = false
    public var canFinalize: Bool = false
    public var errorMessage: String?
    /// AI clarification questions the user can still answer or dismiss.
    public var pendingQuestions: [JournalQuestion] = []

    private var llmService: LLMServiceProtocol?
    private var questionTracker: JournalQuestionTrackerProtocol?
    private var sessionId: UUID?
    private var runningSummary: String = ""
    private var questions: [JournalQuestion] = []
    private var streamingTask: Task<Void, Never>?

    private let logger = Logger(
        subsystem: "com.macparakeet.viewmodels",
        category: "JournalChat"
    )

    public init() {}

    public func configure(
        llmService: LLMServiceProtocol?,
        questionTracker: JournalQuestionTrackerProtocol? = nil
    ) {
        self.llmService = llmService
        self.questionTracker = questionTracker
    }

    /// Update just the LLM provider when the user (re)configures it after launch,
    /// without disturbing the question tracker. Wired from refreshLLMAvailability.
    public func updateLLMService(_ llmService: LLMServiceProtocol?) {
        self.llmService = llmService
    }

    public func loadReview(
        sessionId: UUID,
        runningSummary: String,
        questions: [JournalQuestion]
    ) async {
        self.sessionId = sessionId
        self.runningSummary = runningSummary
        self.questions = questions
        self.pendingQuestions = questions.filter { $0.status == .pending }

        // Build the initial AI message. Questions are surfaced as interactive
        // chips in the panel (answer/dismiss), so they aren't duplicated here.
        var introContent = "Here's what I observed during your workday:\n\n"
        introContent += runningSummary
        if !pendingQuestions.isEmpty {
            introContent += "\n\nI jotted down a few questions below — answer any that help, or just tell me what I missed."
        }

        messages = [
            JournalChatMessage(
                role: .assistant,
                content: introContent
            )
        ]
        canFinalize = true
    }

    /// Persist the user's answer to a clarification question and remove it from
    /// the pending list. The answer feeds the final-snapshot generation.
    public func answerQuestion(_ question: JournalQuestion, with answer: String) async {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await questionTracker?.answer(questionId: question.id, answer: trimmed)
            pendingQuestions.removeAll { $0.id == question.id }
            messages.append(JournalChatMessage(
                role: .user,
                content: "\(question.question)\n\n\(trimmed)"
            ))
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to answer journal question: \(error.localizedDescription)")
        }
    }

    /// Dismiss a clarification question without answering it.
    public func dismissQuestion(_ question: JournalQuestion) async {
        do {
            try await questionTracker?.dismiss(questionId: question.id)
            pendingQuestions.removeAll { $0.id == question.id }
        } catch {
            errorMessage = error.localizedDescription
            logger.error("Failed to dismiss journal question: \(error.localizedDescription)")
        }
    }

    public func sendMessage() async {
        // Ignore submits while a response is still streaming — the send button is
        // disabled in that state, but the text field's Enter key bypasses it.
        guard !isStreaming else { return }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let llm = llmService else {
            errorMessage = "AI provider not configured. Set one up in Settings."
            return
        }

        let userText = inputText
        inputText = ""

        // Add user message
        let userMessage = JournalChatMessage(role: .user, content: userText)
        messages.append(userMessage)

        // Build chat history
        let history: [ChatMessage] = messages.dropLast().map {
            ChatMessage(role: $0.role, content: $0.content)
        }

        // Stream AI response
        isStreaming = true
        let assistantID = UUID()
        let assistantMessage = JournalChatMessage(
            id: assistantID,
            role: .assistant,
            content: "",
            isStreaming: true
        )
        messages.append(assistantMessage)

        streamingTask?.cancel()
        streamingTask = Task { [weak self] in
            guard let self else { return }
            do {
                let stream = llm.chatStream(
                    question: userText,
                    transcript: "Day journal review. Running summary: \(self.runningSummary)",
                    userNotes: nil,
                    history: history,
                    source: .transcriptChat
                )
                for try await chunk in stream {
                    guard !Task.isCancelled else { break }
                    await MainActor.run {
                        if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                            self.messages[index].content += chunk
                        }
                    }
                }
                await MainActor.run {
                    if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                        self.messages[index].isStreaming = false
                    }
                    self.isStreaming = false
                }
            } catch {
                // Always clear the streaming flags, even on cancellation — otherwise
                // isStreaming stays true forever and freezes the send/save buttons.
                await MainActor.run {
                    if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                        self.messages[index].isStreaming = false
                    }
                    self.isStreaming = false
                    if !(error is CancellationError) {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        }
    }
}

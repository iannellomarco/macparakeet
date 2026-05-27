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

    private var llmService: LLMServiceProtocol?
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
        llmService: LLMServiceProtocol?
    ) {
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

        // Build the initial AI message with observations and questions
        var introContent = "Here's what I observed during your workday:\n\n"
        introContent += runningSummary

        if !questions.isEmpty {
            let pendingQuestions = questions.filter { $0.status == .pending }
            if !pendingQuestions.isEmpty {
                introContent += "\n\nI have a few questions to help fill in the gaps:\n\n"
                for (i, question) in pendingQuestions.enumerated() {
                    introContent += "\(i + 1). \(question.question)\n"
                }
                introContent += "\nFeel free to answer any of these, or just tell me what I missed."
            }
        }

        messages = [
            JournalChatMessage(
                role: .assistant,
                content: introContent
            )
        ]
        canFinalize = true
    }

    public func sendMessage() async {
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
                guard !(error is CancellationError) else { return }
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isStreaming = false
                    if let index = self.messages.firstIndex(where: { $0.id == assistantID }) {
                        self.messages[index].isStreaming = false
                    }
                }
            }
        }
    }
}

import AppKit
import MacParakeetCore
import MacParakeetViewModels

@MainActor
final class JournalFlowCoordinator {
    private let viewModel: JournalControlViewModel
    private let chatViewModel: JournalChatViewModel
    private let sessionRepo: JournalSessionRepositoryProtocol
    private let questionRepo: JournalQuestionRepositoryProtocol
    private var chatPanelController: JournalChatPanelController?

    init(
        viewModel: JournalControlViewModel,
        chatViewModel: JournalChatViewModel,
        sessionRepo: JournalSessionRepositoryProtocol,
        questionRepo: JournalQuestionRepositoryProtocol
    ) {
        self.viewModel = viewModel
        self.chatViewModel = chatViewModel
        self.sessionRepo = sessionRepo
        self.questionRepo = questionRepo

        viewModel.onReviewStarted = { [weak self] sessionId in
            Task { @MainActor in
                await self?.showChatPanel(sessionId: sessionId)
            }
        }

        viewModel.onSessionFinalized = { [weak self] in
            self?.chatPanelController?.close()
            self?.chatPanelController = nil
        }
    }

    private func showChatPanel(sessionId: UUID) async {
        // Load the real data from the DB
        var summary = "No observations recorded."
        var questions: [JournalQuestion] = []
        do {
            if let session = try sessionRepo.fetch(id: sessionId) {
                summary = session.runningSummary ?? summary
            }
            questions = (try? questionRepo.fetchPending(sessionId: sessionId)) ?? []
        } catch {
            // Use defaults if DB read fails
        }

        let controller = JournalChatPanelController(viewModel: chatViewModel)
        controller.onFinalize = { [weak self] notes in
            Task { @MainActor in
                await self?.viewModel.finalizeSession(userNotes: notes)
            }
        }
        controller.onDiscard = { [weak self] in
            Task { @MainActor in
                await self?.viewModel.cancelJournaling()
            }
        }
        self.chatPanelController = controller

        controller.show(
            sessionId: sessionId,
            runningSummary: summary,
            questions: questions
        )
    }
}

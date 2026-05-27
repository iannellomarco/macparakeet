import AppKit
import MacParakeetCore
import MacParakeetViewModels
import SwiftUI

private final class JournalChatPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

@MainActor
final class JournalChatPanelController {
    var onFinalize: ((String) -> Void)?
    var onDiscard: (() -> Void)?

    private var panel: NSPanel?
    private var windowDelegate: JournalChatPanelWindowDelegate?
    private let viewModel: JournalChatViewModel
    private var sessionId: UUID?
    private var runningSummary: String = ""
    private var questions: [JournalQuestion] = []

    init(viewModel: JournalChatViewModel) {
        self.viewModel = viewModel
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    func show(sessionId: UUID, runningSummary: String, questions: [JournalQuestion]) {
        self.sessionId = sessionId
        self.runningSummary = runningSummary
        self.questions = questions

        if panel == nil {
            createPanel()
        }

        Task {
            await viewModel.loadReview(
                sessionId: sessionId,
                runningSummary: runningSummary,
                questions: questions
            )
        }

        panel?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    func close() {
        panel?.delegate = nil
        panel?.close()
        panel = nil
        windowDelegate = nil
    }

    private func createPanel() {
        let panel = JournalChatPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 650),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "Day Review"
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 450, height: 400)
        panel.setFrameAutosaveName("JournalChatPanel")

        let chatPanel = JournalChatPanel(
            viewModel: viewModel,
            onFinalize: { [weak self] notes in
                self?.onFinalize?(notes)
                self?.close()
            },
            onDiscard: { [weak self] in
                self?.onDiscard?()
                self?.close()
            }
        )

        let hostingView = NSHostingView(rootView: chatPanel)
        panel.contentView = hostingView

        let delegate = JournalChatPanelWindowDelegate(controller: self)
        panel.delegate = delegate
        self.windowDelegate = delegate

        self.panel = panel
    }
}

private final class JournalChatPanelWindowDelegate: NSObject, NSWindowDelegate {
    private weak var controller: JournalChatPanelController?

    init(controller: JournalChatPanelController) {
        self.controller = controller
    }

    func windowWillClose(_ notification: Notification) {
        controller?.onDiscard?()
    }
}

import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// End-of-day review chat. Presents the AI's day observations, lets the user
/// answer/dismiss clarification questions, add notes, and finalize the journal.
struct JournalChatPanel: View {
    @State var viewModel: JournalChatViewModel
    var onFinalize: (String) -> Void
    var onDiscard: () -> Void

    @State private var userNotes: String = ""
    @State private var showNotes: Bool = false
    @State private var answerDrafts: [UUID: String] = [:]
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            messagesView
            questionsSection
            Divider()
            inputView
            bottomBar
        }
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720)
        .frame(minHeight: 540, idealHeight: 640)
        .background(DesignSystem.Colors.contentBackground)
        .onAppear { inputFocused = true }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "book.pages")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.accent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Day Review")
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Chat with the AI about your workday")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            Button { onDiscard() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
            .help("Discard this review")
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(viewModel.messages) { message in
                        Group {
                            if message.role == .user {
                                userBubble(message)
                            } else {
                                aiMessageCard(message)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func aiMessageCard(_ message: JournalChatMessage) -> some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 28, height: 28)
                .background(DesignSystem.Colors.accentLight, in: Circle())

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text(renderedMarkdown(message.content))
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .textSelection(.enabled)

                if message.isStreaming {
                    AIStreamingIndicator()
                }
            }
            .padding(DesignSystem.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius)
                    .stroke(DesignSystem.Colors.border, lineWidth: 1)
            )

            Spacer(minLength: DesignSystem.Spacing.xl)
        }
    }

    private func userBubble(_ message: JournalChatMessage) -> some View {
        HStack {
            Spacer(minLength: 60)
            Text(message.content)
                .font(DesignSystem.Typography.body)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(DesignSystem.Colors.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius))
        }
    }

    private func renderedMarkdown(_ content: String) -> AttributedString {
        (try? AttributedString(
            markdown: content,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(content)
    }

    // MARK: - Questions

    @ViewBuilder
    private var questionsSection: some View {
        if !viewModel.pendingQuestions.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label("A few questions to sharpen your journal", systemImage: "questionmark.bubble")
                    .font(DesignSystem.Typography.caption.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.textSecondary)

                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(viewModel.pendingQuestions) { question in
                            questionCard(question)
                        }
                    }
                }
                .frame(maxHeight: 168)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(DesignSystem.Colors.accentLight.opacity(0.6))
        }
    }

    private func questionCard(_ question: JournalQuestion) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(question.question)
                .font(DesignSystem.Typography.bodySmall.weight(.medium))
                .foregroundStyle(DesignSystem.Colors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: DesignSystem.Spacing.sm) {
                TextField("Your answer…", text: draftBinding(question.id))
                    .textFieldStyle(.roundedBorder)
                    .font(DesignSystem.Typography.bodySmall)
                    .onSubmit { submitAnswer(question) }

                Button("Answer") { submitAnswer(question) }
                    .parakeetAction(.primary)
                    .controlSize(.small)
                    .disabled((answerDrafts[question.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Skip") {
                    Task { await viewModel.dismissQuestion(question) }
                }
                .parakeetAction(.subtle)
                .controlSize(.small)
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.rowCornerRadius))
    }

    private func draftBinding(_ id: UUID) -> Binding<String> {
        Binding(
            get: { answerDrafts[id] ?? "" },
            set: { answerDrafts[id] = $0 }
        )
    }

    private func submitAnswer(_ question: JournalQuestion) {
        let draft = answerDrafts[question.id] ?? ""
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        Task {
            await viewModel.answerQuestion(question, with: draft)
            answerDrafts[question.id] = nil
        }
    }

    // MARK: - Input

    private var inputView: some View {
        VStack(spacing: 0) {
            if showNotes {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Notes for your journal")
                        .font(DesignSystem.Typography.caption)
                        .foregroundStyle(DesignSystem.Colors.textSecondary)
                    TextEditor(text: $userNotes)
                        .font(DesignSystem.Typography.body)
                        .frame(height: 56)
                        .scrollContentBackground(.hidden)
                        .padding(DesignSystem.Spacing.sm)
                        .background(DesignSystem.Colors.surfaceElevated, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.rowCornerRadius))
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)
                .padding(.bottom, DesignSystem.Spacing.sm)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button {
                    withAnimation(DesignSystem.Animation.contentSwap) { showNotes.toggle() }
                } label: {
                    Image(systemName: showNotes ? "note.text.badge.plus" : "note.text")
                        .font(.body)
                        .foregroundStyle(showNotes ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Add notes to your journal entry")

                TextField("Ask a question or add context…", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .focused($inputFocused)
                    .onSubmit { Task { await viewModel.sendMessage() } }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? DesignSystem.Colors.accent : DesignSystem.Colors.textTertiary)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
        }
        .background(DesignSystem.Colors.surface)
    }

    private var canSend: Bool {
        !viewModel.isStreaming
            && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Button(role: .destructive) {
                onDiscard()
            } label: {
                Label("Discard", systemImage: "trash")
            }
            .parakeetAction(.destructive)
            .controlSize(.large)

            Spacer()

            Button {
                onFinalize(userNotes)
            } label: {
                Label("Save Journal", systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: 180)
            }
            .parakeetAction(.primaryProminent)
            .controlSize(.large)
            .disabled(!viewModel.canFinalize)
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
        .background(DesignSystem.Colors.surface)
    }
}

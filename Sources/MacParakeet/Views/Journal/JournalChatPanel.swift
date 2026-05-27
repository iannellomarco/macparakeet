import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

struct JournalChatPanel: View {
    @State var viewModel: JournalChatViewModel
    var onFinalize: (String) -> Void
    var onDiscard: () -> Void

    @State private var userNotes: String = ""
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Messages
            messagesView

            Divider()

            // Input area
            inputView

            // Bottom bar
            bottomBar
        }
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720)
        .frame(minHeight: 520, idealHeight: 620)
        .onAppear { inputFocused = true }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.title3)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Day Review")
                    .font(.headline)
                Text("Chat with the AI about your workday")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button { onDiscard() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Messages

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
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
                .padding(20)
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let last = viewModel.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - AI Message Card

    private func aiMessageCard(_ message: JournalChatMessage) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Avatar
            Image(systemName: "brain.head.profile")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28, height: 28)
                .padding(6)
                .background(.blue.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 8) {
                // Render content as Markdown if it looks structured
                let content = message.content
                if content.contains("##") || content.contains("**") {
                    let attr = (try? AttributedString(
                        markdown: content,
                        options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                    )) ?? AttributedString(content)
                    Text(attr)
                    .font(.body)
                    .textSelection(.enabled)
                } else {
                    Text(content)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if message.isStreaming {
                    HStack(spacing: 3) {
                        Circle().frame(width: 4, height: 4)
                        Circle().frame(width: 4, height: 4)
                        Circle().frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.04), in: RoundedRectangle(cornerRadius: 14))

            Spacer(minLength: 40)
        }
    }

    // MARK: - User Bubble

    private func userBubble(_ message: JournalChatMessage) -> some View {
        HStack {
            Spacer(minLength: 60)

            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Input view

    private var inputView: some View {
        VStack(spacing: 0) {
            // Notes field (collapsible)
            if !userNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes for your journal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $userNotes)
                        .font(.callout)
                        .frame(height: 50)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            // Chat input bar
            HStack(spacing: 8) {
                // Add notes toggle
                Button {
                    withAnimation {
                        if userNotes.isEmpty {
                            userNotes = " "
                            userNotes = ""
                        } else {
                            userNotes = ""
                        }
                    }
                } label: {
                    Image(systemName: userNotes.isEmpty ? "note.text" : "note.text")
                        .font(.body)
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
                        .foregroundStyle(canSend ? Color.blue : Color.secondary.opacity(0.4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        !viewModel.isStreaming
            && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            Button(role: .destructive) {
                onDiscard()
            } label: {
                Label("Discard", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Spacer()

            Button {
                onFinalize(userNotes)
            } label: {
                Label("Save Journal", systemImage: "square.and.arrow.down.fill")
                    .frame(maxWidth: 180)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!viewModel.canFinalize)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// End-of-day chat panel for reviewing the day journal with the AI.
/// Presented as an NSPanel overlay when the user stops recording.
struct JournalChatPanel: View {
    @State var viewModel: JournalChatViewModel
    var onFinalize: (String) -> Void
    var onDiscard: () -> Void

    @State private var userNotes: String = ""
    @State private var scrollID: UUID?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "camera.viewfinder")
                    .foregroundStyle(.blue)
                Text("Day Review")
                    .font(.headline)
                Spacer()
                Button {
                    onDiscard()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Chat messages
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let last = viewModel.messages.last {
                        withAnimation {
                            scrollProxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            Divider()

            // Notes field (for final snapshot)
            VStack(alignment: .leading, spacing: 4) {
                Text("Additional notes for your day snapshot:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $userNotes)
                    .font(.body)
                    .frame(height: 60)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Input bar
            HStack(spacing: 8) {
                TextField("Answer the AI's questions or add context...", text: $viewModel.inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        Task { await viewModel.sendMessage() }
                    }

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(viewModel.isStreaming || viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            // Action buttons
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    onDiscard()
                } label: {
                    Label("Discard Day", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button {
                    onFinalize(userNotes)
                } label: {
                    Label("Save Day Snapshot", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.canFinalize)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 500, idealWidth: 600, maxWidth: 700)
        .frame(minHeight: 500, idealHeight: 600)
    }
}

// MARK: - Chat Bubble

private struct ChatBubble: View {
    let message: JournalChatMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.blue)
                    .frame(width: 24)
            } else {
                Spacer()
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                Text(message.role == .assistant ? "AI" : "You")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(message.content)
                    .font(.body)
                    .padding(10)
                    .background(
                        message.role == .assistant
                            ? Color.blue.opacity(0.1)
                            : Color.accentColor.opacity(0.15)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                if message.isStreaming {
                    HStack(spacing: 3) {
                        Circle().frame(width: 4, height: 4)
                        Circle().frame(width: 4, height: 4)
                        Circle().frame(width: 4, height: 4)
                    }
                    .foregroundStyle(.blue)
                }
            }

            if message.role == .user {
                Image(systemName: "person.circle")
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            } else {
                Spacer()
            }
        }
    }
}

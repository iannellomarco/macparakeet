import SwiftUI
import MacParakeetCore

struct JournalDayDetailView: View {
    let session: JournalSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Stats card
                statsCard
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Journal content
                VStack(alignment: .leading, spacing: 24) {
                    if let snapshot = session.finalSnapshot, !snapshot.isEmpty {
                        journalContent(title: nil, text: snapshot)
                    } else if let summary = session.runningSummary, !summary.isEmpty {
                        journalContent(title: nil, text: summary)
                    } else {
                        emptyContent
                    }

                    if let notes = session.userNotes, !notes.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Your Notes", systemImage: "note.text")
                                .font(.headline)
                            Text(notes)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 720, alignment: .leading)
            }
        }
        .frame(minWidth: 420, idealWidth: 640)
        .background(.ultraThinMaterial)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: "\(session.screenshotCount)", label: "Captures", icon: "camera.fill", color: .blue)
            Divider().frame(height: 40)
            statItem(value: formatDuration, label: "Duration", icon: "clock.fill", color: .orange)
            Divider().frame(height: 40)
            statItem(value: "1", label: "Meeting", icon: "mic.fill", color: .purple)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Journal Content

    private func journalContent(title: String?, text: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Render as Markdown when structured
            let hasMarkdown = text.contains("## ") || text.contains("**") || text.contains("# ")
            if hasMarkdown {
                let attr = (try? AttributedString(
                    markdown: text,
                    options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
                )) ?? AttributedString(text)
                Text(attr)
                .font(.body)
                .textSelection(.enabled)
            } else {
                // Narrative format — paragraph styling
                Text(text)
                    .font(.body.leading(.loose))
                    .textSelection(.enabled)
                    .lineSpacing(6)
            }
        }
    }

    private var emptyContent: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 36))
                .foregroundStyle(.secondary.opacity(0.4))
            Text("No observations recorded")
                .font(.headline)
            Text("Make sure an AI provider is configured in\nSettings → AI Provider.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Helpers

    private var formatDuration: String {
        guard let endedAt = session.endedAt else { return "—" }
        let s = Int(endedAt.timeIntervalSince(session.createdAt))
        let h = s / 3600; let m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

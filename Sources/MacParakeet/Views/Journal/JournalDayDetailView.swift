import SwiftUI
import MacParakeetCore

/// Read-only reading pane for a single saved journal session. Shows real
/// session stats, the AI-written narrative (rendered as Markdown), and the
/// user's notes. Hosted inside `JournalLibraryView`'s detail pane.
struct JournalDayDetailView: View {
    let session: JournalSession
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                titleHeader
                statsCard
                narrative
                notesSection
            }
            .padding(.horizontal, DesignSystem.Spacing.xl)
            .padding(.vertical, DesignSystem.Spacing.lg)
            .frame(maxWidth: 760, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DesignSystem.Colors.contentBackground)
    }

    // MARK: - Title

    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? dayTitle)
                    .font(DesignSystem.Typography.heroTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(subtitle)
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer()
            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14))
            }
            .parakeetAction(.subtle)
            .help("Delete this journal entry")
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(value: durationText, label: "Duration", icon: "clock.fill")
            statDivider
            statItem(value: "\(session.screenshotCount)", label: "Captures", icon: "camera.fill")
            statDivider
            statItem(value: storageText, label: "Storage", icon: "internaldrive.fill")
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius)
                .fill(DesignSystem.Colors.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cardCornerRadius)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .cardShadow(DesignSystem.Shadows.cardRest)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundStyle(DesignSystem.Colors.accent)
            Text(value)
                .font(DesignSystem.Typography.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.micro)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(DesignSystem.Colors.divider)
            .frame(width: 1, height: 38)
    }

    // MARK: - Narrative

    @ViewBuilder
    private var narrative: some View {
        if let text = narrativeText {
            MarkdownContentView(text, font: DesignSystem.Typography.bodyLarge)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            emptyContent
        }
    }

    private var emptyContent: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
            Text("No observations were recorded")
                .font(DesignSystem.Typography.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text("Make sure an AI provider is configured in Settings → AI Provider, and that Screen Recording permission is granted, so the Day Journal can analyze your captures.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.xxl)
    }

    // MARK: - Notes

    @ViewBuilder
    private var notesSection: some View {
        if let notes = session.userNotes, !notes.isEmpty {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Divider()
                Label("Your Notes", systemImage: "note.text")
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(notes)
                    .font(DesignSystem.Typography.body)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .textSelection(.enabled)
            }
        }
    }

    // MARK: - Derived

    private var narrativeText: String? {
        if let snapshot = session.finalSnapshot, !snapshot.isEmpty { return snapshot }
        if let summary = session.runningSummary, !summary.isEmpty { return summary }
        return nil
    }

    private var dayTitle: String {
        let f = DateFormatter()
        f.dateFormat = "EEEE, d MMMM"
        return f.string(from: session.createdAt)
    }

    private var subtitle: String {
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let start = timeFormatter.string(from: session.createdAt)
        guard let endedAt = session.endedAt else { return start }
        let end = timeFormatter.string(from: endedAt)
        return "\(start) – \(end) · \(durationText)"
    }

    private var durationText: String {
        guard let endedAt = session.endedAt else { return "—" }
        let seconds = max(0, Int(endedAt.timeIntervalSince(session.createdAt)))
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        if m > 0 { return "\(m)m" }
        return "<1m"
    }

    private var storageText: String {
        guard session.totalStorageBytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(session.totalStorageBytes), countStyle: .file)
    }
}

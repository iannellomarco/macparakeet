import SwiftUI
import MacParakeetCore

/// Read-only detail view for a past day journal entry.
struct JournalDayDetailView: View {
    let session: JournalSession

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.title ?? "Day Journal")
                        .font(.title)
                    Text(formattedDate)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label("\(session.screenshotCount) screenshots", systemImage: "photo")
                        if let endedAt = session.endedAt {
                            Text("•")
                            Text(formatDuration(from: session.createdAt, to: endedAt))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Divider()

                // Final snapshot
                if let snapshot = session.finalSnapshot, !snapshot.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day Summary")
                            .font(.headline)
                        Text(snapshot)
                            .font(.body)
                    }
                } else if let summary = session.runningSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day Summary")
                            .font(.headline)
                        Text(summary)
                            .font(.body)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Day Summary")
                            .font(.headline)
                        Text("No observations were recorded. Make sure an AI provider is configured in Settings → AI Provider.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // User notes
                if let notes = session.userNotes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Notes")
                            .font(.headline)
                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                }

                // Running summary (raw AI observations)
                if let summary = session.runningSummary, !summary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Raw Observations")
                            .font(.headline)
                        Text(summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .frame(maxWidth: 700)
        }
        .frame(minWidth: 400, idealWidth: 600)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: session.createdAt)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let interval = Int(end.timeIntervalSince(start))
        let hours = interval / 3600
        let minutes = (interval % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

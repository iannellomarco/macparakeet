import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Browse saved day journal entries.
/// Date-grouped list following the Meetings library pattern.
struct JournalLibraryView: View {
    @State var viewModel: JournalLibraryViewModel

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading journal entries...")
            } else if viewModel.sessions.isEmpty {
                emptyState
            } else {
                listView
            }
        }
        .task {
            viewModel.loadSessions()
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Day Journals Yet")
                .font(.title2)

            Text("Start a Day Journal from the Transcribe tab to capture and review your workday.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(groupedSessions.keys.sorted(by: >), id: \.self) { dateKey in
                Section(header: Text(dateKey).font(.headline)) {
                    ForEach(groupedSessions[dateKey] ?? []) { session in
                        JournalRowCard(session: session)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            if let session = groupedSessions[dateKey]?[index] {
                                viewModel.deleteSession(id: session.id)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    // MARK: - Helpers

    private var groupedSessions: [String: [JournalSession]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var groups: [String: [JournalSession]] = [:]
        for session in viewModel.sessions {
            let key = formatter.string(from: session.createdAt)
            groups[key, default: []].append(session)
        }
        return groups
    }
}

// MARK: - Row Card

private struct JournalRowCard: View {
    let session: JournalSession

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "camera.viewfinder")
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? formattedDate)
                    .font(.headline)

                if let snapshot = session.finalSnapshot {
                    Text(snapshot)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label("\(session.screenshotCount) screenshots", systemImage: "photo")
                    if let endedAt = session.endedAt {
                        Text("•")
                        Text(formatDuration(from: session.createdAt, to: endedAt))
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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

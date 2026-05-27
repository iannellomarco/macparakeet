import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Browse saved day journal entries with calendar navigation.
struct JournalLibraryView: View {
    @State var viewModel: JournalLibraryViewModel
    @State private var selectedDate: Date = Date()
    @State private var selectedSession: JournalSession?

    var body: some View {
        VStack(spacing: 0) {
            // Calendar picker
            calendarBar
                .padding(.horizontal)
                .padding(.top, 12)

            Divider()
                .padding(.top, 8)

            // Content
            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading journal entries...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            } else if viewModel.sessions.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                listView
            }
        }
        .navigationDestination(item: $selectedSession) { session in
            JournalDayDetailView(session: session)
                .navigationTitle(session.title ?? "Day Journal")
        }
        .task {
            viewModel.loadSessions()
        }
    }

    // MARK: - Calendar bar

    private var calendarBar: some View {
        HStack {
            Button {
                selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
            } label: {
                Image(systemName: "chevron.left")
            }
            .buttonStyle(.plain)

            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(width: 120)

            Button {
                let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                if next <= Date() {
                    selectedDate = next
                }
            } label: {
                Image(systemName: "chevron.right")
            }
            .buttonStyle(.plain)
            .disabled(Calendar.current.isDateInToday(selectedDate))

            Button("Today") {
                selectedDate = Date()
            }
            .buttonStyle(.link)
            .disabled(Calendar.current.isDateInToday(selectedDate))

            Spacer()

            Text("\(viewModel.sessions.count) entries")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Day Journal for this date")
                .font(.title2)

            Text("Start a Day Journal from the Transcribe tab to capture and review your workday.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if Calendar.current.isDateInToday(selectedDate) {
                Text("Today's journal will appear here after you stop and save it.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - List

    private var listView: some View {
        List {
            ForEach(sessionsForSelectedDate) { session in
                Button {
                    selectedSession = session
                } label: {
                    JournalRowCard(session: session)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.inset)
    }

    private var sessionsForSelectedDate: [JournalSession] {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? selectedDate

        return viewModel.sessions.filter {
            $0.createdAt >= dayStart && $0.createdAt < dayEnd
        }
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
                HStack {
                    Text(session.title ?? formattedTime)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                if let snapshot = session.finalSnapshot {
                    Text(cleanPreview(snapshot))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label("\(session.screenshotCount)", systemImage: "photo")
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
        .contentShape(Rectangle())
    }

    private var formattedTime: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: session.createdAt)
    }

    private func cleanPreview(_ text: String) -> String {
        // Remove markdown headers for preview
        text
            .replacingOccurrences(of: "# ", with: "")
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

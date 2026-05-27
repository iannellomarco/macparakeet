import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

struct JournalLibraryView: View {
    @State var viewModel: JournalLibraryViewModel
    @State private var selectedDate: Date = Date()
    @State private var selectedSession: JournalSession?

    private var datesWithEntries: Set<Date> {
        Set(viewModel.sessions.map {
            Calendar.current.startOfDay(for: $0.createdAt)
        })
    }

    var body: some View {
        VStack(spacing: 0) {
            calendarHeader
                .padding(.horizontal, 20)
                .padding(.top, 16)

            Divider().padding(.top, 12)

            if viewModel.isLoading {
                Spacer()
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(0.8)
                    Text("Loading…").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            } else if sessionsForDate.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                entriesList
            }
        }
        .navigationDestination(item: $selectedSession) { session in
            JournalDayDetailView(session: session)
                .navigationTitle(formattedNavTitle(session))
        }
        .task { viewModel.loadSessions() }
    }

    // MARK: - Calendar Header

    private var calendarHeader: some View {
        VStack(spacing: 12) {
            // Month + year title
            HStack {
                Button {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)

                Text(formattedMonthYear)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity)

                Button {
                    let next = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
                    if next <= Date() { selectedDate = next }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.body.weight(.medium))
                }
                .buttonStyle(.plain)
                .disabled(Calendar.current.isDateInToday(selectedDate))
            }

            // Day-of-week strip
            HStack(spacing: 0) {
                ForEach(dayLabels, id: \.self) { day in
                    Text(day)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Date grid (current week)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                    if Calendar.current.isDate(date, equalTo: Date.distantPast, toGranularity: .day) {
                        Color.clear.frame(height: 32)
                    } else {
                        dayCell(date)
                    }
                }
            }
        }
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasEntry = datesWithEntries.contains(Calendar.current.startOfDay(for: date))
        let isFuture = date > Date()

        return Button {
            selectedDate = date
        } label: {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.callout.weight(isSelected || isToday ? .semibold : .regular))
                .frame(height: 32)
                .frame(maxWidth: .infinity)
                .background(
                    isSelected
                        ? .blue.opacity(0.15)
                        : isToday ? .blue.opacity(0.05) : .clear
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .blue.opacity(0.3) : .clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(alignment: .bottom) {
                    if hasEntry && !isSelected {
                        Circle()
                            .fill(.blue.opacity(0.5))
                            .frame(width: 4, height: 4)
                            .padding(.bottom, 2)
                    }
                }
                    .foregroundColor(isSelected ? .blue : .primary)
                    .opacity(isFuture ? 0.4 : 1.0)
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private var dayLabels: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        return formatter.veryShortWeekdaySymbols
    }

    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: selectedDate)) ?? selectedDate
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: startOfWeek) }
    }

    private var formattedMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: selectedDate)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 40))
                .foregroundStyle(.secondary.opacity(0.5))

            Text("No journal for this day")
                .font(.title3.weight(.medium))

            if Calendar.current.isDateInToday(selectedDate) {
                Text("Your journal will appear here after you stop\nand save today's session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Start a Day Journal from the Transcribe tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(40)
    }

    // MARK: - Entries List

    private var entriesList: some View {
        List {
            ForEach(sessionsForDate) { session in
                Button { selectedSession = session } label: {
                    entryRow(session)
                }
                .buttonStyle(.plain)
            }
        }
        .listStyle(.plain)
    }

    private func entryRow(_ session: JournalSession) -> some View {
        HStack(spacing: 14) {
            // Time column
            VStack(spacing: 2) {
                Text(formattedTime(session.createdAt))
                    .font(.callout.weight(.medium))
                if let endedAt = session.endedAt {
                    Text(formatDuration(from: session.createdAt, to: endedAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 48, alignment: .leading)

            // Timeline dot
            VStack {
                Circle().fill(.blue).frame(width: 8, height: 8)
                Rectangle().fill(.blue.opacity(0.15)).frame(width: 1)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(session.title ?? "Day Journal")
                    .font(.body.weight(.medium))
                    .lineLimit(1)

                if let snapshot = session.finalSnapshot {
                    Text(cleanPreview(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Label("\(session.screenshotCount)", systemImage: "camera.fill")
                    if let meetings = extractMeetingCount(from: session) {
                        Text("•")
                        Label("\(meetings)", systemImage: "mic.fill")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.top, 2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 10)
    }

    private var sessionsForDate: [JournalSession] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: selectedDate)
        let end = cal.date(byAdding: .day, value: 1, to: start) ?? selectedDate
        return viewModel.sessions.filter { $0.createdAt >= start && $0.createdAt < end }
            .sorted { $0.createdAt < $1.createdAt }
    }

    // MARK: - Helpers

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: date)
    }

    private func formattedNavTitle(_ session: JournalSession) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE d MMMM"; return f.string(from: session.createdAt)
    }

    private func cleanPreview(_ text: String) -> String {
        text.replacingOccurrences(of: "# ", with: "")
           .replacingOccurrences(of: "**", with: "")
           .replacingOccurrences(of: "*", with: "")
           .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func formatDuration(from start: Date, to end: Date) -> String {
        let s = Int(end.timeIntervalSince(start))
        let h = s / 3600; let m = (s % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private func extractMeetingCount(from session: JournalSession) -> Int? {
        0 // placeholder — could be derived from analysis_runs
    }
}

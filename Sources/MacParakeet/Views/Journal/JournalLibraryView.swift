import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// The Journal tab — a master/detail workspace. A compact month calendar plus
/// the selected day's entries live in a left rail; the chosen entry's narrative
/// renders in a persistent reading pane on the right.
///
/// Selection is in-view state (no `NavigationStack` push), so the detail is
/// always reachable even though the tab is hosted inside the app's
/// `NavigationSplitView` detail column.
struct JournalLibraryView: View {
    @State var viewModel: JournalLibraryViewModel

    @State private var visibleMonth: Date = Date()
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var selectedSessionID: UUID?
    @State private var pendingDelete: JournalSession?
    @State private var didInitialSelection = false

    private let calendar = Calendar.current

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            HStack(spacing: 0) {
                rail
                    .frame(width: 272)
                    .background(DesignSystem.Colors.surfaceElevated.opacity(0.4))
                Divider()
                readingPane
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .background(DesignSystem.Colors.contentBackground)
        .task {
            viewModel.loadSessions()
            applyInitialSelectionIfNeeded()
        }
        .onChange(of: viewModel.sessions) { _, _ in
            applyInitialSelectionIfNeeded()
            reconcileSelection()
        }
        .alert("Delete this journal entry?", isPresented: deleteAlertBinding) {
            Button("Cancel", role: .cancel) { pendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let session = pendingDelete { performDelete(session) }
                pendingDelete = nil
            }
        } message: {
            Text("This day's narrative, notes, and its stored screenshots will be permanently deleted.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: DesignSystem.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Journal")
                    .font(DesignSystem.Typography.pageTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Your AI second brain, day by day.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer(minLength: DesignSystem.Spacing.md)

            if !calendar.isDateInToday(selectedDate) || !isViewingCurrentMonth {
                Button {
                    jumpToToday()
                } label: {
                    Label("Today", systemImage: "calendar")
                }
                .parakeetAction(.secondary)
                .controlSize(.small)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.lg)
        .padding(.vertical, DesignSystem.Spacing.md)
    }

    // MARK: - Left rail

    private var rail: some View {
        VStack(spacing: 0) {
            calendarBlock
                .padding(DesignSystem.Spacing.md)
            Divider()
            entryList
        }
    }

    private var calendarBlock: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            HStack {
                monthNavButton(systemName: "chevron.left") { shiftMonth(-1) }
                Spacer()
                Text(monthTitle)
                    .font(DesignSystem.Typography.body.weight(.semibold))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Spacer()
                monthNavButton(systemName: "chevron.right") { shiftMonth(1) }
                    .disabled(isViewingCurrentMonth)
                    .opacity(isViewingCurrentMonth ? 0.3 : 1)
            }

            HStack(spacing: 0) {
                ForEach(Array(orderedWeekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(DesignSystem.Typography.micro.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
                ForEach(Array(monthGridDays.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 30)
                    }
                }
            }
        }
    }

    private func monthNavButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let hasEntry = datesWithEntries.contains(calendar.startOfDay(for: date))
        let isFuture = date > Date()

        return Button {
            selectDay(date)
        } label: {
            VStack(spacing: 2) {
                Text("\(calendar.component(.day, from: date))")
                    .font(DesignSystem.Typography.bodySmall.weight(isSelected || isToday ? .semibold : .regular))
                    .foregroundStyle(dayTextColor(isSelected: isSelected, isToday: isToday, isFuture: isFuture))
                Circle()
                    .fill(hasEntry ? (isSelected ? DesignSystem.Colors.onAccent : DesignSystem.Colors.accent) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? DesignSystem.Colors.accent : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(isToday && !isSelected ? DesignSystem.Colors.accent.opacity(0.55) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
    }

    private func dayTextColor(isSelected: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isSelected { return DesignSystem.Colors.onAccent }
        if isFuture { return DesignSystem.Colors.textTertiary.opacity(0.6) }
        if isToday { return DesignSystem.Colors.accent }
        return DesignSystem.Colors.textPrimary
    }

    // MARK: - Entry list (selected day)

    private var entryList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(railListTitle)
                .font(DesignSystem.Typography.micro.weight(.semibold))
                .foregroundStyle(DesignSystem.Colors.textTertiary)
                .textCase(.uppercase)
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.top, DesignSystem.Spacing.md)
                .padding(.bottom, DesignSystem.Spacing.sm)

            if sessionsForSelectedDay.isEmpty {
                Text(calendar.isDateInToday(selectedDate) ? "No entry saved yet today." : "No entry for this day.")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textTertiary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                Spacer()
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(sessionsForSelectedDay) { session in
                            entryRow(session)
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.sm)
                    .padding(.bottom, DesignSystem.Spacing.md)
                }
            }
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func entryRow(_ session: JournalSession) -> some View {
        let isSelected = session.id == selectedSessionID
        return Button {
            selectedSessionID = session.id
        } label: {
            HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
                Text(timeFormatter.string(from: session.createdAt))
                    .font(DesignSystem.Typography.duration.weight(.medium))
                    .foregroundStyle(isSelected ? DesignSystem.Colors.accent : DesignSystem.Colors.textSecondary)
                    .frame(width: 40, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text(session.title ?? "Day Journal")
                        .font(DesignSystem.Typography.bodySmall.weight(.medium))
                        .foregroundStyle(DesignSystem.Colors.textPrimary)
                        .lineLimit(1)
                    if let preview = previewText(session) {
                        Text(preview)
                            .font(DesignSystem.Typography.caption)
                            .foregroundStyle(DesignSystem.Colors.textSecondary)
                            .lineLimit(2)
                    }
                    Label("\(session.screenshotCount)", systemImage: "camera.fill")
                        .font(DesignSystem.Typography.micro)
                        .foregroundStyle(DesignSystem.Colors.textTertiary)
                        .padding(.top, 1)
                }
                Spacer(minLength: 0)
            }
            .padding(DesignSystem.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.rowCornerRadius)
                    .fill(isSelected ? DesignSystem.Colors.accent.opacity(0.12) : .clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Layout.rowCornerRadius)
                    .stroke(isSelected ? DesignSystem.Colors.accent.opacity(0.35) : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reading pane

    @ViewBuilder
    private var readingPane: some View {
        if viewModel.isLoading && viewModel.sessions.isEmpty {
            loadingState
        } else if let session = selectedSession {
            JournalDayDetailView(session: session) {
                pendingDelete = session
            }
            .id(session.id)
        } else {
            dayEmptyState
        }
    }

    private var loadingState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ProgressView().scaleEffect(0.9)
            Text("Loading your journal…")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var dayEmptyState: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "book.closed")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(DesignSystem.Colors.accent.opacity(0.5))
            Text(viewModel.sessions.isEmpty ? "No journal entries yet" : "Nothing for \(mediumDateFormatter.string(from: selectedDate))")
                .font(DesignSystem.Typography.sectionTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(emptyStateDetail)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignSystem.Spacing.xl)
    }

    private var emptyStateDetail: String {
        if viewModel.sessions.isEmpty {
            return "Start a Day Journal from the Transcribe tab. After you stop and save a session, it appears here."
        }
        if calendar.isDateInToday(selectedDate) {
            return "Today's entry shows up here once you stop and save the session you're recording."
        }
        return "Pick another day from the calendar to read its entry."
    }

    // MARK: - Selection helpers

    private func selectDay(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        selectedSessionID = sessionsForSelectedDay.first?.id
    }

    private func jumpToToday() {
        visibleMonth = Date()
        selectDay(Date())
    }

    private func shiftMonth(_ delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: visibleMonth) else { return }
        // Never navigate the calendar past the current month.
        if delta > 0, calendar.compare(next, to: Date(), toGranularity: .month) == .orderedDescending { return }
        visibleMonth = next
    }

    private func applyInitialSelectionIfNeeded() {
        guard !didInitialSelection, !viewModel.sessions.isEmpty else { return }
        didInitialSelection = true
        if let latest = viewModel.sessions.max(by: { $0.createdAt < $1.createdAt }) {
            visibleMonth = latest.createdAt
            selectedDate = calendar.startOfDay(for: latest.createdAt)
            selectedSessionID = sessionsForSelectedDay.first?.id
        }
    }

    private func reconcileSelection() {
        let dayIDs = Set(sessionsForSelectedDay.map(\.id))
        if let id = selectedSessionID, dayIDs.contains(id) { return }
        selectedSessionID = sessionsForSelectedDay.first?.id
    }

    private func performDelete(_ session: JournalSession) {
        let wasSelected = session.id == selectedSessionID
        viewModel.deleteSession(id: session.id)
        if wasSelected {
            selectedSessionID = sessionsForSelectedDay.first?.id
        }
    }

    // MARK: - Derived data

    private var datesWithEntries: Set<Date> {
        Set(viewModel.sessions.map { calendar.startOfDay(for: $0.createdAt) })
    }

    private var sessionsForSelectedDay: [JournalSession] {
        viewModel.sessions
            .filter { calendar.isDate($0.createdAt, inSameDayAs: selectedDate) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedSession: JournalSession? {
        guard let id = selectedSessionID else { return nil }
        return viewModel.sessions.first { $0.id == id }
    }

    private var monthGridDays: [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstOfMonth = monthInterval.start
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let daysInMonth = calendar.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks)
        for offset in 0..<daysInMonth {
            cells.append(calendar.date(byAdding: .day, value: offset, to: firstOfMonth))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private var isViewingCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: Date(), toGranularity: .month)
    }

    private var railListTitle: String {
        if calendar.isDateInToday(selectedDate) { return "Today" }
        return mediumDateFormatter.string(from: selectedDate)
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }

    private func previewText(_ session: JournalSession) -> String? {
        let raw = session.finalSnapshot ?? session.runningSummary
        guard let raw, !raw.isEmpty else { return nil }
        let cleaned = raw
            .replacingOccurrences(of: "#", with: "")
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    // MARK: - Formatters

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f.string(from: visibleMonth)
    }

    private var timeFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }

    private var mediumDateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM"
        return f
    }
}

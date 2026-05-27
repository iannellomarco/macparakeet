import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

struct JournalSettingsSection: View {
    @State var viewModel: JournalSettingsViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 0) {
                settingsRow(
                    title: "Screenshot every",
                    detail: "Higher frequency = more detail, more storage",
                    content: {
                        Picker("", selection: Binding(get: { viewModel.captureInterval }, set: { viewModel.saveCaptureInterval($0) })) {
                            ForEach(JournalCaptureInterval.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).frame(width: 130)
                    }
                )

                Divider().padding(.leading, 12)

                settingsRow(
                    title: "Analyze every",
                    detail: "How often the AI reviews new screenshots",
                    content: {
                        Picker("", selection: Binding(get: { viewModel.analysisInterval }, set: { viewModel.saveAnalysisInterval($0) })) {
                            ForEach(JournalAnalysisInterval.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).frame(width: 130)
                    }
                )

                Divider().padding(.leading, 12)

                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Pause when idle", isOn: Binding(get: { viewModel.idleSkipEnabled }, set: { viewModel.saveIdleSkipEnabled($0) }))
                    Text("Stops capturing when you're away from your Mac")
                        .font(.caption).foregroundStyle(.secondary)
                    if viewModel.idleSkipEnabled {
                        Picker("After", selection: Binding(get: { viewModel.idleThreshold }, set: { viewModel.saveIdleThreshold($0) })) {
                            ForEach(JournalIdleThreshold.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).frame(width: 130)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)

                Divider().padding(.leading, 12)

                settingsRow(
                    title: "Keep screenshots for",
                    detail: "Older captures are automatically deleted",
                    content: {
                        Picker("", selection: Binding(get: { viewModel.retention }, set: { viewModel.saveRetention($0) })) {
                            ForEach(JournalRetention.allCases, id: \.rawValue) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.menu).frame(width: 130)
                    }
                )
            }
        } label: {
            Label("Day Journal", systemImage: "camera.viewfinder")
        }
    }

    private func settingsRow<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            content()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}

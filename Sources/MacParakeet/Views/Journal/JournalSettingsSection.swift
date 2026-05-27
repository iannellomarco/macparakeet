import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Settings section for Day Journal configuration.
/// Gated behind `AppFeatures.journalingEnabled`.
struct JournalSettingsSection: View {
    @State var viewModel: JournalSettingsViewModel

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 16) {
                // Capture interval
                VStack(alignment: .leading, spacing: 6) {
                    Text("Screenshot Interval")
                        .font(.headline)
                    Picker("Screenshot Interval", selection: Binding(
                        get: { viewModel.captureInterval },
                        set: { viewModel.saveCaptureInterval($0) }
                    )) {
                        ForEach(JournalCaptureInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    Text("How often to capture your screen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Analysis interval
                VStack(alignment: .leading, spacing: 6) {
                    Text("Analysis Interval")
                        .font(.headline)
                    Picker("Analysis Interval", selection: Binding(
                        get: { viewModel.analysisInterval },
                        set: { viewModel.saveAnalysisInterval($0) }
                    )) {
                        ForEach(JournalAnalysisInterval.allCases, id: \.rawValue) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    Text("How often the AI reviews new screenshots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Idle skip
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Skip captures when idle", isOn: Binding(
                        get: { viewModel.idleSkipEnabled },
                        set: { viewModel.saveIdleSkipEnabled($0) }
                    ))
                    if viewModel.idleSkipEnabled {
                        Picker("Idle threshold", selection: Binding(
                            get: { viewModel.idleThreshold },
                            set: { viewModel.saveIdleThreshold($0) }
                        )) {
                            ForEach(JournalIdleThreshold.allCases, id: \.rawValue) { threshold in
                                Text(threshold.label).tag(threshold)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: 200)
                    }
                    Text("Pauses capture when you step away from your Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Storage
                VStack(alignment: .leading, spacing: 6) {
                    Text("Storage Retention")
                        .font(.headline)
                    Picker("Retention", selection: Binding(
                        get: { viewModel.retention },
                        set: { viewModel.saveRetention($0) }
                    )) {
                        ForEach(JournalRetention.allCases, id: \.rawValue) { retention in
                            Text(retention.label).tag(retention)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: 200)
                    Text("Screenshots are automatically deleted after this period")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Divider()

                // Permission
                VStack(alignment: .leading, spacing: 6) {
                    Text("Screen Recording Permission")
                        .font(.headline)
                    HStack {
                        Image(systemName: viewModel.hasScreenRecordingPermission
                            ? "checkmark.circle.fill"
                            : "xmark.circle.fill")
                            .foregroundStyle(viewModel.hasScreenRecordingPermission
                                ? .green : .red)
                        Text(viewModel.hasScreenRecordingPermission
                            ? "Granted" : "Not granted")
                    }
                    if !viewModel.hasScreenRecordingPermission {
                        Button("Open Screen Recording Settings") {
                            _ = viewModel.requestScreenRecordingPermission()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .padding(8)
        } label: {
            Label("Day Journal", systemImage: "camera.viewfinder")
        }
    }
}

import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Tile on the Transcribe tab for starting/stopping day journal recording.
/// Gated behind `AppFeatures.journalingEnabled`.
struct JournalControlView: View {
    @State var viewModel: JournalControlViewModel

    var body: some View {
        GroupBox {
            VStack(spacing: 12) {
                if viewModel.isComputing {
                    computingView
                } else if viewModel.isJournaling {
                    recordingView
                } else if viewModel.isReviewing {
                    reviewingView
                } else {
                    idleView
                }
            }
            .padding(12)
        } label: {
            Label("Day Journal", systemImage: "camera.viewfinder")
        }
    }

    // MARK: - Idle state

    private var idleView: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)

            Text("Capture your workday for later review")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Screenshots are taken periodically, analyzed by AI, and reviewed at the end of your day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task { await viewModel.startJournaling() }
            } label: {
                Label("Start Day Journal", systemImage: "record.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    // MARK: - Recording state

    private var recordingView: some View {
        VStack(spacing: 8) {
            HStack {
                Circle()
                    .fill(.red)
                    .frame(width: 8, height: 8)
                    .opacity(blinkOpacity)

                Text("Recording")
                    .font(.headline)
                    .foregroundStyle(.red)
            }

            Text(formatElapsed(viewModel.elapsedSeconds))
                .font(.system(.title2, design: .monospaced))

            Text("\(viewModel.screenshotCount) screenshots captured")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Button(role: .destructive) {
                    Task { await viewModel.cancelJournaling() }
                } label: {
                    Label("Discard", systemImage: "trash")
                }
                .buttonStyle(.bordered)

                Button {
                    Task { await viewModel.stopJournaling() }
                } label: {
                    Label("Stop & Review", systemImage: "stop.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Reviewing state

    private var reviewingView: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.bubble")
                .font(.system(size: 28))
                .foregroundStyle(.blue)

            Text("Ready to Review")
                .font(.headline)

            Text("Open the review panel to chat with the AI about your day.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("\(viewModel.screenshotCount) screenshots captured")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Computing state

    private var computingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
                .padding(.bottom, 4)

            Text(viewModel.isReviewing
                ? "Generating day snapshot..."
                : "Processing final batch...")
                .font(.headline)

            Text("The AI is analyzing your day's activity. This may take a moment.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 250)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var blinkOpacity: Double {
        // Simple blink: toggle every second
        let seconds = Date().timeIntervalSince1970
        return seconds.truncatingRemainder(dividingBy: 2) < 1 ? 1.0 : 0.3
    }

    private func formatElapsed(_ totalSeconds: Int) -> String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

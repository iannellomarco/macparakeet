import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Tile on the Transcribe tab for starting/stopping day journal recording.
struct JournalControlView: View {
    @State var viewModel: JournalControlViewModel
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(.primary.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Idle state

    private var idleView: some View {
        VStack(spacing: 20) {
            // Hero icon
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 64, height: 64)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 6) {
                Text("Day Journal")
                    .font(.title3.weight(.semibold))
                Text("Your AI second brain")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Feature bullets
            VStack(alignment: .leading, spacing: 10) {
                featureRow(icon: "camera.fill", text: "Periodic screenshots of your work")
                featureRow(icon: "text.viewfinder", text: "On-device OCR — nothing leaves your Mac")
                featureRow(icon: "brain.fill", text: "AI analyzes your day, asks you questions")
                featureRow(icon: "book.fill", text: "End-of-day review chat with saved journal")
            }
            .padding(.horizontal, 16)

            Button {
                Task { await viewModel.startJournaling() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "record.circle")
                    Text("Start Journaling")
                }
                .font(.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 28)
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary.opacity(0.8))
        }
    }

    // MARK: - Recording state

    private var recordingView: some View {
        VStack(spacing: 16) {
            // Animated recording indicator
            ZStack {
                Circle()
                    .fill(.red.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
                Circle()
                    .fill(.red)
                    .frame(width: 16, height: 16)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseScale = 1.5
                }
            }

            VStack(spacing: 4) {
                Text("Recording your workday")
                    .font(.headline)
                Text(formatElapsed(viewModel.elapsedSeconds))
                    .font(.system(.largeTitle, design: .rounded).weight(.medium))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
            }

            // Stats row
            HStack(spacing: 24) {
                statBadge(count: "\(viewModel.screenshotCount)", label: "Captures")
            }
            .padding(.vertical, 4)

            // Actions
            HStack(spacing: 12) {
                Button(role: .destructive) {
                    Task { await viewModel.cancelJournaling() }
                } label: {
                    Label("Discard", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button {
                    Task { await viewModel.stopJournaling() }
                } label: {
                    Label("Stop & Review", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
    }

    private func statBadge(count: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(count)
                .font(.title3.weight(.semibold))
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Reviewing state

    private var reviewingView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.blue.opacity(0.08))
                    .frame(width: 56, height: 56)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.blue)
            }

            VStack(spacing: 4) {
                Text("Review Ready")
                    .font(.headline)
                Text("\(viewModel.screenshotCount) captures · \(formatElapsed(viewModel.elapsedSeconds))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Text("The AI has analyzed your day. A chat panel will open for you to review observations, answer questions, and save your journal.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Computing state

    private var computingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.3)

            VStack(spacing: 6) {
                Text("Processing…")
                    .font(.headline)
                Text(viewModel.isReviewing
                     ? "The AI is writing your day narrative"
                     : "Analyzing your latest screen captures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, 36)
        .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

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

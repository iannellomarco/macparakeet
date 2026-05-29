import SwiftUI
import MacParakeetCore
import MacParakeetViewModels

/// Tile on the Transcribe tab for starting/stopping day journal recording.
struct JournalControlView: View {
    @State var viewModel: JournalControlViewModel
    @State private var pulseScale: CGFloat = 1.0
    @Environment(\.openURL) private var openURL

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
        .background(DesignSystem.Colors.surface, in: RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Layout.cornerRadius)
                .stroke(DesignSystem.Colors.border, lineWidth: 1)
        )
        .cardShadow(DesignSystem.Shadows.cardRest)
    }

    // MARK: - Idle state

    private var idleView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accentLight)
                    .frame(width: 64, height: 64)
                Image(systemName: "camera.viewfinder")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(spacing: 6) {
                Text("Day Journal")
                    .font(DesignSystem.Typography.pageTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Your AI second brain")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                featureRow(icon: "camera.fill", text: "Periodic screenshots of your work")
                featureRow(icon: "text.viewfinder", text: "On-device OCR — nothing leaves your Mac")
                featureRow(icon: "brain.fill", text: "AI analyzes your day, asks you questions")
                featureRow(icon: "book.fill", text: "End-of-day review chat with saved journal")
            }
            .padding(.horizontal, DesignSystem.Spacing.md)

            if viewModel.needsScreenRecordingPermission {
                permissionBanner
                    .padding(.horizontal, DesignSystem.Spacing.lg)
            }

            Button {
                Task { await viewModel.startJournaling() }
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Image(systemName: "record.circle")
                    Text("Start Journaling")
                }
                .font(DesignSystem.Typography.body.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, DesignSystem.Spacing.xs)
            }
            .parakeetAction(.primaryProminent)
            .controlSize(.large)
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.xl)
    }

    private var permissionBanner: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.warningAmber)
            VStack(alignment: .leading, spacing: 2) {
                Text("Screen Recording permission needed")
                    .font(DesignSystem.Typography.bodySmall.weight(.medium))
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("Grant it in System Settings, then start again.")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }
            Spacer(minLength: 0)
            Button("Open Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    openURL(url)
                }
            }
            .parakeetAction(.secondary)
            .controlSize(.small)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(DesignSystem.Colors.warningAmber.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignSystem.Layout.rowCornerRadius))
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(DesignSystem.Colors.accent)
                .frame(width: 20)
            Text(text)
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
        }
    }

    // MARK: - Recording state

    private var recordingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Recording is a live-capture indicator — red is the correct semantic.
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.recordingRed.opacity(0.15))
                    .frame(width: 56, height: 56)
                    .scaleEffect(pulseScale)
                    .opacity(2.0 - pulseScale)
                Circle()
                    .fill(DesignSystem.Colors.recordingRed)
                    .frame(width: 16, height: 16)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false)) {
                    pulseScale = 1.5
                }
            }

            VStack(spacing: 4) {
                Text("Recording your workday")
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(formatElapsed(viewModel.elapsedSeconds))
                    .font(.system(.largeTitle, design: .rounded).weight(.medium).monospacedDigit())
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                    .contentTransition(.numericText())
            }

            statBadge(count: "\(viewModel.screenshotCount)", label: "Captures")
                .padding(.vertical, DesignSystem.Spacing.xs)

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(role: .destructive) {
                    Task { await viewModel.cancelJournaling() }
                } label: {
                    Label("Discard", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .parakeetAction(.destructive)
                .controlSize(.large)

                Button {
                    Task { await viewModel.stopJournaling() }
                } label: {
                    Label("Stop & Review", systemImage: "stop.fill")
                        .frame(maxWidth: .infinity)
                }
                .parakeetAction(.primaryProminent)
                .controlSize(.large)
            }
            .padding(.horizontal, DesignSystem.Spacing.lg)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    private func statBadge(count: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(count)
                .font(DesignSystem.Typography.pageTitle)
                .foregroundStyle(DesignSystem.Colors.textPrimary)
            Text(label)
                .font(DesignSystem.Typography.micro)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
        }
    }

    // MARK: - Reviewing state

    private var reviewingView: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            ZStack {
                Circle()
                    .fill(DesignSystem.Colors.accentLight)
                    .frame(width: 56, height: 56)
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DesignSystem.Colors.accent)
            }

            VStack(spacing: 4) {
                Text("Review Ready")
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text("\(viewModel.screenshotCount) captures · \(formatElapsed(viewModel.elapsedSeconds))")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
            }

            Text("The AI has analyzed your day. A chat panel will open for you to review observations, answer questions, and save your journal.")
                .font(DesignSystem.Typography.bodySmall)
                .foregroundStyle(DesignSystem.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DesignSystem.Spacing.md)
        }
        .padding(.vertical, DesignSystem.Spacing.lg)
    }

    // MARK: - Computing state

    private var computingView: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.3)

            VStack(spacing: 6) {
                Text("Processing…")
                    .font(DesignSystem.Typography.sectionTitle)
                    .foregroundStyle(DesignSystem.Colors.textPrimary)
                Text(viewModel.isReviewing
                     ? "The AI is writing your day narrative"
                     : "Analyzing your latest screen captures")
                    .font(DesignSystem.Typography.bodySmall)
                    .foregroundStyle(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xxl)
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

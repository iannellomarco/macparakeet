import AVFoundation
import os
import XCTest
@testable import MacParakeetCore

/// Integration tests that drive the real `AVAudioEngineMicrophonePlatform`
/// against a real microphone, verifying the contract `SharedMicrophoneStream`
/// is supposed to enforce per ADR-015 and PR #189:
///
///   Subscribe → buffers arrive within deadline, regardless of prior state.
///
/// These complement the existing mock-based `SharedMicrophoneStreamTests`,
/// which exercise orchestration but cannot reach the real macOS HAL where
/// the `2026-05-03` silent-tap-stall bug lives. See:
///   - `journal/2026-05-03-dictation-silent-stall.md` (diagnosis)
///   - `plans/active/2026-05-dictation-stall-integration-tests.md` (this plan)
///   - PR #210 (passive instrumentation that paired with this work)
///
/// ## Running
///
/// Default `swift test` skips this suite. To run:
///
/// ```
/// MACPARAKEET_HARDWARE_TESTS=1 swift test \
///     --filter MicrophoneEngineRealPlatformTests
/// ```
///
/// The 3-minute idle-gap test is additionally gated on
/// `MACPARAKEET_SLOW_HARDWARE_TESTS=1` so a normal hardware run stays under
/// ~30 seconds.
///
/// ## Why these can't run in CI
///
/// Real microphone access requires TCC permission for the test runner and a
/// live (or virtual) input device on the host. Headless CI has neither.
/// Wiring this into CI would mean per-runner mic provisioning plus
/// non-deterministic outputs — both bigger problems than this suite solves.
final class MicrophoneEngineRealPlatformTests: XCTestCase {

    /// First-buffer deadline. Production captures show 100–200 ms first-buffer
    /// latency on a healthy system; 1 s is a 5× safety margin.
    private static let firstBufferDeadline: TimeInterval = 1.0

    /// Production buffer size used by both dictation and meeting recording.
    private static let bufferSize: AVAudioFrameCount = 4096

    private var platform: AVAudioEngineMicrophonePlatform!

    override func setUpWithError() throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["MACPARAKEET_HARDWARE_TESTS"] == "1",
            "Set MACPARAKEET_HARDWARE_TESTS=1 to run real-platform integration tests."
        )
        platform = AVAudioEngineMicrophonePlatform()
    }

    override func tearDown() async throws {
        platform?.stopEngine()
        platform = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    /// Cold-start case: a fresh `AVAudioEngineMicrophonePlatform` in a fresh
    /// process must deliver buffers within the deadline. If this fails, the
    /// platform itself is broken and the bug doesn't even need a transition
    /// to manifest.
    func testColdStartDeliversBuffers() async throws {
        let count = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        XCTAssertGreaterThan(
            count, 0,
            "Cold-start subscribe should deliver at least one buffer within \(Self.firstBufferDeadline)s."
        )
    }

    /// Cycle case: subscribe → stop → subscribe. Exercises the engine
    /// teardown/recreate path that PR #189 introduced. The bug hypothesis is
    /// that the freshly-created `AVAudioEngine` reports `isRunning = true`
    /// from `start()` but the HAL hasn't actually attached yet.
    func testPostCycleDeliversBuffers() async throws {
        _ = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        platform.stopEngine()

        let count = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        XCTAssertGreaterThan(
            count, 0,
            "Subscribe immediately after stop should deliver buffers — engine recreate must not lose the input chain."
        )
    }

    /// VPIO transition case: subscribe with VPIO enabled (simulates meeting
    /// recording starting), then with VPIO disabled (simulates dictation).
    /// This is the path the journal originally suspected before the
    /// invariant framing widened the hypothesis.
    func testPostVPIODeliversBuffers() async throws {
        _ = try await subscribeAndAwaitFirstBuffer(vpioEnabled: true)
        platform.stopEngine()

        let count = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        XCTAssertGreaterThan(
            count, 0,
            "Subscribe after VPIO teardown should deliver buffers — coreaudiod's VPAU aggregate must release cleanly."
        )
    }

    /// Stress: 10 back-to-back subscribe/stop cycles. If any one cycle fails
    /// to deliver buffers, surface which cycle. Catches timing-flaky variants
    /// of the bug that pass single-shot tests.
    func testStressTenCycles() async throws {
        for cycle in 0..<10 {
            let count = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
            XCTAssertGreaterThan(
                count, 0,
                "Cycle \(cycle) should deliver buffers within \(Self.firstBufferDeadline)s."
            )
            platform.stopEngine()
        }
    }

    /// Idle-gap case: matches the wall-clock signature of the journal-reported
    /// stall (2:42 idle gap before the failure). Coreaudiod state during long
    /// idle is the leading suspect; tests with shorter gaps may not surface it.
    ///
    /// Gated separately because it sleeps 3 minutes wall-clock.
    func testIdleGapDeliversBuffers() async throws {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["MACPARAKEET_SLOW_HARDWARE_TESTS"] == "1",
            "Set MACPARAKEET_SLOW_HARDWARE_TESTS=1 to run the 3-minute idle-gap test."
        )

        _ = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        platform.stopEngine()

        try await Task.sleep(for: .seconds(180))

        let count = try await subscribeAndAwaitFirstBuffer(vpioEnabled: false)
        XCTAssertGreaterThan(
            count, 0,
            "Subscribe after 3-min idle should deliver buffers — coreaudiod state during long idle must not break the input chain."
        )
    }

    // MARK: - Helpers

    /// Configure the platform, install a counting tap, and return the buffer
    /// count seen by the deadline. Throws if `configureAndStart` itself fails
    /// (e.g. mic permission denied) — tests should propagate that.
    private func subscribeAndAwaitFirstBuffer(vpioEnabled: Bool) async throws -> Int {
        let counter = OSAllocatedUnfairLock(initialState: 0)

        try platform.configureAndStart(
            vpioEnabled: vpioEnabled,
            bufferSize: Self.bufferSize
        ) { _, _ in
            counter.withLock { $0 += 1 }
        }

        return await awaitNonZero(counter: counter, timeout: Self.firstBufferDeadline)
    }

    /// Poll the counter every 20 ms until it goes nonzero or the deadline
    /// passes. Returns the final count. Polling beats `XCTestExpectation`
    /// here because the tap closure is `@Sendable` and must remain so —
    /// expectations under Swift 6 strict concurrency add ceremony for no
    /// diagnostic gain.
    private func awaitNonZero(
        counter: OSAllocatedUnfairLock<Int>,
        timeout: TimeInterval
    ) async -> Int {
        let deadline = ContinuousClock.now + .seconds(timeout)
        while ContinuousClock.now < deadline {
            let n = counter.withLock { $0 }
            if n > 0 { return n }
            try? await Task.sleep(for: .milliseconds(20))
        }
        return counter.withLock { $0 }
    }
}

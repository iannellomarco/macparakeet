import Foundation
import CoreGraphics

// MARK: - Protocol

public protocol JournalIdleDetectorProtocol: Sendable {
    func isUserIdle(thresholdSeconds: Int) -> Bool
}

// MARK: - Implementation

public final class JournalIdleDetector: JournalIdleDetectorProtocol {

    public init() {}

    public func isUserIdle(thresholdSeconds: Int) -> Bool {
        let idleSeconds = CGEventSource.secondsSinceLastEventType(
            .combinedSessionState,
            eventType: CGEventType(rawValue: UInt32.max)!
        )
        return idleSeconds >= Double(thresholdSeconds)
    }
}

import AppKit
import XCTest
@testable import MacParakeetCore

@MainActor
final class ClipboardServiceTests: XCTestCase {
    func testDefaultRestoreDelayLeavesRoomForAsyncPasteConsumers() {
        XCTAssertGreaterThanOrEqual(
            ClipboardService.defaultClipboardRestoreDelay,
            0.75,
            "Restoring too soon can make slow target apps paste the previously saved clipboard item."
        )
    }

    func testPasteboardWriteFailureHasActionableDescription() {
        XCTAssertEqual(
            ClipboardServiceError.pasteboardWriteFailed.errorDescription,
            "Paste automation unavailable (could not write transcript to the clipboard)."
        )
    }

    func testPasteTextRestoresOriginalClipboardAfterConfiguredDelay() async throws {
        let pasteboard = makeScratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        replacePasteboard(pasteboard, with: "original")

        var pastedStrings: [String] = []
        let service = ClipboardService(
            pasteboard: pasteboard,
            eventPosting: RecordingClipboardEventPosting {
                pastedStrings.append(pasteboard.string(forType: .string) ?? "")
            },
            clipboardRestoreDelay: Self.shortRestoreDelay
        )

        try await service.pasteText("dictation")

        XCTAssertEqual(pastedStrings, ["dictation"])
        XCTAssertEqual(pasteboard.string(forType: .string), "dictation")

        try await waitForPasteboardString("original", on: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testOverlappingPasteTextRestoresPreExistingClipboard() async throws {
        let pasteboard = makeScratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        replacePasteboard(pasteboard, with: "original")

        var pastedStrings: [String] = []
        let service = ClipboardService(
            pasteboard: pasteboard,
            eventPosting: RecordingClipboardEventPosting {
                pastedStrings.append(pasteboard.string(forType: .string) ?? "")
            },
            clipboardRestoreDelay: Self.shortRestoreDelay
        )

        try await service.pasteText("first dictation")
        try await service.pasteText("second dictation")

        XCTAssertEqual(pastedStrings, ["first dictation", "second dictation"])
        XCTAssertEqual(pasteboard.string(forType: .string), "second dictation")

        try await waitForPasteboardString("original", on: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testUserClipboardChangeDuringRestoreWindowIsNotClobbered() async throws {
        let pasteboard = makeScratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        replacePasteboard(pasteboard, with: "original")

        let service = ClipboardService(
            pasteboard: pasteboard,
            eventPosting: RecordingClipboardEventPosting(),
            clipboardRestoreDelay: Self.shortRestoreDelay
        )

        try await service.pasteText("dictation")
        replacePasteboard(pasteboard, with: "user copy")

        try await waitPastRestoreWindow()

        XCTAssertEqual(pasteboard.string(forType: .string), "user copy")
    }

    func testPasteAfterUserClipboardChangeUsesNewClipboardAsRestoreTarget() async throws {
        let pasteboard = makeScratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        replacePasteboard(pasteboard, with: "original")

        let service = ClipboardService(
            pasteboard: pasteboard,
            eventPosting: RecordingClipboardEventPosting(),
            clipboardRestoreDelay: Self.shortRestoreDelay
        )

        try await service.pasteText("first dictation")
        replacePasteboard(pasteboard, with: "user copy")
        try await service.pasteText("second dictation")

        try await waitForPasteboardString("user copy", on: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "user copy")
    }

    func testCopyToClipboardCancelsPendingRestore() async throws {
        let pasteboard = makeScratchPasteboard()
        defer { pasteboard.releaseGlobally() }
        replacePasteboard(pasteboard, with: "original")

        let service = ClipboardService(
            pasteboard: pasteboard,
            eventPosting: RecordingClipboardEventPosting(),
            clipboardRestoreDelay: Self.shortRestoreDelay
        )

        try await service.pasteText("dictation")
        await service.copyToClipboard("manual copy")

        try await waitPastRestoreWindow()

        XCTAssertEqual(pasteboard.string(forType: .string), "manual copy")
    }

    private static let shortRestoreDelay: TimeInterval = 0.03

    private func makeScratchPasteboard() -> NSPasteboard {
        NSPasteboard(name: NSPasteboard.Name("com.macparakeet.tests.clipboard.\(UUID().uuidString)"))
    }

    private func replacePasteboard(_ pasteboard: NSPasteboard, with string: String) {
        pasteboard.clearContents()
        XCTAssertTrue(pasteboard.setString(string, forType: .string))
    }

    private func waitForPasteboardString(
        _ expected: String,
        on pasteboard: NSPasteboard,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if pasteboard.string(forType: .string) == expected {
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }

        XCTAssertEqual(pasteboard.string(forType: .string), expected, file: file, line: line)
    }

    private func waitPastRestoreWindow() async throws {
        try await Task.sleep(for: .milliseconds(300))
    }
}

@MainActor
private final class RecordingClipboardEventPosting: ClipboardEventPosting {
    private let onPaste: @MainActor () throws -> Void

    init(onPaste: @escaping @MainActor () throws -> Void = {}) {
        self.onPaste = onPaste
    }

    func simulatePaste(using pasteShortcutKeyResolver: PasteShortcutKeyResolver) throws {
        try onPaste()
    }

    func simulateKeystroke(_ keyCode: UInt16) throws {}
}

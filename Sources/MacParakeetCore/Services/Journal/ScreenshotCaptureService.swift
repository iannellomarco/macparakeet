import Foundation
import CoreGraphics
import ImageIO

// MARK: - Captured Screenshot (non-DB value type)

public struct CapturedScreenshot: Sendable {
    public let id: UUID
    public let imageData: Data
    public let displayName: String
    public let displayWidth: Int
    public let displayHeight: Int
    public let capturedAt: Date

    public init(
        id: UUID = UUID(),
        imageData: Data,
        displayName: String,
        displayWidth: Int,
        displayHeight: Int,
        capturedAt: Date = Date()
    ) {
        self.id = id
        self.imageData = imageData
        self.displayName = displayName
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.capturedAt = capturedAt
    }
}

// MARK: - Protocol

public protocol ScreenshotCaptureServiceProtocol: Sendable {
    func captureAllDisplays() async throws -> [CapturedScreenshot]
}

// MARK: - Implementation

public final class ScreenshotCaptureService: ScreenshotCaptureServiceProtocol {
    private let permissionService: PermissionServiceProtocol
    private let jpegQuality: CGFloat

    public init(
        permissionService: PermissionServiceProtocol = PermissionService(),
        jpegQuality: CGFloat = 0.7
    ) {
        self.permissionService = permissionService
        self.jpegQuality = jpegQuality
    }

    public func captureAllDisplays() async throws -> [CapturedScreenshot] {
        guard permissionService.checkScreenRecordingPermission() else {
            return []
        }

        var displayCount: UInt32 = 0
        guard let displayIDs = activeDisplayIDs(&displayCount) else {
            return []
        }

        var screenshots: [CapturedScreenshot] = []
        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]
            guard let cgImage = CGDisplayCreateImage(displayID) else {
                continue
            }
            let width = CGDisplayPixelsWide(displayID)
            let height = CGDisplayPixelsHigh(displayID)
            let displayName = "Display \(i + 1) (\(width)×\(height))"

            if let data = encodeJPEG(cgImage: cgImage) {
                screenshots.append(CapturedScreenshot(
                    imageData: data,
                    displayName: displayName,
                    displayWidth: Int(width),
                    displayHeight: Int(height)
                ))
            }
        }
        displayIDs.deallocate()
        return screenshots
    }

    // MARK: - JPEG encoding

    private func encodeJPEG(cgImage: CGImage) -> Data? {
        guard let mutableData = CFDataCreateMutable(nil, 0),
              let destination = CGImageDestinationCreateWithData(
                mutableData, "public.jpeg" as CFString, 1, nil
              )
        else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: jpegQuality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            return nil
        }
        return mutableData as Data
    }

    private func activeDisplayIDs(_ count: UnsafeMutablePointer<UInt32>) -> UnsafeMutablePointer<CGDirectDisplayID>? {
        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success else {
            return nil
        }
        let displayIDs = UnsafeMutablePointer<CGDirectDisplayID>.allocate(capacity: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, displayIDs, &displayCount) == .success else {
            displayIDs.deallocate()
            return nil
        }
        count.pointee = displayCount
        return displayIDs
    }
}

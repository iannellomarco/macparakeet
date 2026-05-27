import Foundation

// MARK: - Protocol

public protocol JournalStorageManagerProtocol: Sendable {
    func saveScreenshot(id: UUID, imageData: Data, sessionId: UUID) throws -> URL
    func deleteSessionFolder(sessionId: UUID) throws
    func enforceRetention(retentionDays: Int, sessionId: UUID) throws -> Int
    func storageUsedBytes(sessionId: UUID) throws -> Int64
}

// MARK: - Implementation

public final class JournalStorageManager: JournalStorageManagerProtocol, @unchecked Sendable {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    public static var journalBasePath: String {
        "\(AppPaths.appSupportDir)/journal"
    }

    // MARK: - Save

    public func saveScreenshot(id: UUID, imageData: Data, sessionId: UUID) throws -> URL {
        let folder = sessionFolder(sessionId)
        try fileManager.createDirectory(atPath: folder, withIntermediateDirectories: true)

        let filePath = folder + "/screenshot_\(id.uuidString).jpg"
        let url = URL(fileURLWithPath: filePath)
        try imageData.write(to: url)
        return url
    }

    // MARK: - Delete

    public func deleteSessionFolder(sessionId: UUID) throws {
        let folder = sessionFolder(sessionId)
        if fileManager.fileExists(atPath: folder) {
            try fileManager.removeItem(atPath: folder)
        }
    }

    // MARK: - Retention

    public func enforceRetention(retentionDays: Int, sessionId: UUID) throws -> Int {
        let folder = sessionFolder(sessionId)
        guard fileManager.fileExists(atPath: folder) else { return 0 }

        let files = try fileManager.contentsOfDirectory(atPath: folder)
        let cutoff = Date().addingTimeInterval(-Double(retentionDays) * 86400)
        var deletedCount = 0

        for file in files {
            let fullPath = folder + "/" + file
            let attrs = try fileManager.attributesOfItem(atPath: fullPath)
            if let creationDate = attrs[.creationDate] as? Date,
               creationDate < cutoff,
               file.hasPrefix("screenshot_") {
                try fileManager.removeItem(atPath: fullPath)
                deletedCount += 1
            }
        }
        return deletedCount
    }

    // MARK: - Storage

    public func storageUsedBytes(sessionId: UUID) throws -> Int64 {
        let folder = sessionFolder(sessionId)
        guard fileManager.fileExists(atPath: folder) else { return 0 }

        let files = try fileManager.contentsOfDirectory(atPath: folder)
        var total: Int64 = 0
        for file in files where file.hasPrefix("screenshot_") {
            let fullPath = folder + "/" + file
            let attrs = try fileManager.attributesOfItem(atPath: fullPath)
            total += (attrs[.size] as? Int64) ?? 0
        }
        return total
    }

    // MARK: - Helpers

    private func sessionFolder(_ sessionId: UUID) -> String {
        "\(Self.journalBasePath)/\(sessionId.uuidString)"
    }
}

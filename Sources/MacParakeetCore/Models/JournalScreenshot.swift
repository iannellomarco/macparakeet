import Foundation
import GRDB

public struct JournalScreenshot: Codable, Identifiable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var capturedAt: Date
    public var filePath: String
    public var ocrText: String?
    public var ocrConfidence: Double?
    public var fileSizeBytes: Int?
    public var displayName: String?
    public var displayWidth: Int?
    public var displayHeight: Int?
    public var isDiscarded: Bool

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        capturedAt: Date = Date(),
        filePath: String,
        ocrText: String? = nil,
        ocrConfidence: Double? = nil,
        fileSizeBytes: Int? = nil,
        displayName: String? = nil,
        displayWidth: Int? = nil,
        displayHeight: Int? = nil,
        isDiscarded: Bool = false
    ) {
        self.id = id
        self.sessionId = sessionId
        self.capturedAt = capturedAt
        self.filePath = filePath
        self.ocrText = ocrText
        self.ocrConfidence = ocrConfidence
        self.fileSizeBytes = fileSizeBytes
        self.displayName = displayName
        self.displayWidth = displayWidth
        self.displayHeight = displayHeight
        self.isDiscarded = isDiscarded
    }
}

extension JournalScreenshot: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "journal_screenshots"

    public enum Columns: String, ColumnExpression {
        case id, sessionId, capturedAt, filePath
        case ocrText, ocrConfidence, fileSizeBytes
        case displayName, displayWidth, displayHeight
        case isDiscarded
    }
}

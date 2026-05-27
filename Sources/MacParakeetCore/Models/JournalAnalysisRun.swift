import Foundation
import GRDB

public struct JournalAnalysisRun: Codable, Identifiable, Sendable {
    public var id: UUID
    public var sessionId: UUID
    public var runAt: Date
    public var screenshotCount: Int
    public var ocrTextInput: String
    public var analysis: String
    public var questionsJSON: String?
    public var providerModel: String?
    public var latencyMs: Int?
    public var wasUsed: Bool

    public init(
        id: UUID = UUID(),
        sessionId: UUID,
        runAt: Date = Date(),
        screenshotCount: Int,
        ocrTextInput: String,
        analysis: String,
        questionsJSON: String? = nil,
        providerModel: String? = nil,
        latencyMs: Int? = nil,
        wasUsed: Bool = true
    ) {
        self.id = id
        self.sessionId = sessionId
        self.runAt = runAt
        self.screenshotCount = screenshotCount
        self.ocrTextInput = ocrTextInput
        self.analysis = analysis
        self.questionsJSON = questionsJSON
        self.providerModel = providerModel
        self.latencyMs = latencyMs
        self.wasUsed = wasUsed
    }
}

extension JournalAnalysisRun: FetchableRecord, PersistableRecord {
    public static let databaseTableName = "journal_analysis_runs"

    public enum Columns: String, ColumnExpression {
        case id, sessionId, runAt, screenshotCount
        case ocrTextInput, analysis, questionsJSON
        case providerModel, latencyMs, wasUsed
    }
}

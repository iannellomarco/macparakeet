import Foundation
import MacParakeetCore
import OSLog

@MainActor
@Observable
public final class JournalLibraryViewModel {
    public var sessions: [JournalSession] = []
    public var isLoading: Bool = false

    private var sessionRepo: JournalSessionRepositoryProtocol?
    private var storageManager: JournalStorageManagerProtocol?
    private let logger = Logger(
        subsystem: "com.macparakeet.viewmodels",
        category: "JournalLibrary"
    )

    public init() {}

    public func configure(
        sessionRepo: JournalSessionRepositoryProtocol?,
        storageManager: JournalStorageManagerProtocol? = nil
    ) {
        self.sessionRepo = sessionRepo
        self.storageManager = storageManager
    }

    public func loadSessions() {
        guard let repo = sessionRepo else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            sessions = try repo.fetchAll(limit: nil)
                .filter { $0.status == .completed }
        } catch {
            logger.error("Failed to load journal sessions: \(error.localizedDescription)")
        }
    }

    public func deleteSession(id: UUID) {
        guard let repo = sessionRepo else { return }
        do {
            _ = try repo.delete(id: id)
            // Remove the on-disk screenshot folder too — DB cascade only clears
            // the rows, not the JPEG files in the session folder.
            do {
                try storageManager?.deleteSessionFolder(sessionId: id)
            } catch {
                logger.error("Failed to delete journal screenshot folder: \(error.localizedDescription)")
            }
            sessions.removeAll { $0.id == id }
        } catch {
            logger.error("Failed to delete journal session: \(error.localizedDescription)")
        }
    }
}

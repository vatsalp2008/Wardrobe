import Foundation

/// Caches gap analysis results, which are expensive to compute (spec §5.4: cache 24h).
/// Phase 4 backs this with Core Data; Phase 0 ships `InMemoryGapRepository`.
protocol GapRepositoryProtocol: Sendable {
    func cachedSuggestions() async throws -> [GapSuggestion]?
    func save(_ suggestions: [GapSuggestion]) async throws
    /// Whether the cached result is still within its freshness window.
    func isCacheValid(maxAge: TimeInterval) async -> Bool
}

actor InMemoryGapRepository: GapRepositoryProtocol {
    private var suggestions: [GapSuggestion] = []
    private var lastUpdated: Date?

    func cachedSuggestions() async throws -> [GapSuggestion]? {
        suggestions.isEmpty ? nil : suggestions
    }

    func save(_ suggestions: [GapSuggestion]) async throws {
        self.suggestions = suggestions
        self.lastUpdated = suggestions.map(\.generatedAt).max()
    }

    func isCacheValid(maxAge: TimeInterval) async -> Bool {
        guard let lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) < maxAge
    }
}

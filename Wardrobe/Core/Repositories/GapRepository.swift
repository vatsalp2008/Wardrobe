import CoreData
import Foundation

/// Caches gap analysis results, which are expensive to compute (spec §5.4: cache 24h). The app
/// uses `CoreDataGapRepository`; `InMemoryGapRepository` backs tests and previews.
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

/// Local-first Core Data implementation. Persisting the cache is what makes the 24h freshness
/// window meaningful — before this, every relaunch forced a fresh (paid) stylist call.
final class CoreDataGapRepository: GapRepositoryProtocol, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    /// Returns suggestions in their original ranked order, or nil when nothing is cached —
    /// callers treat nil as "no cache", so an empty array must not be returned in its place.
    func cachedSuggestions() async throws -> [GapSuggestion]? {
        try await stack.container.performBackgroundTask { context in
            let request = GapSuggestionEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "rank", ascending: true)]
            let results = try context.fetch(request).map { $0.toModel() }
            return results.isEmpty ? nil : results
        }
    }

    /// Replaces the whole cache. Deletes through the context rather than with an
    /// `NSBatchDeleteRequest`, which bypasses contexts and misbehaves against an in-memory store.
    func save(_ suggestions: [GapSuggestion]) async throws {
        try await stack.container.performBackgroundTask { context in
            for entity in try context.fetch(GapSuggestionEntity.fetchRequest()) {
                context.delete(entity)
            }
            for (index, suggestion) in suggestions.enumerated() {
                GapSuggestionEntity(context: context).update(from: suggestion, rank: index)
            }
            try context.save()
        }
    }

    func isCacheValid(maxAge: TimeInterval) async -> Bool {
        guard let lastUpdated = await newestTimestamp() else { return false }
        return Date().timeIntervalSince(lastUpdated) < maxAge
    }

    /// Timestamp of the freshest cached suggestion, or nil when the cache is empty or unreadable.
    /// The protocol method isn't throwing, so a fetch failure is treated as "no cache".
    private func newestTimestamp() async -> Date? {
        try? await stack.container.performBackgroundTask { context in
            let request = GapSuggestionEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "generatedAt", ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first?.generatedAt
        }
    }
}

import Foundation

/// Caches try-on renders so a previously composited outfit loads instantly (spec §5.3).
/// Phase 3 backs this with Core Data + Supabase; Phase 0 ships `InMemoryTryOnRepository`.
protocol TryOnRepositoryProtocol: Sendable {
    func cachedResult(for outfitID: UUID) async throws -> TryOnResult?
    func save(_ result: TryOnResult) async throws
}

actor InMemoryTryOnRepository: TryOnRepositoryProtocol {
    private var results: [UUID: TryOnResult] = [:]

    func cachedResult(for outfitID: UUID) async throws -> TryOnResult? {
        results[outfitID]
    }

    func save(_ result: TryOnResult) async throws {
        results[result.outfitID] = result
    }
}

import Foundation

/// Persists generated outfits and their wear/favorite state (spec §5.2). Phase 2 backs this
/// with Core Data; Phase 0 ships `InMemoryOutfitRepository`.
protocol OutfitRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [Outfit]
    func save(_ outfits: [Outfit]) async throws
    func setFavorite(id: UUID, isFavorited: Bool) async throws
    func recordWorn(id: UUID, on date: Date) async throws
}

actor InMemoryOutfitRepository: OutfitRepositoryProtocol {
    private var outfits: [Outfit] = []

    func fetchAll() async throws -> [Outfit] {
        outfits.sorted { $0.generatedAt > $1.generatedAt }
    }

    func save(_ outfits: [Outfit]) async throws {
        self.outfits = outfits
    }

    func setFavorite(id: UUID, isFavorited: Bool) async throws {
        guard let index = outfits.firstIndex(where: { $0.id == id }) else { return }
        outfits[index].isFavorited = isFavorited
    }

    func recordWorn(id: UUID, on date: Date) async throws {
        guard let index = outfits.firstIndex(where: { $0.id == id }) else { return }
        outfits[index].wornOn.append(date)
    }
}

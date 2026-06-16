import Foundation

/// Abstracts the wardrobe data source (spec §3.2). Phase 1 backs this with Core Data
/// (local-first) and image upload via Supabase; Phase 0 ships `InMemoryWardrobeRepository`
/// seeded from `SampleData`.
protocol WardrobeRepositoryProtocol: Sendable {
    func fetchAll() async throws -> [ClothingItem]
    func add(_ item: ClothingItem) async throws
    func update(_ item: ClothingItem) async throws
    func delete(id: UUID) async throws
    /// Increments wear count and stamps `lastWorn` (spec §5.2 wear tracker).
    func markWorn(id: UUID, on date: Date) async throws
}

actor InMemoryWardrobeRepository: WardrobeRepositoryProtocol {
    private var items: [ClothingItem]

    init(seed: [ClothingItem] = SampleData.items) {
        self.items = seed
    }

    func fetchAll() async throws -> [ClothingItem] {
        items.sorted { $0.dateAdded > $1.dateAdded }
    }

    func add(_ item: ClothingItem) async throws {
        items.append(item)
    }

    func update(_ item: ClothingItem) async throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
    }

    func delete(id: UUID) async throws {
        items.removeAll { $0.id == id }
    }

    func markWorn(id: UUID, on date: Date) async throws {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].wearCount += 1
        items[index].lastWorn = date
    }
}

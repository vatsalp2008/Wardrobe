import CoreData
import Foundation

/// Persists generated outfits and their wear/favorite state (spec §5.2). The app uses
/// `CoreDataOutfitRepository`; `InMemoryOutfitRepository` backs tests and previews.
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

/// Local-first Core Data implementation. All work runs on a background context; results are
/// mapped to the `Sendable` `Outfit` value type before crossing the concurrency boundary.
final class CoreDataOutfitRepository: OutfitRepositoryProtocol, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchAll() async throws -> [Outfit] {
        try await stack.container.performBackgroundTask { context in
            let request = OutfitEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "generatedAt", ascending: false)]
            return try context.fetch(request).map { $0.toModel() }
        }
    }

    /// Upserts the incoming batch, then prunes previously-saved outfits that are *not* in it.
    ///
    /// Unlike the in-memory repository this is not a blind replace: outfits the user favorited or
    /// actually wore are kept. A blind replace would delete them on every feed refresh, which
    /// would make favoriting and wear history pointless once they're persisted at all.
    func save(_ outfits: [Outfit]) async throws {
        try await stack.container.performBackgroundTask { context in
            let itemsByID = try Self.resolveItems(for: outfits, in: context)

            for outfit in outfits {
                let entity = try Self.entity(with: outfit.id, in: context) ?? OutfitEntity(context: context)
                let resolved = Set(outfit.items.compactMap { itemsByID[$0.id] })
                entity.update(from: outfit, items: resolved)
            }

            let keep = outfits.map(\.id)
            let stale = OutfitEntity.fetchRequest()
            stale.predicate = NSPredicate(
                format: "NOT (id IN %@) AND isFavorited == NO AND wornOnData == nil", keep
            )
            for entity in try context.fetch(stale) {
                context.delete(entity)
            }

            try context.save()
        }
    }

    func setFavorite(id: UUID, isFavorited: Bool) async throws {
        try await stack.container.performBackgroundTask { context in
            guard let entity = try Self.entity(with: id, in: context) else { return }
            entity.isFavorited = isFavorited
            try context.save()
        }
    }

    func recordWorn(id: UUID, on date: Date) async throws {
        try await stack.container.performBackgroundTask { context in
            guard let entity = try Self.entity(with: id, in: context) else { return }
            entity.appendWornDate(date)
            try context.save()
        }
    }

    /// Fetches every garment referenced by `outfits` in one request, keyed by id.
    private static func resolveItems(
        for outfits: [Outfit],
        in context: NSManagedObjectContext
    ) throws -> [UUID: ClothingItemEntity] {
        let ids = Set(outfits.flatMap { $0.items.map(\.id) })
        guard !ids.isEmpty else { return [:] }
        let request = ClothingItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id IN %@", Array(ids))
        return Dictionary(
            try context.fetch(request).map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    private static func entity(with id: UUID, in context: NSManagedObjectContext) throws -> OutfitEntity? {
        let request = OutfitEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

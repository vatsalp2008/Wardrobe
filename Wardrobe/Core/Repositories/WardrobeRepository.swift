import CoreData
import Foundation

/// Abstracts the wardrobe data source (spec §3.2). The app uses `CoreDataWardrobeRepository`
/// (local-first); `InMemoryWardrobeRepository` (seeded from `SampleData`) backs tests/previews.
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

/// Local-first Core Data implementation. All work runs on a background context; results are
/// mapped to the `Sendable` `ClothingItem` value type before crossing the concurrency boundary.
final class CoreDataWardrobeRepository: WardrobeRepositoryProtocol, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func fetchAll() async throws -> [ClothingItem] {
        try await stack.container.performBackgroundTask { context in
            let request = ClothingItemEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
            return try context.fetch(request).map { $0.toModel() }
        }
    }

    func add(_ item: ClothingItem) async throws {
        try await stack.container.performBackgroundTask { context in
            let entity = ClothingItemEntity(context: context)
            entity.update(from: item)
            try context.save()
        }
    }

    func update(_ item: ClothingItem) async throws {
        try await stack.container.performBackgroundTask { context in
            let entity = try Self.entity(with: item.id, in: context) ?? ClothingItemEntity(context: context)
            entity.update(from: item)
            try context.save()
        }
    }

    func delete(id: UUID) async throws {
        try await stack.container.performBackgroundTask { context in
            guard let entity = try Self.entity(with: id, in: context) else { return }
            context.delete(entity)
            try context.save()
        }
    }

    func markWorn(id: UUID, on date: Date) async throws {
        try await stack.container.performBackgroundTask { context in
            guard let entity = try Self.entity(with: id, in: context) else { return }
            entity.wearCount += 1
            entity.lastWorn = date
            try context.save()
        }
    }

    private static func entity(with id: UUID, in context: NSManagedObjectContext) throws -> ClothingItemEntity? {
        let request = ClothingItemEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

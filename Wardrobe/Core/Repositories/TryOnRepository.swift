import CoreData
import Foundation

/// Caches try-on renders so a previously composited outfit loads instantly (spec §5.3). The app
/// uses `CoreDataTryOnRepository`; `InMemoryTryOnRepository` backs tests and previews.
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

/// Local-first Core Data implementation. One cached render per outfit — saving again for the same
/// outfit overwrites the row, matching the in-memory dictionary's semantics. The render itself
/// stays on disk (`LocalImageStore`); only its URL is stored here.
final class CoreDataTryOnRepository: TryOnRepositoryProtocol, @unchecked Sendable {
    private let stack: CoreDataStack

    init(stack: CoreDataStack = .shared) {
        self.stack = stack
    }

    func cachedResult(for outfitID: UUID) async throws -> TryOnResult? {
        try await stack.container.performBackgroundTask { context in
            try Self.entity(forOutfit: outfitID, in: context)?.toModel()
        }
    }

    func save(_ result: TryOnResult) async throws {
        try await stack.container.performBackgroundTask { context in
            let entity = try Self.entity(forOutfit: result.outfitID, in: context)
                ?? TryOnResultEntity(context: context)
            entity.update(from: result)
            try context.save()
        }
    }

    private static func entity(
        forOutfit outfitID: UUID,
        in context: NSManagedObjectContext
    ) throws -> TryOnResultEntity? {
        let request = TryOnResultEntity.fetchRequest()
        request.predicate = NSPredicate(format: "outfitID == %@", outfitID as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }
}

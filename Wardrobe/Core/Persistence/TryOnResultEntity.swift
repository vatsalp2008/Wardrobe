import CoreData
import Foundation

/// Core Data managed object for a cached try-on render. Code generation is disabled in the model
/// (no `codeGenerationType`), so this hand-written subclass is the single definition.
///
/// Only the URL is stored — the rendered PNG itself lives on disk via `LocalImageStore` (or
/// remotely in the private `tryon-results` bucket), so the store stays small.
@objc(TryOnResultEntity)
final class TryOnResultEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var outfitID: UUID
    @NSManaged var renderedImageURL: String
    @NSManaged var createdAt: Date

    @nonobjc class func fetchRequest() -> NSFetchRequest<TryOnResultEntity> {
        NSFetchRequest<TryOnResultEntity>(entityName: "TryOnResultEntity")
    }
}

extension TryOnResultEntity {
    func toModel() -> TryOnResult {
        TryOnResult(
            id: id,
            outfitID: outfitID,
            renderedImageURL: renderedImageURL,
            createdAt: createdAt
        )
    }

    func update(from result: TryOnResult) {
        id = result.id
        outfitID = result.outfitID
        renderedImageURL = result.renderedImageURL
        createdAt = result.createdAt
    }
}

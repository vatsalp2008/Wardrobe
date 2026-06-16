import CoreData
import Foundation

/// Core Data managed object for a wardrobe item. Code generation is disabled in the model
/// (no `codeGenerationType`), so this hand-written subclass is the single definition.
/// Multi-value fields (colors, seasons, embedding) are stored as encoded scalars and mapped
/// to/from the pure `ClothingItem` value type in `toModel()` / `update(from:)`.
@objc(ClothingItemEntity)
final class ClothingItemEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var categoryRaw: String
    @NSManaged var colorsRaw: String          // comma-separated hex strings
    @NSManaged var patternRaw: String
    @NSManaged var formalityRaw: String
    @NSManaged var seasonsRaw: String          // comma-separated Season rawValues
    @NSManaged var imageURL: String
    @NSManaged var thumbnailData: Data?
    @NSManaged var embeddingData: Data?        // JSON-encoded [Float]
    @NSManaged var wearCount: Int32
    @NSManaged var lastWorn: Date?
    @NSManaged var dateAdded: Date
    @NSManaged var brand: String?
    @NSManaged var notes: String?

    @nonobjc class func fetchRequest() -> NSFetchRequest<ClothingItemEntity> {
        NSFetchRequest<ClothingItemEntity>(entityName: "ClothingItemEntity")
    }
}

extension ClothingItemEntity {
    /// Maps the managed object to the pure value type, defaulting any unparseable enum raw value.
    func toModel() -> ClothingItem {
        ClothingItem(
            id: id,
            name: name,
            category: ClothingCategory(rawValue: categoryRaw) ?? .top,
            color: Self.split(colorsRaw),
            pattern: ClothingPattern(rawValue: patternRaw) ?? .solid,
            formality: FormalityLevel(rawValue: formalityRaw) ?? .casual,
            season: Self.split(seasonsRaw).compactMap(Season.init(rawValue:)),
            imageURL: imageURL,
            thumbnailData: thumbnailData,
            embedding: Self.decodeEmbedding(embeddingData),
            wearCount: Int(wearCount),
            lastWorn: lastWorn,
            dateAdded: dateAdded,
            brand: brand,
            notes: notes
        )
    }

    /// Writes a value-type item onto this managed object.
    func update(from item: ClothingItem) {
        id = item.id
        name = item.name
        categoryRaw = item.category.rawValue
        colorsRaw = item.color.joined(separator: ",")
        patternRaw = item.pattern.rawValue
        formalityRaw = item.formality.rawValue
        seasonsRaw = item.season.map(\.rawValue).joined(separator: ",")
        imageURL = item.imageURL
        thumbnailData = item.thumbnailData
        embeddingData = Self.encodeEmbedding(item.embedding)
        wearCount = Int32(item.wearCount)
        lastWorn = item.lastWorn
        dateAdded = item.dateAdded
        brand = item.brand
        notes = item.notes
    }

    private static func split(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private static func encodeEmbedding(_ embedding: [Float]) -> Data? {
        embedding.isEmpty ? nil : try? JSONEncoder().encode(embedding)
    }

    private static func decodeEmbedding(_ data: Data?) -> [Float] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Float].self, from: data)) ?? []
    }
}

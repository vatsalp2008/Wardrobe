import CoreData
import Foundation

/// Core Data managed object for a generated outfit. Code generation is disabled in the model
/// (no `codeGenerationType`), so this hand-written subclass is the single definition.
///
/// Garments are held as a to-many relationship rather than an embedded snapshot — each
/// `ClothingItem` carries a thumbnail JPEG, so snapshotting would duplicate megabytes on every
/// refresh. `itemIDsRaw` carries the display order alongside the (unordered) relationship.
@objc(OutfitEntity)
final class OutfitEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var occasionRaw: String
    @NSManaged var trendScore: Double
    @NSManaged var weatherMinC: Double
    @NSManaged var weatherMaxC: Double
    @NSManaged var generatedBy: String
    @NSManaged var generatedAt: Date
    @NSManaged var wornOnData: Data?           // JSON-encoded [Date]
    @NSManaged var isFavorited: Bool
    @NSManaged var tryOnImageURL: String?
    @NSManaged var reasoning: String?
    @NSManaged var itemIDsRaw: String          // comma-separated UUID strings, in display order
    @NSManaged var items: Set<ClothingItemEntity>

    @nonobjc class func fetchRequest() -> NSFetchRequest<OutfitEntity> {
        NSFetchRequest<OutfitEntity>(entityName: "OutfitEntity")
    }
}

extension OutfitEntity {
    /// Maps the managed object to the pure value type, restoring garment order from `itemIDsRaw`.
    /// Items deleted from the closet are simply absent — the relationship's nullify rule drops
    /// them, and the ID lookup skips them.
    func toModel() -> Outfit {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = Self.split(itemIDsRaw)
            .compactMap(UUID.init(uuidString:))
            .compactMap { byID[$0]?.toModel() }
        return Outfit(
            id: id,
            items: ordered,
            occasion: Occasion(rawValue: occasionRaw) ?? .casual,
            trendScore: trendScore,
            weatherSuitability: WeatherRange(minC: weatherMinC, maxC: weatherMaxC),
            generatedBy: generatedBy,
            generatedAt: generatedAt,
            wornOn: Self.decodeDates(wornOnData),
            isFavorited: isFavorited,
            tryOnImageURL: tryOnImageURL,
            reasoning: reasoning
        )
    }

    /// Writes a value-type outfit onto this managed object. Garment entities are resolved by the
    /// repository and passed in — an entity must never fetch on its own context.
    ///
    /// `itemIDsRaw` is written from `outfit.items` rather than from `resolved`, so ordering
    /// survives a garment that is momentarily missing from the store.
    func update(from outfit: Outfit, items resolved: Set<ClothingItemEntity>) {
        id = outfit.id
        occasionRaw = outfit.occasion.rawValue
        trendScore = outfit.trendScore
        weatherMinC = outfit.weatherSuitability.minC
        weatherMaxC = outfit.weatherSuitability.maxC
        generatedBy = outfit.generatedBy
        generatedAt = outfit.generatedAt
        wornOnData = Self.encodeDates(outfit.wornOn)
        isFavorited = outfit.isFavorited
        tryOnImageURL = outfit.tryOnImageURL
        reasoning = outfit.reasoning
        itemIDsRaw = outfit.items.map(\.id.uuidString).joined(separator: ",")
        items = resolved
    }

    /// Appends a wear date in place, used by `recordWorn`.
    func appendWornDate(_ date: Date) {
        var dates = Self.decodeDates(wornOnData)
        dates.append(date)
        wornOnData = Self.encodeDates(dates)
    }

    private static func split(_ raw: String) -> [String] {
        raw.split(separator: ",").map(String.init).filter { !$0.isEmpty }
    }

    private static func encodeDates(_ dates: [Date]) -> Data? {
        dates.isEmpty ? nil : try? JSONEncoder().encode(dates)
    }

    private static func decodeDates(_ data: Data?) -> [Date] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([Date].self, from: data)) ?? []
    }
}

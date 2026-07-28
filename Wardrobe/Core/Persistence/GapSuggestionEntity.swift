import CoreData
import Foundation

/// Core Data managed object for a cached gap-analysis suggestion. Code generation is disabled in
/// the model (no `codeGenerationType`), so this hand-written subclass is the single definition.
///
/// `rank` is entity-only and has no counterpart on `GapSuggestion`: Core Data fetches are
/// unordered, and the Gap Finder presents `suggestions.first` as *the* gap, so the stylist's
/// ranking has to be stored explicitly or the top suggestion becomes arbitrary after a relaunch.
@objc(GapSuggestionEntity)
final class GapSuggestionEntity: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var missingCategoryRaw: String
    /// Named to avoid colliding with `NSObject.description`.
    @NSManaged var suggestionDescription: String
    @NSManaged var newOutfitsUnlocked: Int32
    @NSManaged var trendAlignment: Double
    @NSManaged var reasoning: String?
    @NSManaged var shoppingResultsData: Data?   // JSON-encoded [ShoppingItem]
    @NSManaged var generatedAt: Date
    @NSManaged var rank: Int16

    @nonobjc class func fetchRequest() -> NSFetchRequest<GapSuggestionEntity> {
        NSFetchRequest<GapSuggestionEntity>(entityName: "GapSuggestionEntity")
    }
}

extension GapSuggestionEntity {
    func toModel() -> GapSuggestion {
        GapSuggestion(
            id: id,
            missingCategory: ClothingCategory(rawValue: missingCategoryRaw) ?? .top,
            description: suggestionDescription,
            newOutfitsUnlocked: Int(newOutfitsUnlocked),
            trendAlignment: trendAlignment,
            reasoning: reasoning,
            shoppingResults: Self.decodeShopping(shoppingResultsData),
            generatedAt: generatedAt
        )
    }

    /// Writes a value-type suggestion onto this managed object. `rank` is the caller's index in
    /// the ranked array.
    func update(from suggestion: GapSuggestion, rank order: Int) {
        id = suggestion.id
        missingCategoryRaw = suggestion.missingCategory.rawValue
        suggestionDescription = suggestion.description
        newOutfitsUnlocked = Int32(suggestion.newOutfitsUnlocked)
        trendAlignment = suggestion.trendAlignment
        reasoning = suggestion.reasoning
        shoppingResultsData = Self.encodeShopping(suggestion.shoppingResults)
        generatedAt = suggestion.generatedAt
        rank = Int16(order)
    }

    private static func encodeShopping(_ items: [ShoppingItem]) -> Data? {
        items.isEmpty ? nil : try? JSONEncoder().encode(items)
    }

    private static func decodeShopping(_ data: Data?) -> [ShoppingItem] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([ShoppingItem].self, from: data)) ?? []
    }
}

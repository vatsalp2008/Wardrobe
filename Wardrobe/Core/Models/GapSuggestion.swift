import Foundation

/// A live shopping result for a gap item, parsed from SerpAPI (spec §5.4).
struct ShoppingItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var title: String
    var price: String          // Display string incl. currency, e.g. "$39.99"
    var retailer: String
    var imageURL: String
    var buyLink: String

    init(
        id: UUID = UUID(),
        title: String,
        price: String,
        retailer: String,
        imageURL: String,
        buyLink: String
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.retailer = retailer
        self.imageURL = imageURL
        self.buyLink = buyLink
    }
}

/// The single missing item that unlocks the most new outfit combinations (spec §4.3).
struct GapSuggestion: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var missingCategory: ClothingCategory
    var description: String          // e.g. "A white linen shirt"
    var newOutfitsUnlocked: Int
    var trendAlignment: Double       // 0.0–1.0
    var reasoning: String?           // Stylist explanation from Claude
    var shoppingResults: [ShoppingItem]
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        missingCategory: ClothingCategory,
        description: String,
        newOutfitsUnlocked: Int,
        trendAlignment: Double,
        reasoning: String? = nil,
        shoppingResults: [ShoppingItem] = [],
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.missingCategory = missingCategory
        self.description = description
        self.newOutfitsUnlocked = newOutfitsUnlocked
        self.trendAlignment = trendAlignment
        self.reasoning = reasoning
        self.shoppingResults = shoppingResults
        self.generatedAt = generatedAt
    }
}

/// A candidate missing item produced by the combination-matrix analysis (spec §5.4).
/// `newOutfitsUnlocked` is the number of *additional* valid outfits adding this item enables.
struct GapCandidate: Codable, Equatable {
    var category: ClothingCategory
    var description: String
    var formality: FormalityLevel
    var colors: [String]
    var newOutfitsUnlocked: Int
}

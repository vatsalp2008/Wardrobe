import Foundation

/// Canned data used by mock services and SwiftUI previews so the app is fully
/// explorable without any network access or API keys (mock-first, spec §2.2 / plan).
enum SampleData {

    static let items: [ClothingItem] = [
        ClothingItem(name: "White Oxford Shirt", category: .top, color: ["#FFFFFF"],
                     pattern: .solid, formality: .smartCasual, season: [.spring, .fall],
                     wearCount: 4, lastWorn: Date().addingTimeInterval(-86_400 * 9)),
        ClothingItem(name: "Navy Chinos", category: .bottom, color: ["#1F2D5A"],
                     pattern: .solid, formality: .smartCasual, season: [.spring, .summer, .fall],
                     wearCount: 7, lastWorn: Date().addingTimeInterval(-86_400 * 2)),
        ClothingItem(name: "Grey Crewneck Tee", category: .top, color: ["#9A9A9A"],
                     pattern: .solid, formality: .casual, season: [.spring, .summer],
                     wearCount: 12, lastWorn: Date().addingTimeInterval(-86_400)),
        ClothingItem(name: "Charcoal Blazer", category: .outerwear, color: ["#36454F"],
                     pattern: .solid, formality: .business, season: [.fall, .winter],
                     wearCount: 2, lastWorn: Date().addingTimeInterval(-86_400 * 20)),
        ClothingItem(name: "White Leather Sneakers", category: .shoes, color: ["#FFFFFF"],
                     pattern: .solid, formality: .casual, season: [.spring, .summer, .fall],
                     wearCount: 15, lastWorn: Date().addingTimeInterval(-86_400 * 3)),
        ClothingItem(name: "Dark Wash Jeans", category: .bottom, color: ["#2A3F5F"],
                     pattern: .solid, formality: .casual, season: [.fall, .winter, .spring],
                     wearCount: 9, lastWorn: Date().addingTimeInterval(-86_400 * 5))
    ]

    static var sampleOutfit: Outfit {
        Outfit(
            items: Array(items.prefix(3)),
            occasion: .work,
            trendScore: 0.82,
            weatherSuitability: WeatherRange(minC: 10, maxC: 22),
            generatedBy: "rule-engine",
            reasoning: "Smart-casual layering suited to mild weather; neutral palette avoids pattern clash."
        )
    }

    static var sampleGap: GapSuggestion {
        GapSuggestion(
            missingCategory: .top,
            description: "A white linen shirt",
            newOutfitsUnlocked: 14,
            trendAlignment: 0.76,
            shoppingResults: sampleShopping
        )
    }

    static let sampleShopping: [ShoppingItem] = [
        ShoppingItem(title: "Linen Blend Shirt", price: "$39.90", retailer: "Uniqlo",
                     imageURL: "", buyLink: "https://example.com/1"),
        ShoppingItem(title: "Relaxed Linen Shirt", price: "$59.00", retailer: "J.Crew",
                     imageURL: "", buyLink: "https://example.com/2")
    ]
}

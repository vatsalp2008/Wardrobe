import Foundation

/// Wraps the Claude API (spec §6.1) for the app's three AI tasks: outfit generation,
/// trend scoring, and gap analysis. The live adapter (`POST /v1/messages`,
/// model `claude-sonnet-4-6`) is implemented in Phase 2/4; Phase 0 ships `MockClaudeService`.
protocol ClaudeServiceProtocol: Sendable {
    /// Returns up to 5 outfits assembled from `wardrobe`, respecting weather, occasion,
    /// and recent-wear rules.
    func generateOutfits(
        wardrobe: [ClothingItem],
        weather: WeatherInfo,
        occasion: Occasion
    ) async throws -> [Outfit]

    /// Scores an outfit 0.0–1.0 against the supplied trending fashion keywords.
    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double

    /// Returns the top gap suggestions for the wardrobe (shopping results filled in by SerpService).
    func analyzeGap(wardrobe: [ClothingItem]) async throws -> [GapSuggestion]
}

/// Deterministic, offline stand-in. Doubles as the permanent fallback when no API key
/// is configured (plan: "Missing Claude key → deterministic rule-based generator").
struct MockClaudeService: ClaudeServiceProtocol {
    func generateOutfits(
        wardrobe: [ClothingItem],
        weather: WeatherInfo,
        occasion: Occasion
    ) async throws -> [Outfit] {
        let tops = wardrobe.filter { $0.category == .top }
        let bottoms = wardrobe.filter { $0.category == .bottom }
        let shoes = wardrobe.filter { $0.category == .shoes }

        var outfits: [Outfit] = []
        for (index, top) in tops.enumerated() {
            guard let bottom = bottoms[safe: index % max(bottoms.count, 1)] else { continue }
            var items = [top, bottom]
            if let shoe = shoes.first { items.append(shoe) }
            outfits.append(
                Outfit(
                    items: items,
                    occasion: occasion,
                    trendScore: 0.6 + Double(index % 3) * 0.1,
                    weatherSuitability: WeatherRange(minC: weather.temperatureC - 6,
                                                     maxC: weather.temperatureC + 6),
                    generatedBy: "mock-rule-engine",
                    reasoning: "Paired \(top.name) with \(bottom.name) for a \(occasion.displayName.lowercased()) look."
                )
            )
            if outfits.count == 5 { break }
        }
        return outfits
    }

    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double {
        // Stable pseudo-score derived from item count so previews look plausible.
        min(1.0, 0.5 + Double(outfit.items.count) * 0.1)
    }

    func analyzeGap(wardrobe: [ClothingItem]) async throws -> [GapSuggestion] {
        [SampleData.sampleGap]
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

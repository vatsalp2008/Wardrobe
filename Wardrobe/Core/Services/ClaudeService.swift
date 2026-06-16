import Foundation

/// Wraps the Claude API (spec §6.1) for the app's three AI tasks: outfit generation,
/// trend scoring, and gap analysis. The live adapter (`POST /v1/messages`,
/// model `claude-sonnet-4-6`) is implemented in Phase 2/4; Phase 0 ships `MockClaudeService`.
protocol ClaudeServiceProtocol: Sendable {
    /// Returns up to 5 outfits assembled from `wardrobe`, respecting weather, occasion,
    /// trend keywords, and recent-wear rules.
    func generateOutfits(
        wardrobe: [ClothingItem],
        weather: WeatherInfo,
        occasion: Occasion,
        trendKeywords: [String]
    ) async throws -> [Outfit]

    /// Scores an outfit 0.0–1.0 against the supplied trending fashion keywords.
    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double

    /// Picks the top gap suggestions from the matrix-computed candidates, adding reasoning and
    /// trend alignment (shopping results are filled in afterward by SerpService).
    func analyzeGap(wardrobe: [ClothingItem], candidates: [GapCandidate]) async throws -> [GapSuggestion]

    /// Classifies a segmented garment image into category/pattern/formality/seasons (F1).
    /// The live client uses Claude vision; the mock returns low confidence so the review screen
    /// prompts for manual tags (colors are always filled on-device by the caller).
    func tagGarment(imageData: Data) async throws -> ClothingTags
}

/// Deterministic, offline stand-in. Doubles as the permanent fallback when no API key
/// is configured (plan: "Missing Claude key → deterministic rule-based generator").
struct MockClaudeService: ClaudeServiceProtocol {
    func generateOutfits(
        wardrobe: [ClothingItem],
        weather: WeatherInfo,
        occasion: Occasion,
        trendKeywords: [String]
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

    func analyzeGap(wardrobe: [ClothingItem], candidates: [GapCandidate]) async throws -> [GapSuggestion] {
        candidates.prefix(3).map { candidate in
            GapSuggestion(
                missingCategory: candidate.category,
                description: candidate.description,
                newOutfitsUnlocked: candidate.newOutfitsUnlocked,
                trendAlignment: 0.7,
                reasoning: "Adding \(candidate.description.lowercased()) bridges gaps in your "
                    + "\(candidate.category.displayName.lowercased()) options."
            )
        }
    }

    func tagGarment(imageData: Data) async throws -> ClothingTags {
        // No vision without a key — return low confidence so the user confirms tags manually.
        ClothingTags(category: .top, colors: [], pattern: .solid,
                     formality: .casual, seasons: [], confidence: 0.0)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

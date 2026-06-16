import Foundation

/// Provider-agnostic prompts, request/response DTOs, and JSON helpers shared by the AI stylist
/// clients. Both `LiveClaudeService` (Anthropic) and `GeminiStylistService` (Google) conform to
/// `ClaudeServiceProtocol` and reuse everything here, so the wire client is the only difference.
enum StylistPrompts {
    static let outfit = """
    You are an expert personal stylist. Given a JSON object with the user's wardrobe items, \
    today's weather, the target occasion, and current trend keywords, assemble up to 5 complete \
    outfits using ONLY the provided item IDs.

    Rules:
    - No clashing patterns within an outfit.
    - Weather-appropriate: respect the temperature.
    - Match the requested occasion's formality.
    - Each outfit should include at least a top and bottom (or a dress), plus shoes when available.
    - Prefer items that align with the trend keywords; score accordingly.

    Respond with ONLY a JSON array (no prose). Each element:
    {"itemIds": ["<uuid>", ...], "trendScore": 0.0-1.0, "minTempC": <number>, "maxTempC": <number>, "reasoning": "<one sentence>"}
    """

    static let gap = """
    You are a personal stylist analyzing a wardrobe's "gaps". You receive a JSON object with the \
    wardrobe size and a list of candidate items, each with how many NEW valid outfit combinations \
    it would unlock. Pick the top 3 by overall value (outfits unlocked + versatility + current \
    trend relevance).

    Respond with ONLY a JSON array (no prose). Each element references a candidate by its index:
    {"index": <int>, "trendAlignment": 0.0-1.0, "reasoning": "<one short sentence>"}
    """

    static let tag = """
    You are a fashion cataloging assistant. Look at the garment image and classify it.
    Respond with ONLY a JSON object (no prose):
    {"category": one of [top, bottom, outerwear, shoes, accessory, dress],
     "pattern": one of [solid, striped, plaid, floral, graphic],
     "formality": one of [casual, smart_casual, business, formal],
     "seasons": array from [spring, summer, fall, winter]}
    """
}

enum StylistJSON {
    static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Extracts and decodes the first top-level JSON array from `text` (models may add prose).
    static func decodeArray<T: Decodable>(from text: String) throws -> [T] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else {
            throw StylistAIError.parse
        }
        return try JSONDecoder().decode([T].self, from: data)
    }

    /// Extracts and decodes the first top-level JSON object from `text`.
    static func decodeObject<T: Decodable>(from text: String) throws -> T {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else {
            throw StylistAIError.parse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Request / response DTOs

struct OutfitRequestPayload: Encodable {
    let wardrobe: [WardrobeItemDTO]
    let weatherC: Double
    let condition: String
    let occasion: String
    let trendKeywords: [String]
}

struct WardrobeItemDTO: Encodable {
    let id: String
    let name: String
    let category: String
    let colors: [String]
    let pattern: String
    let formality: String
    let seasons: [String]

    init(_ item: ClothingItem) {
        id = item.id.uuidString
        name = item.name
        category = item.category.rawValue
        colors = item.color
        pattern = item.pattern.rawValue
        formality = item.formality.rawValue
        seasons = item.season.map(\.rawValue)
    }
}

struct OutfitDTO: Decodable {
    let itemIds: [String]
    let trendScore: Double?
    let minTempC: Double?
    let maxTempC: Double?
    let reasoning: String?

    func toOutfit(wardrobe: [ClothingItem], occasion: Occasion, generatedBy: String) -> Outfit? {
        let byID = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id.uuidString, $0) })
        let items = itemIds.compactMap { byID[$0] }
        guard !items.isEmpty else { return nil }
        return Outfit(
            items: items,
            occasion: occasion,
            trendScore: trendScore ?? 0.5,
            weatherSuitability: WeatherRange(minC: minTempC ?? -10, maxC: maxTempC ?? 40),
            generatedBy: generatedBy,
            reasoning: reasoning
        )
    }
}

struct GapRequestPayload: Encodable {
    let wardrobeSize: Int
    let candidates: [GapCandidateDTO]
}

struct GapCandidateDTO: Encodable {
    let index: Int
    let description: String
    let category: String
    let newOutfitsUnlocked: Int
}

struct GapRankingDTO: Decodable {
    let index: Int
    let trendAlignment: Double?
    let reasoning: String?
}

struct GarmentTagDTO: Decodable {
    let category: String?
    let pattern: String?
    let formality: String?
    let seasons: [String]?

    func toTags() -> ClothingTags {
        ClothingTags(
            category: category.flatMap(ClothingCategory.init(rawValue:)) ?? .top,
            colors: [],   // filled on-device by the caller (DominantColor)
            pattern: pattern.flatMap(ClothingPattern.init(rawValue:)) ?? .solid,
            formality: formality.flatMap(FormalityLevel.init(rawValue:)) ?? .casual,
            seasons: (seasons ?? []).compactMap(Season.init(rawValue:)),
            confidence: 0.9
        )
    }

    /// Maps gap candidates + a ranking back into a `GapSuggestion`.
    static func suggestion(from ranking: GapRankingDTO, candidates: [GapCandidate]) -> GapSuggestion? {
        guard candidates.indices.contains(ranking.index) else { return nil }
        let candidate = candidates[ranking.index]
        return GapSuggestion(
            missingCategory: candidate.category,
            description: candidate.description,
            newOutfitsUnlocked: candidate.newOutfitsUnlocked,
            trendAlignment: ranking.trendAlignment ?? 0.6,
            reasoning: ranking.reasoning
        )
    }
}

enum StylistAIError: Error {
    case network
    case api(status: Int, body: String)
    case refused
    case emptyResponse
    case parse
}

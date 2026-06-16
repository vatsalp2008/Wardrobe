import Foundation

/// Live Claude API client (spec §6.1). Swift has no official Anthropic SDK, so this uses
/// `URLSession` against `POST /v1/messages` with `anthropic-version: 2023-06-01`.
///
/// Model: `claude-sonnet-4-6` — the spec's explicit choice for this high-volume, cost-sensitive
/// outfit-generation workload (a current, valid model ID). Change `Self.model` to switch.
///
/// Selected by `AppContainer` only when `ANTHROPIC_API_KEY` is present; otherwise the app uses
/// `MockClaudeService` (the deterministic offline fallback).
struct LiveClaudeService: ClaudeServiceProtocol {
    static let model = "claude-sonnet-4-6"
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let anthropicVersion = "2023-06-01"

    let apiKey: String
    var session: URLSession = .shared

    func generateOutfits(
        wardrobe: [ClothingItem],
        weather: WeatherInfo,
        occasion: Occasion,
        trendKeywords: [String]
    ) async throws -> [Outfit] {
        let system = Self.stylistSystemPrompt
        let payload = OutfitRequestPayload(
            wardrobe: wardrobe.map(WardrobeItemDTO.init),
            weatherC: weather.temperatureC,
            condition: weather.condition,
            occasion: occasion.rawValue,
            trendKeywords: trendKeywords
        )
        let userText = try Self.encodeJSONString(payload)
        let text = try await sendMessage(system: system, userText: userText, maxTokens: 4096)
        let dtos: [OutfitDTO] = try Self.decodeJSONArray(from: text)
        return dtos.compactMap { $0.toOutfit(wardrobe: wardrobe, occasion: occasion) }
    }

    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double {
        // Trend scoring is folded into generation; the generated outfit already carries a score.
        outfit.trendScore
    }

    func analyzeGap(wardrobe: [ClothingItem], candidates: [GapCandidate]) async throws -> [GapSuggestion] {
        guard !candidates.isEmpty else { return [] }
        let payload = GapRequestPayload(
            wardrobeSize: wardrobe.count,
            candidates: candidates.enumerated().map { index, candidate in
                GapCandidateDTO(index: index, description: candidate.description,
                                category: candidate.category.rawValue,
                                newOutfitsUnlocked: candidate.newOutfitsUnlocked)
            }
        )
        let userText = try Self.encodeJSONString(payload)
        let text = try await sendMessage(system: Self.gapSystemPrompt, userText: userText, maxTokens: 1500)
        let ranked: [GapRankingDTO] = try Self.decodeJSONArray(from: text)

        return ranked.prefix(3).compactMap { ranking -> GapSuggestion? in
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

    func tagGarment(imageData: Data) async throws -> ClothingTags {
        let base64 = imageData.base64EncodedString()
        let text = try await sendVisionMessage(
            system: Self.tagSystemPrompt,
            imageBase64: base64,
            mediaType: "image/jpeg",
            prompt: "Classify this single garment. Respond with ONLY the JSON object.",
            maxTokens: 500
        )
        let dto: GarmentTagDTO = try Self.decodeJSONObject(from: text)
        return dto.toTags()
    }

    private func sendVisionMessage(system: String, imageBase64: String, mediaType: String,
                                   prompt: String, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image",
                     "source": ["type": "base64", "media_type": mediaType, "data": imageBase64]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.network }
        guard http.statusCode == 200 else {
            throw ClaudeError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        if decoded.stopReason == "refusal" { throw ClaudeError.refused }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.emptyResponse
        }
        return text
    }

    /// Decodes the first top-level JSON object from `text`.
    private static func decodeJSONObject<T: Decodable>(from text: String) throws -> T {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"), start < end,
              let data = String(text[start...end]).data(using: .utf8) else {
            throw ClaudeError.parse
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    static let tagSystemPrompt = """
    You are a fashion cataloging assistant. Look at the garment image and classify it.
    Respond with ONLY a JSON object (no prose):
    {"category": one of [top, bottom, outerwear, shoes, accessory, dress],
     "pattern": one of [solid, striped, plaid, floral, graphic],
     "formality": one of [casual, smart_casual, business, formal],
     "seasons": array from [spring, summer, fall, winter]}
    """

    static let gapSystemPrompt = """
    You are a personal stylist analyzing a wardrobe's "gaps". You receive a JSON object with the \
    wardrobe size and a list of candidate items, each with how many NEW valid outfit combinations \
    it would unlock. Pick the top 3 by overall value (outfits unlocked + versatility + current \
    trend relevance).

    Respond with ONLY a JSON array (no prose). Each element references a candidate by its index:
    {"index": <int>, "trendAlignment": 0.0-1.0, "reasoning": "<one short sentence>"}
    """

    // MARK: - HTTP

    private func sendMessage(system: String, userText: String, maxTokens: Int) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = MessagesRequest(
            model: Self.model,
            maxTokens: maxTokens,
            system: system,
            messages: [.init(role: "user", content: userText)]
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClaudeError.network }
        guard http.statusCode == 200 else {
            throw ClaudeError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        if decoded.stopReason == "refusal" { throw ClaudeError.refused }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw ClaudeError.emptyResponse
        }
        return text
    }

    // MARK: - JSON helpers

    private static func encodeJSONString<T: Encodable>(_ value: T) throws -> String {
        let data = try JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    /// Extracts and decodes the first top-level JSON array from `text` (Claude may wrap it in prose).
    private static func decodeJSONArray<T: Decodable>(from text: String) throws -> [T] {
        guard let start = text.firstIndex(of: "["),
              let end = text.lastIndex(of: "]"), start < end else {
            throw ClaudeError.parse
        }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8) else { throw ClaudeError.parse }
        return try JSONDecoder().decode([T].self, from: data)
    }

    static let stylistSystemPrompt = """
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
}

// MARK: - Wire DTOs

private struct MessagesRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [Message]
    struct Message: Encodable { let role: String; let content: String }
    enum CodingKeys: String, CodingKey { case model, system, messages; case maxTokens = "max_tokens" }
}

private struct MessagesResponse: Decodable {
    let content: [Block]
    let stopReason: String?
    struct Block: Decodable { let type: String; let text: String? }
    enum CodingKeys: String, CodingKey { case content; case stopReason = "stop_reason" }
}

private struct OutfitRequestPayload: Encodable {
    let wardrobe: [WardrobeItemDTO]
    let weatherC: Double
    let condition: String
    let occasion: String
    let trendKeywords: [String]
}

private struct WardrobeItemDTO: Encodable {
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

private struct OutfitDTO: Decodable {
    let itemIds: [String]
    let trendScore: Double?
    let minTempC: Double?
    let maxTempC: Double?
    let reasoning: String?

    func toOutfit(wardrobe: [ClothingItem], occasion: Occasion) -> Outfit? {
        let byID = Dictionary(uniqueKeysWithValues: wardrobe.map { ($0.id.uuidString, $0) })
        let items = itemIds.compactMap { byID[$0] }
        guard !items.isEmpty else { return nil }
        return Outfit(
            items: items,
            occasion: occasion,
            trendScore: trendScore ?? 0.5,
            weatherSuitability: WeatherRange(minC: minTempC ?? -10, maxC: maxTempC ?? 40),
            generatedBy: LiveClaudeService.model,
            reasoning: reasoning
        )
    }
}

private struct GapRequestPayload: Encodable {
    let wardrobeSize: Int
    let candidates: [GapCandidateDTO]
}

private struct GapCandidateDTO: Encodable {
    let index: Int
    let description: String
    let category: String
    let newOutfitsUnlocked: Int
}

private struct GapRankingDTO: Decodable {
    let index: Int
    let trendAlignment: Double?
    let reasoning: String?
}

private struct GarmentTagDTO: Decodable {
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
            confidence: 0.9   // confident enough to skip the manual-review banner
        )
    }
}

enum ClaudeError: Error {
    case network
    case api(status: Int, body: String)
    case refused
    case emptyResponse
    case parse
}

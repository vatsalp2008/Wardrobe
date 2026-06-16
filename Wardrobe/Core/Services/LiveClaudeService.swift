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

    func analyzeGap(wardrobe: [ClothingItem]) async throws -> [GapSuggestion] {
        // Implemented in Phase 4 (Gap Finder). Fall back to the deterministic mock until then.
        try await MockClaudeService().analyzeGap(wardrobe: wardrobe)
    }

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

enum ClaudeError: Error {
    case network
    case api(status: Int, body: String)
    case refused
    case emptyResponse
    case parse
}

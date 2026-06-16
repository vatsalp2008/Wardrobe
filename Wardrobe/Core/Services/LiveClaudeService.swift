import Foundation

/// Live Claude API client (spec §6.1). Swift has no official Anthropic SDK, so this uses
/// `URLSession` against `POST /v1/messages` with `anthropic-version: 2023-06-01`.
///
/// Model: `claude-sonnet-4-6` (a current model ID; the spec's choice for this cost-sensitive
/// workload). Selected by `AppContainer` when `ANTHROPIC_API_KEY` is set. Shared prompts/DTOs
/// live in `StylistAISupport`.
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
        let payload = OutfitRequestPayload(
            wardrobe: wardrobe.map(WardrobeItemDTO.init),
            weatherC: weather.temperatureC,
            condition: weather.condition,
            occasion: occasion.rawValue,
            trendKeywords: trendKeywords
        )
        let text = try await sendMessage(system: StylistPrompts.outfit,
                                         userText: StylistJSON.encode(payload), maxTokens: 4096)
        let dtos: [OutfitDTO] = try StylistJSON.decodeArray(from: text)
        return dtos.compactMap { $0.toOutfit(wardrobe: wardrobe, occasion: occasion, generatedBy: Self.model) }
    }

    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double {
        outfit.trendScore   // trend scoring is folded into generation
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
        let text = try await sendMessage(system: StylistPrompts.gap,
                                         userText: StylistJSON.encode(payload), maxTokens: 1500)
        let ranked: [GapRankingDTO] = try StylistJSON.decodeArray(from: text)
        return ranked.prefix(3).compactMap { GarmentTagDTO.suggestion(from: $0, candidates: candidates) }
    }

    func tagGarment(imageData: Data) async throws -> ClothingTags {
        let text = try await sendVisionMessage(
            system: StylistPrompts.tag, imageBase64: imageData.base64EncodedString(),
            mediaType: "image/jpeg",
            prompt: "Classify this single garment. Respond with ONLY the JSON object.", maxTokens: 500
        )
        let dto: GarmentTagDTO = try StylistJSON.decodeObject(from: text)
        return dto.toTags()
    }

    // MARK: - HTTP

    private func sendMessage(system: String, userText: String, maxTokens: Int) async throws -> String {
        let body = MessagesRequest(
            model: Self.model, maxTokens: maxTokens, system: system,
            messages: [.init(role: "user", content: userText)]
        )
        return try await perform(jsonBody: try JSONEncoder().encode(body))
    }

    private func sendVisionMessage(system: String, imageBase64: String, mediaType: String,
                                   prompt: String, maxTokens: Int) async throws -> String {
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
        return try await perform(jsonBody: try JSONSerialization.data(withJSONObject: body))
    }

    private func perform(jsonBody: Data) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.anthropicVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = jsonBody

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StylistAIError.network }
        guard http.statusCode == 200 else {
            throw StylistAIError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(MessagesResponse.self, from: data)
        if decoded.stopReason == "refusal" { throw StylistAIError.refused }
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw StylistAIError.emptyResponse
        }
        return text
    }
}

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

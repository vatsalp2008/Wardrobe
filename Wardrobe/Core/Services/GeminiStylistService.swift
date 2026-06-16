import Foundation

/// Google Gemini stylist client — an alternative AI provider conforming to the same
/// `ClaudeServiceProtocol` (outfit generation, gap ranking, garment tagging). Uses the
/// `generateContent` REST endpoint with JSON response mode. Selected by `AppContainer` when
/// `GEMINI_API_KEY` is set (takes precedence over Anthropic if both are present).
///
/// Model: `gemini-2.0-flash` — fast + low-cost + vision-capable. Change `Self.model` if you want
/// a different tier (e.g. `gemini-2.5-flash`).
struct GeminiStylistService: ClaudeServiceProtocol {
    static let model = "gemini-2.0-flash"
    static var endpoint: URL {
        URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent")!
    }

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
        let text = try await generateContent(system: StylistPrompts.outfit,
                                             parts: [["text": StylistJSON.encode(payload)]],
                                             maxTokens: 4096)
        let dtos: [OutfitDTO] = try StylistJSON.decodeArray(from: text)
        return dtos.compactMap { $0.toOutfit(wardrobe: wardrobe, occasion: occasion, generatedBy: Self.model) }
    }

    func scoreTrend(outfit: Outfit, trendKeywords: [String]) async throws -> Double {
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
        let text = try await generateContent(system: StylistPrompts.gap,
                                             parts: [["text": StylistJSON.encode(payload)]],
                                             maxTokens: 1500)
        let ranked: [GapRankingDTO] = try StylistJSON.decodeArray(from: text)
        return ranked.prefix(3).compactMap { GarmentTagDTO.suggestion(from: $0, candidates: candidates) }
    }

    func tagGarment(imageData: Data) async throws -> ClothingTags {
        let parts: [[String: Any]] = [
            ["inlineData": ["mimeType": "image/jpeg", "data": imageData.base64EncodedString()]],
            ["text": "Classify this single garment. Respond with ONLY the JSON object."]
        ]
        let text = try await generateContent(system: StylistPrompts.tag, parts: parts, maxTokens: 500)
        let dto: GarmentTagDTO = try StylistJSON.decodeObject(from: text)
        return dto.toTags()
    }

    // MARK: - HTTP

    private func generateContent(system: String, parts: [[String: Any]], maxTokens: Int) async throws -> String {
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": ["maxOutputTokens": maxTokens, "responseMimeType": "application/json"]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw StylistAIError.network }
        guard http.statusCode == 200 else {
            throw StylistAIError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
        let decoded = try JSONDecoder().decode(GeminiResponse.self, from: data)
        guard let text = decoded.candidates?.first?.content?.parts?.first?.text else {
            throw StylistAIError.emptyResponse
        }
        return text
    }
}

private struct GeminiResponse: Decodable {
    let candidates: [Candidate]?
    struct Candidate: Decodable { let content: Content? }
    struct Content: Decodable { let parts: [Part]? }
    struct Part: Decodable { let text: String? }
}

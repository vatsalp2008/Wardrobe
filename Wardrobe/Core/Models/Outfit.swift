import Foundation

/// Intended occasion for an outfit. Drives the feed filter chips and Claude's formality rules.
enum Occasion: String, Codable, CaseIterable, Identifiable {
    case casual, work, date, formal, outdoor
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Inclusive temperature range an outfit is suitable for, in degrees Celsius.
struct WeatherRange: Codable, Equatable, Hashable {
    var minC: Double
    var maxC: Double

    func contains(_ temperatureC: Double) -> Bool {
        temperatureC >= minC && temperatureC <= maxC
    }
}

/// An AI- (or rule-) generated outfit composed of wardrobe items (spec §4.2).
struct Outfit: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var items: [ClothingItem]
    var occasion: Occasion
    var trendScore: Double           // 0.0–1.0, how on-trend this week
    var weatherSuitability: WeatherRange
    var generatedBy: String          // Model/version that produced it (e.g. "claude-sonnet-4-6", "rule-engine")
    var generatedAt: Date
    var wornOn: [Date]
    var isFavorited: Bool
    var tryOnImageURL: String?       // Cached try-on result URL
    var reasoning: String?           // Stylist explanation from the generator

    init(
        id: UUID = UUID(),
        items: [ClothingItem],
        occasion: Occasion,
        trendScore: Double = 0,
        weatherSuitability: WeatherRange = WeatherRange(minC: -10, maxC: 40),
        generatedBy: String,
        generatedAt: Date = Date(),
        wornOn: [Date] = [],
        isFavorited: Bool = false,
        tryOnImageURL: String? = nil,
        reasoning: String? = nil
    ) {
        self.id = id
        self.items = items
        self.occasion = occasion
        self.trendScore = trendScore
        self.weatherSuitability = weatherSuitability
        self.generatedBy = generatedBy
        self.generatedAt = generatedAt
        self.wornOn = wornOn
        self.isFavorited = isFavorited
        self.tryOnImageURL = tryOnImageURL
        self.reasoning = reasoning
    }
}

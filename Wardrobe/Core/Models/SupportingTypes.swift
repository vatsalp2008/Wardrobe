import Foundation

/// Output of `MLService` classification of a segmented garment image (spec §5.1).
/// Each prediction carries a confidence so the review screen can flag low-confidence tags.
struct ClothingTags: Codable, Equatable {
    var category: ClothingCategory
    var colors: [String]             // Hex strings via dominant-color extraction
    var pattern: ClothingPattern
    var formality: FormalityLevel
    var seasons: [Season]
    var confidence: Double           // 0.0–1.0 lowest of the per-attribute confidences

    /// Below this, prompt the user to confirm/correct tags manually (spec §5.1).
    static let manualReviewThreshold = 0.6
}

/// Current weather snapshot used by the outfit generator (spec §5.2 / §6.4).
struct WeatherInfo: Codable, Equatable {
    var temperatureC: Double
    var highC: Double
    var condition: String            // e.g. "Clear", "Rain"
    var isFallback: Bool             // true when produced by the seasonal/dev fallback

    static func seasonalDefault(for season: Season) -> WeatherInfo {
        switch season {
        case .spring: return WeatherInfo(temperatureC: 15, highC: 19, condition: "Mild", isFallback: true)
        case .summer: return WeatherInfo(temperatureC: 27, highC: 31, condition: "Warm", isFallback: true)
        case .fall: return WeatherInfo(temperatureC: 13, highC: 17, condition: "Cool", isFallback: true)
        case .winter: return WeatherInfo(temperatureC: 3, highC: 7, condition: "Cold", isFallback: true)
        }
    }
}

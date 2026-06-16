import Foundation

/// Single read-only accessor for configuration / secrets (spec §10: never hardcode keys).
///
/// Resolution order for each key: process environment variable first (Xcode scheme env vars),
/// then `Config.plist` (gitignored). A missing/empty value means the corresponding service
/// runs in mock mode.
struct AppConfig {
    static let shared = AppConfig()

    private let plist: [String: Any]

    private init() {
        if let url = Bundle.main.url(forResource: "Config", withExtension: "plist"),
           let data = try? Data(contentsOf: url),
           let parsed = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let dict = parsed as? [String: Any] {
            self.plist = dict
        } else {
            self.plist = [:]
        }
    }

    /// Returns a non-empty value for `key`, or nil. Env var wins over Config.plist.
    func value(for key: Key) -> String? {
        if let env = ProcessInfo.processInfo.environment[key.rawValue], !env.isEmpty {
            return env
        }
        if let value = plist[key.rawValue] as? String, !value.isEmpty {
            return value
        }
        return nil
    }

    func isPresent(_ key: Key) -> Bool { value(for: key) != nil }

    enum Key: String {
        case anthropicAPIKey = "ANTHROPIC_API_KEY"
        case geminiAPIKey = "GEMINI_API_KEY"
        case replicateAPIToken = "REPLICATE_API_TOKEN"
        case supabaseURL = "SUPABASE_URL"
        case supabaseAnonKey = "SUPABASE_ANON_KEY"
        case serpAPIKey = "SERPAPI_KEY"
        case removeBGKey = "REMOVE_BG_KEY"
        case openWeatherMapKey = "OPENWEATHERMAP_KEY"
    }
}

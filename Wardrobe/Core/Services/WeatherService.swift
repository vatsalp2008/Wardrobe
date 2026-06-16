import CoreLocation
import Foundation

/// Local weather for weather-aware outfit suggestions (spec §6.4).
///
/// `SeasonalWeatherService` is the default — it derives a reasonable temperature from the
/// current date's season with no entitlement or location permission required, so the app works
/// everywhere. WeatherKit (live, location-based) is **F4** in TRADEOFFS: it needs the
/// `com.apple.developer.weatherkit` entitlement (Apple Developer Program) and is swapped in when
/// that's available, falling back to this seasonal service otherwise.
protocol WeatherServiceProtocol: Sendable {
    func currentWeather(at location: CLLocation?) async throws -> WeatherInfo
}

/// Fixed canned weather for tests/previews.
struct MockWeatherService: WeatherServiceProtocol {
    func currentWeather(at location: CLLocation?) async throws -> WeatherInfo {
        WeatherInfo(temperatureC: 18, highC: 22, condition: "Partly Cloudy", isFallback: true)
    }
}

/// Default real service: seasonal defaults based on the current date (Northern Hemisphere).
/// Always flagged `isFallback: true` so the UI can indicate weather isn't live.
struct SeasonalWeatherService: WeatherServiceProtocol {
    func currentWeather(at location: CLLocation?) async throws -> WeatherInfo {
        WeatherInfo.seasonalDefault(for: Date().season)
    }
}

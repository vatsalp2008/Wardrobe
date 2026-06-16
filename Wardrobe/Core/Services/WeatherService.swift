import CoreLocation
import Foundation

/// Local weather for weather-aware outfit suggestions (spec §6.4). The live adapter uses
/// WeatherKit; when the entitlement is unavailable it falls back to a seasonal default
/// (or an OpenWeatherMap dev key). Phase 0 ships `MockWeatherService`.
protocol WeatherServiceProtocol: Sendable {
    func currentWeather(at location: CLLocation?) async throws -> WeatherInfo
}

struct MockWeatherService: WeatherServiceProtocol {
    func currentWeather(at location: CLLocation?) async throws -> WeatherInfo {
        WeatherInfo(temperatureC: 18, highC: 22, condition: "Partly Cloudy", isFallback: true)
    }
}

import Foundation

/// Live shopping + trend keywords via SerpAPI Google Shopping (spec §5.2 / §5.4).
/// Live adapter added in Phase 4; Phase 0 ships `MockSerpService`.
protocol SerpServiceProtocol: Sendable {
    /// Top shopping results for a gap item, optionally bounded by a max price.
    func shoppingResults(query: String, maxPriceUSD: Int?) async throws -> [ShoppingItem]

    /// Current trending fashion keywords used to drive weekly trend scoring.
    func trendingKeywords() async throws -> [String]
}

struct MockSerpService: SerpServiceProtocol {
    func shoppingResults(query: String, maxPriceUSD: Int?) async throws -> [ShoppingItem] {
        SampleData.sampleShopping
    }

    func trendingKeywords() async throws -> [String] {
        ["quiet luxury", "linen", "barrel jeans", "suede", "burgundy"]
    }
}

/// Live SerpAPI Google Shopping client. Selected by `AppContainer` when `SERPAPI_KEY` is present.
struct LiveSerpService: SerpServiceProtocol {
    static let base = "https://serpapi.com/search.json"
    let apiKey: String
    var session: URLSession = .shared

    func shoppingResults(query: String, maxPriceUSD: Int?) async throws -> [ShoppingItem] {
        var fullQuery = query
        if let maxPriceUSD { fullQuery += " under $\(maxPriceUSD)" }
        var components = URLComponents(string: Self.base)!
        components.queryItems = [
            .init(name: "engine", value: "google_shopping"),
            .init(name: "q", value: fullQuery),
            .init(name: "api_key", value: apiKey)
        ]
        guard let url = components.url else { return [] }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw SerpError.api
        }
        let decoded = try JSONDecoder().decode(SerpResponse.self, from: data)
        return decoded.shoppingResults.prefix(5).map { $0.toShoppingItem() }
    }

    func trendingKeywords() async throws -> [String] {
        // Reuse the mock keyword set until a dedicated trend query is built (TRADEOFFS).
        try await MockSerpService().trendingKeywords()
    }
}

private struct SerpResponse: Decodable {
    let shoppingResults: [Result]
    enum CodingKeys: String, CodingKey { case shoppingResults = "shopping_results" }

    struct Result: Decodable {
        let title: String?
        let price: String?
        let source: String?
        let thumbnail: String?
        let productLink: String?
        let link: String?
        enum CodingKeys: String, CodingKey {
            case title, price, source, thumbnail, link
            case productLink = "product_link"
        }

        func toShoppingItem() -> ShoppingItem {
            ShoppingItem(
                title: title ?? "Item",
                price: price ?? "",
                retailer: source ?? "",
                imageURL: thumbnail ?? "",
                buyLink: productLink ?? link ?? ""
            )
        }
    }
}

enum SerpError: Error { case api }

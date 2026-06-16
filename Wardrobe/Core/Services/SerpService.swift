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

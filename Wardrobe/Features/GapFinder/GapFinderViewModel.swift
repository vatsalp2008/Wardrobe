import SwiftUI

/// Drives Gap Finder (spec §5.4): build the combination matrix → Claude ranks the top gaps →
/// SerpAPI fills shopping results for the top suggestion. Results are cached 24h (expensive).
@MainActor
final class GapFinderViewModel: ObservableObject {
    @Published private(set) var suggestions: [GapSuggestion] = []
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?

    /// Gap analysis is cached for 24 hours (spec §5.4).
    static let cacheTTL: TimeInterval = 60 * 60 * 24

    private let claude: ClaudeServiceProtocol
    private let serp: SerpServiceProtocol
    private let wardrobe: WardrobeRepositoryProtocol
    private let gapRepo: GapRepositoryProtocol

    init(container: AppContainer) {
        self.claude = container.claude
        self.serp = container.serp
        self.wardrobe = container.wardrobe
        self.gapRepo = container.gap
    }

    var topSuggestion: GapSuggestion? { suggestions.first }

    /// Loads cached suggestions if still fresh; otherwise computes a fresh analysis.
    func load() async {
        if await gapRepo.isCacheValid(maxAge: Self.cacheTTL),
           let cached = try? await gapRepo.cachedSuggestions(), !cached.isEmpty {
            suggestions = cached
            return
        }
        await analyze()
    }

    func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let items = try await wardrobe.fetchAll()
            guard !items.isEmpty else {
                suggestions = []
                errorMessage = "Add clothing items to your closet so we can find your gaps."
                return
            }
            let candidates = CombinationMatrix.analyze(items)
            guard !candidates.isEmpty else {
                suggestions = []
                errorMessage = "Your wardrobe already pairs well — no high-impact gaps found."
                return
            }

            var ranked = try await claude.analyzeGap(wardrobe: items, candidates: candidates)
            // Fill shopping results for the top suggestion (the others stay link-free until tapped).
            if let top = ranked.first {
                let results = (try? await serp.shoppingResults(
                    query: top.description, maxPriceUSD: BudgetStore().budgetUSD
                )) ?? []
                ranked[0].shoppingResults = results
            }
            try await gapRepo.save(ranked)
            suggestions = ranked
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't analyze your wardrobe. Please try again."
        }
    }
}

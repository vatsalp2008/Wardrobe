import SwiftUI

/// Drives the Outfits feed (spec §5.2): fetch weather → load wardrobe → soft-exclude
/// recently worn items → fetch trend keywords → generate via Claude → persist & display.
@MainActor
final class OutfitViewModel: ObservableObject {
    @Published private(set) var outfits: [Outfit] = []
    @Published private(set) var weather: WeatherInfo?
    @Published private(set) var isLoading = false
    @Published var selectedOccasion: Occasion?     // nil == "All"
    @Published var errorMessage: String?

    /// Items worn within this many days are soft-excluded from generation (spec §5.2).
    static let recentWearDays = 7
    /// Don't soft-exclude below this many candidates, or we can't build outfits.
    static let minCandidates = 4

    private let claude: ClaudeServiceProtocol
    private let serp: SerpServiceProtocol
    private let weatherService: WeatherServiceProtocol
    private let wardrobe: WardrobeRepositoryProtocol
    private let outfitRepo: OutfitRepositoryProtocol

    init(container: AppContainer) {
        self.claude = container.claude
        self.serp = container.serp
        self.weatherService = container.weather
        self.wardrobe = container.wardrobe
        self.outfitRepo = container.outfits
    }

    var filteredOutfits: [Outfit] {
        guard let selectedOccasion else { return outfits }
        return outfits.filter { $0.occasion == selectedOccasion }
    }

    /// Loads previously generated outfits from storage (fast path on tab open).
    func loadCached() async {
        outfits = (try? await outfitRepo.fetchAll()) ?? []
    }

    /// Full regenerate: the morning/refresh path.
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let info = try await weatherService.currentWeather(at: nil)
            weather = info

            let all = try await wardrobe.fetchAll()
            let candidates = Self.candidateItems(all, excludingWornWithin: Self.recentWearDays, now: Date())
            guard candidates.count >= 2 else {
                outfits = []
                errorMessage = all.isEmpty
                    ? "Add some clothing items to your closet first."
                    : nil
                return
            }

            let keywords = (try? await serp.trendingKeywords()) ?? []
            let generated = try await claude.generateOutfits(
                wardrobe: candidates,
                weather: info,
                occasion: selectedOccasion ?? .casual,
                trendKeywords: keywords
            )
            let ranked = generated.sorted { $0.trendScore > $1.trendScore }
            try await outfitRepo.save(ranked)
            outfits = ranked
        } catch {
            errorMessage = "Couldn't generate outfits. Please try again."
        }
    }

    func toggleFavorite(_ outfit: Outfit) async {
        let newValue = !outfit.isFavorited
        try? await outfitRepo.setFavorite(id: outfit.id, isFavorited: newValue)
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            outfits[index].isFavorited = newValue
        }
    }

    /// Logs the outfit as worn today and increments wear counts on each item (wear tracker, §5.2).
    func markWorn(_ outfit: Outfit) async {
        let today = Date()
        try? await outfitRepo.recordWorn(id: outfit.id, on: today)
        for item in outfit.items {
            try? await wardrobe.markWorn(id: item.id, on: today)
        }
        if let index = outfits.firstIndex(where: { $0.id == outfit.id }) {
            outfits[index].wornOn.append(today)
        }
    }

    /// Pure, testable recent-wear soft-exclude: drops items worn within `days`, but keeps all
    /// items if that would leave too few to build outfits from.
    nonisolated static func candidateItems(_ items: [ClothingItem], excludingWornWithin days: Int, now: Date) -> [ClothingItem] {
        let kept = items.filter { item in
            guard let lastWorn = item.lastWorn else { return true }
            let daysSince = Calendar.current.dateComponents([.day], from: lastWorn, to: now).day ?? Int.max
            return daysSince >= days
        }
        return kept.count >= minCandidates ? kept : items
    }
}

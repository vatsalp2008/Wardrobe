import Foundation

/// Dependency-injection container (plan: "lightweight DI container in App/").
///
/// Constructs every service and repository once and hands them to ViewModels. Each external
/// service resolves to its **Live** adapter when the relevant key is configured, otherwise its
/// **Mock** (mock-first). Phase 0 has no Live adapters yet, so everything resolves to a mock —
/// the `// Phase N:` markers show exactly where each live wiring lands.
@MainActor
final class AppContainer: ObservableObject {
    // External services
    let claude: ClaudeServiceProtocol
    let replicate: ReplicateServiceProtocol
    let serp: SerpServiceProtocol
    let weather: WeatherServiceProtocol
    let supabase: SupabaseServiceProtocol
    let backgroundRemoval: BackgroundRemovalServiceProtocol

    // On-device services
    let vision: VisionServiceProtocol
    let ml: MLServiceProtocol

    // Persistence
    let imageStorage: ImageStorageManaging

    // Repositories
    let wardrobe: WardrobeRepositoryProtocol
    let outfits: OutfitRepositoryProtocol
    let tryOn: TryOnRepositoryProtocol
    let gap: GapRepositoryProtocol

    init(config: AppConfig = .shared) {
        // Live Anthropic client when a key is configured; deterministic mock otherwise.
        if let apiKey = config.value(for: .anthropicAPIKey) {
            self.claude = LiveClaudeService(apiKey: apiKey)
        } else {
            self.claude = MockClaudeService()
        }
        // Live Replicate (IDM-VTON) when a token is configured; mock render otherwise.
        if let token = config.value(for: .replicateAPIToken) {
            self.replicate = LiveReplicateService(apiToken: token)
        } else {
            self.replicate = MockReplicateService()
        }
        // Live SerpAPI shopping/trends when a key is configured; mock otherwise.
        if let serpKey = config.value(for: .serpAPIKey) {
            self.serp = LiveSerpService(apiKey: serpKey)
        } else {
            self.serp = MockSerpService()
        }
        // Seasonal weather by default; WeatherKit (F4) swaps in once the entitlement is available.
        self.weather = SeasonalWeatherService()
        // Live Supabase (anon auth + image hosting) when configured; local-only mock otherwise.
        self.supabase = LiveSupabaseService(config: config) ?? MockSupabaseService()
        // Phase 1: config.isPresent(.removeBGKey) ? RemoveBGService(...) : MockBackgroundRemovalService()
        self.backgroundRemoval = MockBackgroundRemovalService()

        // On-device Vision segmentation + dominant-color classifier (Phase 1).
        // F1 (TRADEOFFS): the trained ClothingClassifier.mlmodel still replaces the
        // category/pattern/formality predictions in OnDeviceMLService once available.
        self.vision = LiveVisionService(fallback: backgroundRemoval)
        self.ml = OnDeviceMLService()

        self.imageStorage = ImageStorageManager(supabase: supabase)

        // Local-first Core Data wardrobe; other repositories swap in their respective phases.
        self.wardrobe = CoreDataWardrobeRepository()
        self.outfits = InMemoryOutfitRepository()
        self.tryOn = InMemoryTryOnRepository()
        self.gap = InMemoryGapRepository()
    }
}

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
        // Phase 2: config.isPresent(.anthropicAPIKey) ? LiveClaudeService(...) : MockClaudeService()
        self.claude = MockClaudeService()
        // Phase 3: config.isPresent(.replicateAPIToken) ? LiveReplicateService(...) : MockReplicateService()
        self.replicate = MockReplicateService()
        // Phase 4: config.isPresent(.serpAPIKey) ? LiveSerpService(...) : MockSerpService()
        self.serp = MockSerpService()
        // Phase 2: WeatherKit adapter when entitlement present; else seasonal/OpenWeatherMap fallback.
        self.weather = MockWeatherService()
        // Phase 5: config.isPresent(.supabaseURL) ? LiveSupabaseService(...) : MockSupabaseService()
        self.supabase = MockSupabaseService()
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

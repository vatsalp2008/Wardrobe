import Foundation

/// Dependency-injection container (plan: "lightweight DI container in App/").
///
/// Constructs every service and repository once and hands them to ViewModels. Each external
/// service resolves to its **Live** adapter when the relevant key is configured, otherwise its
/// **Mock** (mock-first), so the app runs end to end with no keys at all. The selection rules
/// live in `init` below; adding or removing a key in `Config.plist` is the only switch.
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
        // AI stylist provider: Gemini if its key is set, else Claude, else deterministic mock.
        if let geminiKey = config.value(for: .geminiAPIKey) {
            self.claude = GeminiStylistService(apiKey: geminiKey)
        } else if let anthropicKey = config.value(for: .anthropicAPIKey) {
            self.claude = LiveClaudeService(apiKey: anthropicKey)
        } else {
            self.claude = MockClaudeService()
        }
        // Live Replicate (IDM-VTON) only when the token *and* a pinned model version are both
        // configured; a token alone would POST an unusable version and fail. Mock render otherwise.
        if let token = config.value(for: .replicateAPIToken),
           let modelVersion = config.value(for: .replicateModelVersion) {
            self.replicate = LiveReplicateService(apiToken: token, modelVersion: modelVersion)
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
        // On-device `LiveVisionService` is the real segmentation path; this is only its fallback.
        // remove.bg is a paid alternative that hasn't been needed, so the no-op mock stands in.
        self.backgroundRemoval = MockBackgroundRemovalService()

        // On-device Vision segmentation + dominant-color classifier (Phase 1).
        // F1 (TRADEOFFS): the trained ClothingClassifier.mlmodel still replaces the
        // category/pattern/formality predictions in OnDeviceMLService once available.
        self.vision = LiveVisionService(fallback: backgroundRemoval)
        self.ml = OnDeviceMLService()

        self.imageStorage = ImageStorageManager(supabase: supabase)

        // Local-first Core Data wardrobe; mirror to Supabase when cloud sync is configured (F9).
        let localWardrobe = CoreDataWardrobeRepository()
        if supabase.isConfigured {
            self.wardrobe = SyncingWardrobeRepository(local: localWardrobe, supabase: supabase)
        } else {
            self.wardrobe = localWardrobe
        }
        // Local-first Core Data for generated outfits, the try-on render cache, and gap analysis,
        // so all three survive relaunch (they share `CoreDataStack.shared` with the wardrobe).
        self.outfits = CoreDataOutfitRepository()
        self.tryOn = CoreDataTryOnRepository()
        self.gap = CoreDataGapRepository()
    }
}

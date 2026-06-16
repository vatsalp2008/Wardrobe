import SwiftUI

/// Drives Photo Try-On (spec §5.3): one-time encrypted photo setup with pose validation, then
/// per-outfit generation with caching and a daily cost limit.
@MainActor
final class TryOnViewModel: ObservableObject {
    struct DisplayResult: Identifiable {
        let id: UUID            // outfitID
        let original: UIImage
        let rendered: UIImage
    }

    @Published private(set) var hasUserPhoto: Bool
    @Published private(set) var userPhoto: UIImage?
    @Published private(set) var outfits: [Outfit] = []
    @Published private(set) var isGenerating = false
    @Published private(set) var remainingToday: Int
    @Published var setupGuidance: String?
    @Published var errorMessage: String?
    @Published var result: DisplayResult?

    private let replicate: ReplicateServiceProtocol
    private let outfitRepo: OutfitRepositoryProtocol
    private let tryOnRepo: TryOnRepositoryProtocol
    private let photoStore = UserPhotoStore.shared
    private let poseValidator = PoseValidator()
    private let limiter = DailyTryOnLimiter()
    private let imageCache = LocalImageStore.shared
    private let usingLiveReplicate: Bool

    init(container: AppContainer) {
        self.replicate = container.replicate
        self.outfitRepo = container.outfits
        self.tryOnRepo = container.tryOn
        self.hasUserPhoto = UserPhotoStore.shared.hasPhoto
        self.userPhoto = UserPhotoStore.shared.load()
        self.remainingToday = DailyTryOnLimiter().remaining()
        self.usingLiveReplicate = AppConfig.shared.isPresent(.replicateAPIToken)
    }

    func load() async {
        outfits = (try? await outfitRepo.fetchAll()) ?? []
        remainingToday = limiter.remaining()
    }

    /// Validates pose, then stores the photo encrypted (spec §5.3 setup flow).
    func savePhoto(_ image: UIImage) {
        let validation = poseValidator.validate(image)
        guard validation.isValid else {
            setupGuidance = validation.guidance
            return
        }
        do {
            try photoStore.save(image)
            userPhoto = image
            hasUserPhoto = true
            setupGuidance = nil
        } catch {
            errorMessage = "Couldn't save your photo securely. Please try again."
        }
    }

    func removePhoto() {
        photoStore.delete()
        userPhoto = nil
        hasUserPhoto = false
    }

    func generate(for outfit: Outfit) async {
        guard let person = userPhoto else { return }

        // Cache hit → instant, no quota consumed.
        if let cached = try? await tryOnRepo.cachedResult(for: outfit.id),
           let rendered = imageCache.load(cached.renderedImageURL) {
            result = DisplayResult(id: outfit.id, original: person, rendered: rendered)
            return
        }

        guard limiter.canGenerate() else {
            errorMessage = "You've reached today's try-on limit (\(DailyTryOnLimiter.dailyLimit)). Try again tomorrow."
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let rendered: UIImage
        do {
            let outputURL = try await replicate.generateTryOn(
                personImageURL: "local-person",
                garmentImageURLs: outfit.items.map(\.imageURL)
            )
            if usingLiveReplicate, let downloaded = await downloadImage(outputURL) {
                rendered = downloaded
            } else {
                // Mock path: render a local preview composite.
                rendered = TryOnCompositor.preview(person: person, items: outfit.items)
            }
        } catch {
            errorMessage = "Try-on failed. Please try again."
            return
        }

        // Persist locally + record the result, and consume one daily use.
        if let url = imageCache.write(rendered, name: outfit.id.uuidString) {
            try? await tryOnRepo.save(TryOnResult(outfitID: outfit.id, renderedImageURL: url.absoluteString))
        }
        limiter.record()
        remainingToday = limiter.remaining()
        result = DisplayResult(id: outfit.id, original: person, rendered: rendered)
    }

    private func downloadImage(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

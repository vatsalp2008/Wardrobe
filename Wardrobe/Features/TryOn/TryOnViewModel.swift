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
    private let imageStorage: ImageStorageManaging
    private let usingLiveReplicate: Bool
    /// Memoized signed URL for the uploaded person photo, so repeat try-ons in one session
    /// upload once. Cleared whenever the photo changes.
    private var personURLCache: (url: String, expiresAt: Date)?

    /// How long the person photo's signed URL stays valid. Comfortably longer than the ~2 minute
    /// Replicate poll window, short enough that a leaked URL ages out quickly.
    private static let personURLLifetime = 3600

    init(container: AppContainer) {
        self.replicate = container.replicate
        self.outfitRepo = container.outfits
        self.tryOnRepo = container.tryOn
        self.imageStorage = container.imageStorage
        self.hasUserPhoto = UserPhotoStore.shared.hasPhoto
        self.userPhoto = UserPhotoStore.shared.load()
        self.remainingToday = DailyTryOnLimiter().remaining()
        self.usingLiveReplicate = AppConfig.shared.isPresent(.replicateAPIToken)
            && AppConfig.shared.isPresent(.replicateModelVersion)
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
            personURLCache = nil
        } catch {
            errorMessage = "Couldn't save your photo securely. Please try again."
        }
    }

    func removePhoto() {
        photoStore.delete()
        userPhoto = nil
        hasUserPhoto = false
        personURLCache = nil
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

        // Replicate fetches garment images over HTTP. Without cloud hosting they're `mock://`
        // URLs it can't reach, so bail before spending a paid call (the F7 ↔ F12 coupling).
        if usingLiveReplicate, !Self.isRemotelyFetchable(outfit.items.first?.imageURL) {
            errorMessage = "Live try-on also needs cloud image hosting — add SUPABASE_URL and "
                + "SUPABASE_ANON_KEY to Config.plist."
            return
        }

        isGenerating = true
        defer { isGenerating = false }

        let rendered: UIImage
        do {
            let outputURL = try await replicate.generateTryOn(
                personImageURL: try await personImageURL(for: person),
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

    /// Resolves the `human_img` value handed to IDM-VTON.
    ///
    /// On the mock path this returns a sentinel and performs **no** upload and no network call,
    /// so behavior without a Replicate token is exactly what it was before. On the live path the
    /// photo is uploaded to the private `tryon-results` bucket under a content-addressed name and
    /// a short-lived signed URL is returned.
    private func personImageURL(for person: UIImage) async throws -> String {
        guard usingLiveReplicate else { return "local-person" }

        if let cached = personURLCache, cached.expiresAt > Date() {
            return cached.url
        }

        let name = photoStore.fingerprint ?? UUID().uuidString
        let url = try await imageStorage.storePrivate(
            person,
            bucket: .tryOnResults,
            fileName: "person/\(name).png",
            expiresIn: Self.personURLLifetime
        )
        #if DEBUG
        print("[TryOn] person photo signed URL: \(url)")
        #endif
        // Expire our copy a minute early so we never hand Replicate a URL that dies mid-poll.
        personURLCache = (url, Date().addingTimeInterval(Double(Self.personURLLifetime - 60)))
        return url
    }

    private static func isRemotelyFetchable(_ urlString: String?) -> Bool {
        guard let urlString, let scheme = URL(string: urlString)?.scheme else { return false }
        return scheme == "http" || scheme == "https"
    }

    private func downloadImage(_ urlString: String) async -> UIImage? {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true else { return nil }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }
}

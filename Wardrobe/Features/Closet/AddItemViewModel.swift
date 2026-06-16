import SwiftUI
import UIKit

/// Drives the capture → segment → classify → review → save pipeline (spec §5.1).
@MainActor
final class AddItemViewModel: ObservableObject {
    enum Step: Equatable {
        case chooseSource
        case camera
        case processing
        case review
    }

    @Published var step: Step = .chooseSource
    @Published var segmentedImage: UIImage?
    @Published var draft = ClothingItem(name: "", category: .top)
    @Published var needsManualTags = false
    @Published var errorMessage: String?

    private let vision: VisionServiceProtocol
    private let ml: MLServiceProtocol
    private let imageStorage: ImageStorageManaging
    private let wardrobe: WardrobeRepositoryProtocol

    init(container: AppContainer) {
        self.vision = container.vision
        self.ml = container.ml
        self.imageStorage = container.imageStorage
        self.wardrobe = container.wardrobe
    }

    /// Runs the on-device pipeline on a captured/picked image and moves to the review step.
    func process(_ image: UIImage) async {
        step = .processing
        do {
            let (segmented, confidence) = try await vision.segment(image)
            let tags = try await ml.classify(segmented)
            segmentedImage = segmented
            needsManualTags = tags.confidence < ClothingTags.manualReviewThreshold
                || confidence < LiveVisionService.confidenceThreshold
            draft = ClothingItem(
                name: Self.suggestedName(tags),
                category: tags.category,
                color: tags.colors,
                pattern: tags.pattern,
                formality: tags.formality,
                season: tags.seasons
            )
            step = .review
        } catch {
            errorMessage = "Couldn't process the photo. Please try again."
            step = .chooseSource
        }
    }

    /// Persists the reviewed item: stores the image and writes to the wardrobe repository.
    func save() async throws {
        var item = draft
        if let image = segmentedImage {
            item.thumbnailData = imageStorage.thumbnailData(for: image, maxDimension: 600)
            item.imageURL = (try? await imageStorage.store(
                image, bucket: .wardrobeItems, fileName: "\(item.id).png"
            )) ?? ""
        }
        try await wardrobe.add(item)
    }

    private static func suggestedName(_ tags: ClothingTags) -> String {
        tags.category.displayName
    }
}

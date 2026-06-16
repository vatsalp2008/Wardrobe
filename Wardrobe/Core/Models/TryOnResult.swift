import Foundation

/// The result of compositing an outfit onto the user's photo via IDM-VTON (spec §5.3).
struct TryOnResult: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var outfitID: UUID
    var renderedImageURL: String     // Stored in Supabase `tryon-results/` (private)
    var createdAt: Date

    init(
        id: UUID = UUID(),
        outfitID: UUID,
        renderedImageURL: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.outfitID = outfitID
        self.renderedImageURL = renderedImageURL
        self.createdAt = createdAt
    }
}

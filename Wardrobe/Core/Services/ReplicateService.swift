import Foundation

/// Virtual try-on via Replicate's IDM-VTON model (spec §6.2). The live adapter uses the
/// POST-then-poll prediction pattern; Phase 0 ships `MockReplicateService`.
protocol ReplicateServiceProtocol: Sendable {
    /// Composites the garment images onto the person image and returns a rendered image URL.
    /// - Parameters:
    ///   - personImageURL: URL of the user's full-body photo.
    ///   - garmentImageURLs: URLs of the background-removed garment images.
    func generateTryOn(
        personImageURL: String,
        garmentImageURLs: [String]
    ) async throws -> String
}

/// Returns a placeholder image URL after a simulated render delay (spec §5.3 skeleton loader).
struct MockReplicateService: ReplicateServiceProtocol {
    /// Seconds to simulate the IDM-VTON render (real range 10–20s).
    var simulatedDelay: Duration = .seconds(2)

    func generateTryOn(
        personImageURL: String,
        garmentImageURLs: [String]
    ) async throws -> String {
        try await Task.sleep(for: simulatedDelay)
        return "mock://tryon-result/\(garmentImageURLs.count)-items.png"
    }
}

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
/// The displayable mock result is rendered locally by `TryOnViewModel` (`TryOnCompositor`),
/// since this URL isn't a real image.
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

/// Live IDM-VTON client (spec §6.2): POST a prediction, then poll until `succeeded`.
///
/// Selected by `AppContainer` only when **both** `REPLICATE_API_TOKEN` and
/// `REPLICATE_MODEL_VERSION` are present — a token without a pinned version would just POST
/// garbage and 422. Real runs also need publicly reachable image URLs for the person and garment
/// images (F7/F12); `TryOnViewModel` checks that precondition before spending a call.
/// IDM-VTON composites one garment per call, so we use the first.
struct LiveReplicateService: ReplicateServiceProtocol {
    static let createURL = URL(string: "https://api.replicate.com/v1/predictions")!
    static let maxPolls = 40   // ~2 minutes

    let apiToken: String
    /// The exact IDM-VTON version hash from the model's Versions tab on replicate.com.
    let modelVersion: String
    var pollInterval: Duration = .seconds(3)
    var session: URLSession = .shared

    func generateTryOn(personImageURL: String, garmentImageURLs: [String]) async throws -> String {
        guard let garment = garmentImageURLs.first else { throw ReplicateError.noGarment }

        let predictionID = try await createPrediction(person: personImageURL, garment: garment)
        for _ in 0..<Self.maxPolls {
            let (status, output) = try await pollPrediction(id: predictionID)
            switch status {
            case "succeeded":
                guard let output else { throw ReplicateError.noOutput }
                return output
            case "failed", "canceled":
                throw ReplicateError.predictionFailed(status)
            default:
                try await Task.sleep(for: pollInterval)
            }
        }
        throw ReplicateError.timedOut
    }

    private func createPrediction(person: String, garment: String) async throws -> String {
        var request = URLRequest(url: Self.createURL)
        request.httpMethod = "POST"
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = CreateRequest(
            version: modelVersion,
            input: .init(humanImg: person, garmImg: garment, garmentDes: "garment")
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        try Self.checkOK(response, data)
        return try JSONDecoder().decode(PredictionResponse.self, from: data).id
    }

    private func pollPrediction(id: String) async throws -> (status: String, output: String?) {
        var request = URLRequest(url: Self.createURL.appendingPathComponent(id))
        request.setValue("Token \(apiToken)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        try Self.checkOK(response, data)
        let decoded = try JSONDecoder().decode(PredictionResponse.self, from: data)
        return (decoded.status, decoded.output?.first)
    }

    private static func checkOK(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { throw ReplicateError.network }
        guard (200...299).contains(http.statusCode) else {
            throw ReplicateError.api(status: http.statusCode, body: String(data: data, encoding: .utf8) ?? "")
        }
    }
}

private struct CreateRequest: Encodable {
    let version: String
    let input: Input
    struct Input: Encodable {
        let humanImg: String
        let garmImg: String
        let garmentDes: String
        enum CodingKeys: String, CodingKey {
            case humanImg = "human_img"
            case garmImg = "garm_img"
            case garmentDes = "garment_des"
        }
    }
}

private struct PredictionResponse: Decodable {
    let id: String
    let status: String
    /// IDM-VTON returns a single image URL; some models return an array — decode flexibly.
    let output: [String]?

    enum CodingKeys: String, CodingKey { case id, status, output }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        status = try container.decode(String.self, forKey: .status)
        if let array = try? container.decode([String].self, forKey: .output) {
            output = array
        } else if let single = try? container.decode(String.self, forKey: .output) {
            output = [single]
        } else {
            output = nil
        }
    }
}

enum ReplicateError: Error {
    case noGarment
    case noOutput
    case predictionFailed(String)
    case timedOut
    case network
    case api(status: Int, body: String)
}

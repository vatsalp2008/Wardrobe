import UIKit
import XCTest
@testable import Wardrobe

/// Exercises the *live* try-on path end to end without a Replicate token and without any real
/// network traffic: a spy Supabase double captures the upload, and a `URLProtocol`-backed session
/// stands in for api.replicate.com.
final class TryOnPlumbingTests: XCTestCase {

    // MARK: - Doubles

    /// Records what `uploadPrivateImage` was called with.
    private final class SpySupabaseService: SupabaseServiceProtocol, @unchecked Sendable {
        var isConfigured: Bool { true }
        private(set) var bucket: StorageBucket?
        private(set) var fileName: String?
        private(set) var expiresIn: Int?
        private(set) var uploadedData: Data?

        func signInAnonymously() async throws {}
        func uploadImage(_ data: Data, bucket: StorageBucket, fileName: String) async throws -> String {
            "https://example.test/public/\(fileName)"
        }
        func uploadPrivateImage(
            _ data: Data, bucket: StorageBucket, fileName: String, expiresIn: Int
        ) async throws -> String {
            self.bucket = bucket
            self.fileName = fileName
            self.expiresIn = expiresIn
            self.uploadedData = data
            return "https://example.test/signed/\(fileName)?token=abc"
        }
        func upsertItem(_ item: ClothingItem) async throws {}
        func deleteItem(id: UUID) async throws {}
        func fetchItems() async throws -> [ClothingItem] { [] }
    }

    /// Serves canned Replicate responses and records the requests it saw.
    private final class StubURLProtocol: URLProtocol {
        nonisolated(unsafe) static var responses: [(status: Int, body: Data)] = []
        nonisolated(unsafe) static var requestBodies: [Data] = []
        nonisolated(unsafe) static var requestedPaths: [String] = []

        static func reset() {
            responses = []
            requestBodies = []
            requestedPaths = []
        }

        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func stopLoading() {}

        override func startLoading() {
            Self.requestedPaths.append(request.url?.path ?? "")
            // httpBodyStream, because URLSession replaces httpBody by the time we see it.
            if let stream = request.httpBodyStream {
                stream.open()
                var data = Data()
                var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buffer, maxLength: buffer.count)
                    if read <= 0 { break }
                    data.append(buffer, count: read)
                }
                stream.close()
                Self.requestBodies.append(data)
            }

            let next = Self.responses.isEmpty ? (200, Data("{}".utf8)) : Self.responses.removeFirst()
            let response = HTTPURLResponse(
                url: request.url!, statusCode: next.0, httpVersion: nil, headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: next.1)
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    private func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private func makeImage(_ side: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: side, height: side))
        }
    }

    override func setUp() {
        super.setUp()
        StubURLProtocol.reset()
    }

    // MARK: - Private upload

    func testStorePrivateUploadsToTryOnBucketAndDownsizes() async throws {
        let spy = SpySupabaseService()
        let manager = ImageStorageManager(supabase: spy)

        let url = try await manager.storePrivate(
            makeImage(2048), bucket: .tryOnResults, fileName: "person/abc123.png", expiresIn: 3600
        )

        XCTAssertEqual(spy.bucket, .tryOnResults)
        XCTAssertEqual(spy.fileName, "person/abc123.png")
        XCTAssertEqual(spy.expiresIn, 3600)
        XCTAssertTrue(url.contains("token="), "a private bucket needs a signed URL, not a public one")

        // The 2048px source must have been resized to the 1024 spec cap before upload.
        let uploaded = try XCTUnwrap(UIImage(data: try XCTUnwrap(spy.uploadedData)))
        XCTAssertEqual(max(uploaded.size.width, uploaded.size.height), 1024, accuracy: 1)
    }

    // MARK: - Live Replicate client

    func testLiveClientSendsPinnedVersionAndSignedURLThenReturnsOutput() async throws {
        let signedURL = "https://example.test/signed/person/abc.png?token=xyz"
        StubURLProtocol.responses = [
            (201, Data(#"{"id":"pred_1","status":"starting"}"#.utf8)),
            (200, Data(#"{"id":"pred_1","status":"succeeded","output":["https://out.test/r.png"]}"#.utf8))
        ]

        var service = LiveReplicateService(apiToken: "token", modelVersion: "abc123hash")
        service.session = stubbedSession()
        service.pollInterval = .milliseconds(1)

        let output = try await service.generateTryOn(
            personImageURL: signedURL, garmentImageURLs: ["https://g.test/shirt.png"]
        )
        XCTAssertEqual(output, "https://out.test/r.png")

        let body = try XCTUnwrap(StubURLProtocol.requestBodies.first)
        let json = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: body) as? [String: Any]
        )
        XCTAssertEqual(json["version"] as? String, "abc123hash")
        let input = try XCTUnwrap(json["input"] as? [String: Any])
        XCTAssertEqual(input["human_img"] as? String, signedURL)
        XCTAssertEqual(input["garm_img"] as? String, "https://g.test/shirt.png")
    }

    /// The response decoder accepts a bare string as well as an array.
    func testLiveClientAcceptsScalarOutput() async throws {
        StubURLProtocol.responses = [
            (201, Data(#"{"id":"p","status":"starting"}"#.utf8)),
            (200, Data(#"{"id":"p","status":"succeeded","output":"https://out.test/single.png"}"#.utf8))
        ]
        var service = LiveReplicateService(apiToken: "t", modelVersion: "v")
        service.session = stubbedSession()
        service.pollInterval = .milliseconds(1)

        let output = try await service.generateTryOn(
            personImageURL: "https://p.test/a.png", garmentImageURLs: ["https://g.test/b.png"]
        )
        XCTAssertEqual(output, "https://out.test/single.png")
    }

    func testLiveClientSurfacesAPIErrors() async {
        StubURLProtocol.responses = [(401, Data(#"{"detail":"Invalid token"}"#.utf8))]
        var service = LiveReplicateService(apiToken: "bad", modelVersion: "v")
        service.session = stubbedSession()
        service.pollInterval = .milliseconds(1)

        do {
            _ = try await service.generateTryOn(
                personImageURL: "https://p.test/a.png", garmentImageURLs: ["https://g.test/b.png"]
            )
            XCTFail("expected an API error")
        } catch let error as ReplicateError {
            guard case .api(let status, _) = error else {
                return XCTFail("expected .api, got \(error)")
            }
            XCTAssertEqual(status, 401)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    // MARK: - Adapter selection

    @MainActor
    func testGoesLiveOnlyWhenTokenAndVersionAreBothPresent() {
        let both = AppContainer(config: AppConfig(overrides: [
            "REPLICATE_API_TOKEN": "t", "REPLICATE_MODEL_VERSION": "v"
        ]))
        XCTAssertTrue(both.replicate is LiveReplicateService)

        let tokenOnly = AppContainer(config: AppConfig(overrides: ["REPLICATE_API_TOKEN": "t"]))
        XCTAssertTrue(tokenOnly.replicate is MockReplicateService,
                      "a token without a pinned version would POST an unusable version")

        let versionOnly = AppContainer(config: AppConfig(overrides: ["REPLICATE_MODEL_VERSION": "v"]))
        XCTAssertTrue(versionOnly.replicate is MockReplicateService)

        let neither = AppContainer(config: AppConfig(overrides: [:]))
        XCTAssertTrue(neither.replicate is MockReplicateService)
    }

    // MARK: - Photo fingerprint

    func testFingerprintIsStableAndChangesWithThePhoto() throws {
        let store = UserPhotoStore.shared
        store.delete()
        defer { store.delete() }

        XCTAssertNil(store.fingerprint, "no photo saved yet")

        try store.save(makeImage(40))
        let first = try XCTUnwrap(store.fingerprint)
        XCTAssertEqual(first, store.fingerprint, "same ciphertext must hash the same")
        XCTAssertEqual(first.count, 16)

        try store.save(makeImage(60))
        XCTAssertNotEqual(store.fingerprint, first)
    }
}

import Foundation
import Supabase

/// Live Supabase adapter (spec §6.3): anonymous auth on first launch + image upload to storage
/// buckets, returning a public URL. Selected by `AppContainer` when `SUPABASE_URL` and
/// `SUPABASE_ANON_KEY` are configured. Full Core Data ↔ `wardrobe_items` row sync is a documented
/// follow-on (TRADEOFFS) — this delivers auth + image hosting, which makes `imageURL` real.
final class LiveSupabaseService: SupabaseServiceProtocol, @unchecked Sendable {
    private let client: SupabaseClient

    var isConfigured: Bool { true }

    init?(config: AppConfig = .shared) {
        guard let urlString = config.value(for: .supabaseURL),
              let url = URL(string: urlString),
              let anonKey = config.value(for: .supabaseAnonKey) else {
            return nil
        }
        self.client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
    }

    func signInAnonymously() async throws {
        // No-op if a session already exists.
        if (try? await client.auth.session) != nil { return }
        _ = try await client.auth.signInAnonymously()
    }

    func uploadImage(_ data: Data, bucket: StorageBucket, fileName: String) async throws -> String {
        let storage = client.storage.from(bucket.rawValue)
        _ = try await storage.upload(
            fileName,
            data: data,
            options: FileOptions(contentType: "image/png", upsert: true)
        )
        return try storage.getPublicURL(path: fileName).absoluteString
    }
}

import Foundation

/// Abstraction over Supabase auth + storage (spec §6.3). Lets the app run local-only when
/// no Supabase credentials are configured. Live adapter (supabase-swift) added in Phase 5;
/// Phase 0 ships `MockSupabaseService`.
protocol SupabaseServiceProtocol: Sendable {
    /// Whether a real backend is configured. When false the app operates in local-only mode.
    var isConfigured: Bool { get }

    /// Signs in anonymously on first launch (no sign-up required).
    func signInAnonymously() async throws

    /// Uploads image data to the named bucket and returns its URL.
    func uploadImage(_ data: Data, bucket: StorageBucket, fileName: String) async throws -> String

    // MARK: - Wardrobe row sync (F9)

    /// Inserts or updates a wardrobe item row in the cloud `wardrobe_items` table.
    func upsertItem(_ item: ClothingItem) async throws
    /// Deletes a wardrobe item row by id.
    func deleteItem(id: UUID) async throws
    /// Fetches all of the current user's wardrobe item rows.
    func fetchItems() async throws -> [ClothingItem]
}

/// Supabase storage buckets (spec §6.3).
enum StorageBucket: String {
    case wardrobeItems = "wardrobe-items"   // public read, authenticated write
    case tryOnResults = "tryon-results"     // private, user-scoped
}

/// Local-only stand-in: reports "not configured" and returns deterministic fake URLs.
struct MockSupabaseService: SupabaseServiceProtocol {
    var isConfigured: Bool { false }

    func signInAnonymously() async throws {}

    func uploadImage(_ data: Data, bucket: StorageBucket, fileName: String) async throws -> String {
        "mock://\(bucket.rawValue)/\(fileName)"
    }

    func upsertItem(_ item: ClothingItem) async throws {}
    func deleteItem(id: UUID) async throws {}
    func fetchItems() async throws -> [ClothingItem] { [] }
}

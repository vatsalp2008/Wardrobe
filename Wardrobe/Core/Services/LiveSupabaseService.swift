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

    // MARK: - Wardrobe row sync (F9)

    private static let table = "wardrobe_items"

    func upsertItem(_ item: ClothingItem) async throws {
        try await client.from(Self.table).upsert(WardrobeItemRow(item), onConflict: "id").execute()
    }

    func deleteItem(id: UUID) async throws {
        try await client.from(Self.table).delete().eq("id", value: id.uuidString).execute()
    }

    func fetchItems() async throws -> [ClothingItem] {
        let rows: [WardrobeItemRow] = try await client.from(Self.table).select().execute().value
        return rows.compactMap { $0.toModel() }
    }
}

/// Row shape mirroring the `wardrobe_items` table. Thumbnails/embeddings stay local-only.
/// `user_id` is omitted — the table column defaults to `auth.uid()` and RLS scopes rows per user.
private struct WardrobeItemRow: Codable {
    let id: String
    let name: String
    let category: String
    let colors: [String]
    let pattern: String
    let formality: String
    let seasons: [String]
    let imageURL: String
    let wearCount: Int
    let lastWorn: String?
    let dateAdded: String
    let brand: String?
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case id, name, category, colors, pattern, formality, seasons, brand, notes
        case imageURL = "image_url"
        case wearCount = "wear_count"
        case lastWorn = "last_worn"
        case dateAdded = "date_added"
    }

    private static let iso = ISO8601DateFormatter()

    init(_ item: ClothingItem) {
        id = item.id.uuidString
        name = item.name
        category = item.category.rawValue
        colors = item.color
        pattern = item.pattern.rawValue
        formality = item.formality.rawValue
        seasons = item.season.map(\.rawValue)
        imageURL = item.imageURL
        wearCount = item.wearCount
        lastWorn = item.lastWorn.map { Self.iso.string(from: $0) }
        dateAdded = Self.iso.string(from: item.dateAdded)
        brand = item.brand
        notes = item.notes
    }

    func toModel() -> ClothingItem? {
        guard let uuid = UUID(uuidString: id) else { return nil }
        return ClothingItem(
            id: uuid,
            name: name,
            category: ClothingCategory(rawValue: category) ?? .top,
            color: colors,
            pattern: ClothingPattern(rawValue: pattern) ?? .solid,
            formality: FormalityLevel(rawValue: formality) ?? .casual,
            season: seasons.compactMap(Season.init(rawValue:)),
            imageURL: imageURL,
            wearCount: wearCount,
            lastWorn: lastWorn.flatMap { Self.iso.date(from: $0) },
            dateAdded: Self.iso.date(from: dateAdded) ?? Date(),
            brand: brand,
            notes: notes
        )
    }
}

import Foundation

/// Broad garment category. Six classes, matching the Core ML classifier output (spec §5.1).
enum ClothingCategory: String, Codable, CaseIterable, Identifiable {
    case top, bottom, outerwear, shoes, accessory, dress
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .top: return "Top"
        case .bottom: return "Bottom"
        case .outerwear: return "Outerwear"
        case .shoes: return "Shoes"
        case .accessory: return "Accessory"
        case .dress: return "Dress"
        }
    }

    /// SF Symbol used in chips and cards.
    var symbolName: String {
        switch self {
        case .top: return "tshirt"
        case .bottom: return "rectangle.portrait"
        case .outerwear: return "jacket"
        case .shoes: return "shoe"
        case .accessory: return "eyeglasses"
        case .dress: return "figure.dress.line.vertical.figure"
        }
    }
}

/// Surface pattern. Five classes (spec §5.1).
enum ClothingPattern: String, Codable, CaseIterable, Identifiable {
    case solid, striped, plaid, floral, graphic
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// Formality level, ordered casual → formal. Four classes (spec §5.1).
enum FormalityLevel: String, Codable, CaseIterable, Identifiable, Comparable {
    case casual
    case smartCasual = "smart_casual"
    case business
    case formal

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .casual: return "Casual"
        case .smartCasual: return "Smart Casual"
        case .business: return "Business"
        case .formal: return "Formal"
        }
    }

    /// Lower value = more casual. Used for formality-matching in outfit rules.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }

    static func < (lhs: FormalityLevel, rhs: FormalityLevel) -> Bool { lhs.rank < rhs.rank }
}

/// Seasonal suitability. An item may belong to several seasons.
enum Season: String, Codable, CaseIterable, Identifiable {
    case spring, summer, fall, winter
    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

/// A single digitized garment in the user's wardrobe (spec §4.1).
///
/// This is the pure `Codable` value type used throughout the app. It maps to/from the
/// Core Data `ClothingItemEntity` in the persistence layer (added in Phase 1).
struct ClothingItem: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    var name: String                 // Auto-generated or user-edited
    var category: ClothingCategory
    var color: [String]              // Hex strings; multi-color items supported
    var pattern: ClothingPattern
    var formality: FormalityLevel
    var season: [Season]
    var imageURL: String             // Remote (Supabase) URL of background-removed image
    var thumbnailData: Data?         // Local thumbnail for offline display
    var embedding: [Float]           // CLIP visual embedding for similarity search
    var wearCount: Int
    var lastWorn: Date?
    var dateAdded: Date
    var brand: String?
    var notes: String?

    init(
        id: UUID = UUID(),
        name: String,
        category: ClothingCategory,
        color: [String] = [],
        pattern: ClothingPattern = .solid,
        formality: FormalityLevel = .casual,
        season: [Season] = [],
        imageURL: String = "",
        thumbnailData: Data? = nil,
        embedding: [Float] = [],
        wearCount: Int = 0,
        lastWorn: Date? = nil,
        dateAdded: Date = Date(),
        brand: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.color = color
        self.pattern = pattern
        self.formality = formality
        self.season = season
        self.imageURL = imageURL
        self.thumbnailData = thumbnailData
        self.embedding = embedding
        self.wearCount = wearCount
        self.lastWorn = lastWorn
        self.dateAdded = dateAdded
        self.brand = brand
        self.notes = notes
    }
}

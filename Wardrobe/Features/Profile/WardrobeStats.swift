import Foundation

/// Wear-history statistics for the Profile tab (spec §7.1). Pure and testable.
struct WardrobeStats: Equatable {
    var itemCount: Int
    var totalWears: Int
    var neverWornCount: Int
    var mostWornName: String?

    static func compute(_ items: [ClothingItem]) -> WardrobeStats {
        let totalWears = items.reduce(0) { $0 + $1.wearCount }
        let neverWorn = items.filter { $0.wearCount == 0 }.count
        let mostWorn = items.max { $0.wearCount < $1.wearCount }
        return WardrobeStats(
            itemCount: items.count,
            totalWears: totalWears,
            neverWornCount: neverWorn,
            mostWornName: (mostWorn?.wearCount ?? 0) > 0 ? mostWorn?.name : nil
        )
    }
}

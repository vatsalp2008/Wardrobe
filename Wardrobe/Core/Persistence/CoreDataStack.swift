import Foundation

/// Local persistence stack (spec §3.2). **Phase 1** introduces the real `Wardrobe.xcdatamodeld`
/// with a `ClothingItemEntity` matching `ClothingItem`, and this type wraps an
/// `NSPersistentContainer` with a Core-Data-backed `WardrobeRepository`.
///
/// For Phase 0 the app runs on `InMemory*Repository` implementations, so this is an
/// intentionally empty placeholder — it documents where the stack will live without
/// requiring a data model file (which would otherwise crash at launch if missing).
enum CoreDataStack {
    /// Placeholder. Replaced in Phase 1 with `lazy var persistentContainer: NSPersistentContainer`.
    static let modelName = "Wardrobe"
}

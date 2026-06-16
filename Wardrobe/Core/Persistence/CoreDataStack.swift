import CoreData
import Foundation

/// Local persistence stack (spec §3.2). Loads the `Wardrobe` model and exposes an
/// `NSPersistentContainer`. Use `.shared` in the app and `.inMemory()` in tests/previews.
final class CoreDataStack: @unchecked Sendable {
    static let modelName = "Wardrobe"
    static let shared = CoreDataStack()

    let container: NSPersistentContainer

    private init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        container.loadPersistentStores { _, error in
            if let error {
                // A failed local store load is unrecoverable and indicates a model/migration bug.
                fatalError("Core Data store failed to load: \(error)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    /// In-memory stack for unit tests and SwiftUI previews (no on-disk file).
    static func inMemory() -> CoreDataStack {
        CoreDataStack(inMemory: true)
    }
}

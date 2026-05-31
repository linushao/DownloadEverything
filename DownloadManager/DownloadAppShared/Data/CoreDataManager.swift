import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()

    static var isTesting: Bool = {
        return ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }()

    private init() {}

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "DownloadApp")

        if CoreDataManager.isTesting {
            let description = NSPersistentStoreDescription()
            description.type = NSInMemoryStoreType
            description.shouldAddStoreAsynchronously = false
            container.persistentStoreDescriptions = [description]
        }

        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Core Data store failed to load: \(error.localizedDescription)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    var backgroundContext: NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    func saveContext(_ context: NSManagedObjectContext? = nil) {
        let context = context ?? viewContext

        if context.concurrencyType == .mainQueueConcurrencyType {
            if !Thread.isMainThread {
                DispatchQueue.main.sync {
                    performSave(on: context)
                }
            } else {
                performSave(on: context)
            }
        } else {
            performSave(on: context)
        }
    }

    private func performSave(on context: NSManagedObjectContext) {
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    static func resetForTesting() {
        let context = shared.viewContext
        let coordinator = shared.persistentContainer.persistentStoreCoordinator

        for store in coordinator.persistentStores {
            try? coordinator.remove(store)
        }

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false

        coordinator.addPersistentStore(with: description) { description, error in
            if let error = error {
                print("Failed to add in-memory store: \(error)")
            }
        }
    }
}

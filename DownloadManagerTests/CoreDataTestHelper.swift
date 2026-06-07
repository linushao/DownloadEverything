import CoreData
import XCTest

@testable import DownloadManager

class CoreDataTestHelper {

    static let shared = CoreDataTestHelper()

    private func findCoreDataModelURL() -> URL? {
        if let url = Bundle(for: type(of: self)).url(
            forResource: "DownloadApp", withExtension: "momd")
        {
            return url
        }
        if let url = Bundle.main.url(forResource: "DownloadApp", withExtension: "momd") {
            return url
        }
        return nil
    }

    lazy var persistentContainer: NSPersistentContainer = {
        guard let modelURL = findCoreDataModelURL() else {
            fatalError("Failed to find Core Data model file")
        }

        guard let managedObjectModel = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model")
        }

        let container = NSPersistentContainer(
            name: "DownloadApp", managedObjectModel: managedObjectModel)

        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

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
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }

    func clearAllData() {
        let context = viewContext

        let shareRequest: NSFetchRequest<NSFetchRequestResult> = ShareEntity.fetchRequest()
        let shareDeleteRequest = NSBatchDeleteRequest(fetchRequest: shareRequest)
        try? context.execute(shareDeleteRequest)

        let downloadRequest: NSFetchRequest<NSFetchRequestResult> = DownloadEntity.fetchRequest()
        let downloadDeleteRequest = NSBatchDeleteRequest(fetchRequest: downloadRequest)
        try? context.execute(downloadDeleteRequest)

        saveContext()
    }
}

extension XCTestCase {

    func waitForCoreDataOperations(timeout: TimeInterval = 1.0) {
        let expectation = XCTestExpectation(description: "Core Data operations")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: timeout)
    }
}

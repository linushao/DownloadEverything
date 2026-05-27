import Foundation
import CoreData

class DownloadRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataManager.shared.viewContext) {
        self.context = context
    }
    
    func createDownloadTask(
        taskId: UUID,
        url: String,
        fileName: String,
        savePath: String
    ) -> DownloadEntity {
        let task = DownloadEntity(context: context)
        task.taskId = taskId
        task.url = url
        task.fileName = fileName
        task.savePath = savePath
        task.totalBytes = 0
        task.downloadedBytes = 0
        task.status = 0
        task.speed = 0.0
        task.createdAt = Date()
        task.updatedAt = Date()
        save()
        return task
    }
    
    func fetchAllDownloadTasks() -> [DownloadEntity] {
        let request: NSFetchRequest<DownloadEntity> = DownloadEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch download tasks: \(error)")
            return []
        }
    }
    
    func fetchDownloadTask(by taskId: UUID) -> DownloadEntity? {
        let request: NSFetchRequest<DownloadEntity> = DownloadEntity.fetchRequest()
        request.predicate = NSPredicate(format: "taskId == %@", taskId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch download task: \(error)")
            return nil
        }
    }
    
    func updateDownloadTask(
        taskId: UUID,
        totalBytes: Int64? = nil,
        downloadedBytes: Int64? = nil,
        status: Int16? = nil,
        speed: Double? = nil,
        resumeData: Data? = nil
    ) {
        guard let task = fetchDownloadTask(by: taskId) else { return }
        
        if let totalBytes = totalBytes {
            task.totalBytes = totalBytes
        }
        if let downloadedBytes = downloadedBytes {
            task.downloadedBytes = downloadedBytes
        }
        if let status = status {
            task.status = status
        }
        if let speed = speed {
            task.speed = speed
        }
        task.resumeData = resumeData
        task.updatedAt = Date()
        save()
    }
    
    func deleteDownloadTask(taskId: UUID) {
        guard let task = fetchDownloadTask(by: taskId) else { return }
        context.delete(task)
        save()
    }
    
    private func save() {
        CoreDataManager.shared.saveContext(context)
    }
}

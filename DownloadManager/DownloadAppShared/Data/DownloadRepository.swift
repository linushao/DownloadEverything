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
        savePath: String,
        isM3U8: Bool = false
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
        task.segmentCount = 0
        task.downloadedSegments = 0
        task.isMerged = false
        task.isM3U8 = isM3U8
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
    
    func updateM3U8Task(
        taskId: UUID,
        segmentCount: Int64? = nil,
        downloadedSegments: Int64? = nil,
        isMerged: Bool? = nil,
        tempDirectory: String? = nil,
        status: Int16? = nil,
        speed: Double? = nil
    ) {
        guard let task = fetchDownloadTask(by: taskId) else { return }
        
        if let segmentCount = segmentCount {
            task.segmentCount = segmentCount
        }
        if let downloadedSegments = downloadedSegments {
            task.downloadedSegments = downloadedSegments
        }
        if let isMerged = isMerged {
            task.isMerged = isMerged
        }
        if let tempDirectory = tempDirectory {
            task.tempDirectory = tempDirectory
        }
        if let status = status {
            task.status = status
        }
        if let speed = speed {
            task.speed = speed
        }
        task.updatedAt = Date()
        save()
    }
    
    func deleteDownloadTask(taskId: UUID) {
        guard let task = fetchDownloadTask(by: taskId) else { return }
        context.delete(task)
        save()
    }
    
    private func save() {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            print("Failed to save context: \(error)")
        }
    }
}

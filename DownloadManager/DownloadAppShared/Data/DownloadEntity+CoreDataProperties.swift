import Foundation
import CoreData

extension DownloadEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<DownloadEntity> {
        return NSFetchRequest<DownloadEntity>(entityName: "DownloadEntity")
    }

    @NSManaged public var taskId: UUID
    @NSManaged public var url: String
    @NSManaged public var fileName: String
    @NSManaged public var savePath: String
    @NSManaged public var totalBytes: Int64
    @NSManaged public var downloadedBytes: Int64
    @NSManaged public var status: Int16
    @NSManaged public var speed: Double
    @NSManaged public var resumeData: Data?
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date

}

extension DownloadEntity : Identifiable {

}

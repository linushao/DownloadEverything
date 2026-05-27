import Foundation
import CoreData

extension ShareEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<ShareEntity> {
        return NSFetchRequest<ShareEntity>(entityName: "ShareEntity")
    }

    @NSManaged public var shareId: UUID
    @NSManaged public var filePath: String
    @NSManaged public var shareType: Int16
    @NSManaged public var accessToken: String
    @NSManaged public var permission: Int16
    @NSManaged public var expiresAt: Date?
    @NSManaged public var createdAt: Date

}

extension ShareEntity : Identifiable {

}

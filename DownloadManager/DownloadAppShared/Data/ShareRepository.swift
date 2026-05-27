import Foundation
import CoreData

class ShareRepository {
    private let context: NSManagedObjectContext
    
    init(context: NSManagedObjectContext = CoreDataManager.shared.viewContext) {
        self.context = context
    }
    
    func createShare(
        shareId: UUID,
        filePath: String,
        shareType: Int16,
        accessToken: String,
        permission: Int16,
        expiresAt: Date? = nil
    ) -> ShareEntity {
        let share = ShareEntity(context: context)
        share.shareId = shareId
        share.filePath = filePath
        share.shareType = shareType
        share.accessToken = accessToken
        share.permission = permission
        share.expiresAt = expiresAt
        share.createdAt = Date()
        save()
        return share
    }
    
    func fetchAllShares() -> [ShareEntity] {
        let request: NSFetchRequest<ShareEntity> = ShareEntity.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "createdAt", ascending: false)
        request.sortDescriptors = [sortDescriptor]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Failed to fetch shares: \(error)")
            return []
        }
    }
    
    func fetchShare(by shareId: UUID) -> ShareEntity? {
        let request: NSFetchRequest<ShareEntity> = ShareEntity.fetchRequest()
        request.predicate = NSPredicate(format: "shareId == %@", shareId as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch share: \(error)")
            return nil
        }
    }
    
    func fetchShare(by accessToken: String) -> ShareEntity? {
        let request: NSFetchRequest<ShareEntity> = ShareEntity.fetchRequest()
        request.predicate = NSPredicate(format: "accessToken == %@", accessToken)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Failed to fetch share by token: \(error)")
            return nil
        }
    }
    
    func deleteShare(shareId: UUID) {
        guard let share = fetchShare(by: shareId) else { return }
        context.delete(share)
        save()
    }
    
    private func save() {
        CoreDataManager.shared.saveContext(context)
    }
}

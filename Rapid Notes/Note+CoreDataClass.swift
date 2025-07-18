import Foundation
import CoreData

@objc(Note)
public class Note: NSManagedObject {
    
}

extension Note {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Note> {
        return NSFetchRequest<Note>(entityName: "Note")
    }
    
    @NSManaged public var id: UUID?
    @NSManaged public var content: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locationName: String?
    @NSManaged public var isVoiceNote: Bool
    @NSManaged public var aiTags: String?
    @NSManaged public var aiSummary: String?
}

extension Note: Identifiable {
    
}
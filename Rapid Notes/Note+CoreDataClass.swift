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
    @NSManaged public var language: String?
    @NSManaged public var detectedLanguage: String?
    @NSManaged public var languageConfidence: Double
}

extension Note: Identifiable {
    
    /// Get the supported language enum from the language string
    var supportedLanguage: SupportedLanguage? {
        guard let languageCode = language else { return nil }
        return SupportedLanguage(rawValue: languageCode)
    }
    
    /// Get the detected supported language enum
    var detectedSupportedLanguage: SupportedLanguage? {
        guard let languageCode = detectedLanguage else { return nil }
        return SupportedLanguage(rawValue: languageCode)
    }
    
    /// Set the language using SupportedLanguage enum
    func setLanguage(_ supportedLanguage: SupportedLanguage) {
        self.language = supportedLanguage.rawValue
    }
    
    /// Set the detected language with confidence
    func setDetectedLanguage(_ supportedLanguage: SupportedLanguage, confidence: Double) {
        self.detectedLanguage = supportedLanguage.rawValue
        self.languageConfidence = confidence
    }
    
    /// Check if the detected language differs from the set language
    var hasLanguageMismatch: Bool {
        guard let currentLang = supportedLanguage,
              let detectedLang = detectedSupportedLanguage,
              languageConfidence > 0.7 else {
            return false
        }
        return currentLang != detectedLang
    }
    
    /// Get display string for the note's language
    var languageDisplayName: String {
        return supportedLanguage?.displayName ?? "Unknown"
    }
    
    /// Get flag emoji for the note's language
    var languageFlag: String {
        return supportedLanguage?.flag ?? "🌐"
    }
}
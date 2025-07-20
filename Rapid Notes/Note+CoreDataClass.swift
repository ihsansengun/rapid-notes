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
    
    // AI Memory Assistant fields
    @NSManaged public var aiCategory: String?
    @NSManaged public var aiInterpretation: String?
    @NSManaged public var aiNextSteps: String?
    @NSManaged public var aiReminderSuggestion: String?
    @NSManaged public var aiConfidence: Double
    @NSManaged public var aiExpandedText: String?
    @NSManaged public var aiExpansionStyle: String?
    @NSManaged public var needsAIProcessing: Bool
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
    
    // MARK: - AI Memory Assistant Helpers
    
    /// Get parsed AI tags as an array
    var aiTagsArray: [String] {
        guard let tagsString = aiTags, !tagsString.isEmpty else { return [] }
        return tagsString.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
    
    /// Set AI tags from an array
    func setAITags(_ tags: [String]) {
        self.aiTags = tags.joined(separator: ", ")
    }
    
    /// Get parsed next steps as an array
    var aiNextStepsArray: [String] {
        guard let stepsString = aiNextSteps, !stepsString.isEmpty else { return [] }
        return stepsString.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
    
    /// Set AI next steps from an array
    func setAINextSteps(_ steps: [String]) {
        self.aiNextSteps = steps.joined(separator: "\n")
    }
    
    /// Get the expansion style enum
    var aiExpansionStyleEnum: ExpansionStyle? {
        guard let style = aiExpansionStyle else { return nil }
        return ExpansionStyle(rawValue: style)
    }
    
    /// Set the expansion style from enum
    func setAIExpansionStyle(_ style: ExpansionStyle) {
        self.aiExpansionStyle = style.rawValue
    }
    
    /// Update note with AI clarity results
    func updateWithClarity(_ clarity: NoteClarity) {
        self.aiInterpretation = clarity.interpretation
        self.aiCategory = clarity.suggestedCategory
        self.setAINextSteps(clarity.nextSteps)
        self.aiReminderSuggestion = clarity.reminderSuggestion
        self.aiConfidence = clarity.confidence
        self.needsAIProcessing = false
    }
    
    /// Update note with AI expansion results
    func updateWithExpansion(_ expansion: NoteExpansion) {
        self.aiExpandedText = expansion.expandedText
        self.setAIExpansionStyle(expansion.expansionStyle)
        self.aiConfidence = max(self.aiConfidence, expansion.confidence) // Keep the higher confidence
    }
    
    /// Check if AI processing has been completed
    var hasAIProcessing: Bool {
        return aiInterpretation != nil || aiCategory != nil || !aiNextStepsArray.isEmpty
    }
    
    /// Check if AI processing confidence is high enough to show suggestions
    var hasHighConfidenceAI: Bool {
        return aiConfidence >= 0.7
    }
    
    /// Check if note has background insights discovered through memory processing
    var hasBackgroundInsights: Bool {
        return aiCategory != nil || hasMemoryConnections
    }
    
    /// Check if this note has been connected to other notes through memory analysis
    var hasMemoryConnections: Bool {
        // TODO: Implement memory thread detection
        // For now, return true if we have some AI processing
        return aiCategory != nil && aiConfidence > 0.5
    }
    
    /// Get a brief description of AI category in user's language
    var localizedAICategory: String? {
        guard let category = aiCategory,
              let lang = supportedLanguage else { return aiCategory }
        
        return LocalizedCategory.getDisplayName(for: category, language: lang)
    }
}
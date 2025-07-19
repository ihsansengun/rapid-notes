import Foundation
import NaturalLanguage

/// Service for detecting the language of text content
class LanguageDetector {
    static let shared = LanguageDetector()
    
    private let languageRecognizer = NLLanguageRecognizer()
    
    private init() {}
    
    /// Detect the language of given text
    /// - Parameter text: The text to analyze
    /// - Returns: The detected SupportedLanguage, or nil if detection fails
    func detectLanguage(from text: String) -> SupportedLanguage? {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        
        guard let dominantLanguage = languageRecognizer.dominantLanguage else {
            return nil
        }
        
        return mapNLLanguageToSupportedLanguage(dominantLanguage)
    }
    
    /// Detect language with confidence score
    /// - Parameter text: The text to analyze
    /// - Returns: A tuple containing the detected language and confidence score (0.0-1.0)
    func detectLanguageWithConfidence(from text: String) -> (language: SupportedLanguage?, confidence: Double) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (nil, 0.0)
        }
        
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        
        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: 5)
        
        guard let dominantLanguage = hypotheses.keys.first,
              let confidence = hypotheses[dominantLanguage] else {
            return (nil, 0.0)
        }
        
        let supportedLanguage = mapNLLanguageToSupportedLanguage(dominantLanguage)
        return (supportedLanguage, confidence)
    }
    
    /// Get multiple language hypotheses with confidence scores
    /// - Parameter text: The text to analyze
    /// - Returns: Array of tuples containing languages and their confidence scores
    func getLanguageHypotheses(from text: String, maxCount: Int = 3) -> [(language: SupportedLanguage, confidence: Double)] {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        languageRecognizer.reset()
        languageRecognizer.processString(text)
        
        let hypotheses = languageRecognizer.languageHypotheses(withMaximum: maxCount)
        
        return hypotheses.compactMap { (nlLanguage, confidence) in
            guard let supportedLanguage = mapNLLanguageToSupportedLanguage(nlLanguage) else {
                return nil
            }
            return (supportedLanguage, confidence)
        }.sorted { $0.confidence > $1.confidence }
    }
    
    /// Map NLLanguage to SupportedLanguage
    private func mapNLLanguageToSupportedLanguage(_ nlLanguage: NLLanguage) -> SupportedLanguage? {
        switch nlLanguage {
        case .english:
            return .english
        case .spanish:
            return .spanish
        case .french:
            return .french
        case .german:
            return .german
        case .italian:
            return .italian
        case .portuguese:
            return .portuguese
        case .japanese:
            return .japanese
        case .simplifiedChinese, .traditionalChinese:
            return .chinese
        case .korean:
            return .korean
        case .russian:
            return .russian
        case .turkish:
            return .turkish
        default:
            return nil
        }
    }
    
    /// Check if the detected language is different from current language setting
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - currentLanguage: Current language setting
    /// - Returns: True if detected language differs from current setting
    func shouldSuggestLanguageChange(for text: String, currentLanguage: SupportedLanguage) -> Bool {
        let (detectedLanguage, confidence) = detectLanguageWithConfidence(from: text)
        
        guard let detected = detectedLanguage,
              confidence > 0.7, // High confidence threshold
              detected != currentLanguage else {
            return false
        }
        
        return true
    }
    
    /// Get suggested language change with reason
    /// - Parameters:
    ///   - text: Text to analyze
    ///   - currentLanguage: Current language setting
    /// - Returns: Tuple with suggested language and confidence, or nil if no change needed
    func getSuggestedLanguageChange(for text: String, currentLanguage: SupportedLanguage) -> (language: SupportedLanguage, confidence: Double)? {
        let (detectedLanguage, confidence) = detectLanguageWithConfidence(from: text)
        
        guard let detected = detectedLanguage,
              confidence > 0.7,
              detected != currentLanguage else {
            return nil
        }
        
        return (detected, confidence)
    }
    
    /// Analyze text for mixed language content
    /// - Parameter text: Text to analyze
    /// - Returns: Array of language segments detected in the text
    func analyzeMixedLanguageContent(_ text: String) -> [LanguageSegment] {
        let sentences = text.components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var segments: [LanguageSegment] = []
        
        for sentence in sentences {
            let (language, confidence) = detectLanguageWithConfidence(from: sentence)
            
            if let detectedLanguage = language, confidence > 0.5 {
                segments.append(LanguageSegment(
                    text: sentence,
                    language: detectedLanguage,
                    confidence: confidence
                ))
            }
        }
        
        return segments
    }
    
    /// Debug language detection results
    func debugDetection(for text: String) {
        print("=== Language Detection Debug ===")
        print("Text: \"\(text.prefix(100))...\"")
        
        let (primaryLanguage, confidence) = detectLanguageWithConfidence(from: text)
        print("Primary: \(primaryLanguage?.displayName ?? "Unknown") (confidence: \(String(format: "%.2f", confidence)))")
        
        let hypotheses = getLanguageHypotheses(from: text, maxCount: 5)
        print("Hypotheses:")
        for (language, conf) in hypotheses {
            print("  - \(language.displayName): \(String(format: "%.2f", conf))")
        }
        
        let segments = analyzeMixedLanguageContent(text)
        if segments.count > 1 {
            print("Mixed language detected (\(segments.count) segments):")
            for segment in segments.prefix(3) {
                print("  - \(segment.language.displayName): \"\(segment.text.prefix(50))...\"")
            }
        }
        
        print("================================")
    }
}

/// Represents a segment of text with detected language
struct LanguageSegment {
    let text: String
    let language: SupportedLanguage
    let confidence: Double
}
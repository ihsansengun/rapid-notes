import Foundation

/// Service for comparing transcripts from different engines and determining the best result
class TranscriptComparator {
    static let shared = TranscriptComparator()
    
    private init() {}
    
    /// Compare Apple Speech and Whisper results and return the best one
    func chooseBestTranscript(
        appleResult: AppleTranscriptResult?,
        whisperResult: WhisperResult?
    ) -> TranscriptComparisonResult {
        
        // If only one result is available, use it
        if let whisperResult = whisperResult, appleResult == nil {
            return TranscriptComparisonResult(
                chosenTranscript: whisperResult.text,
                chosenEngine: .whisper,
                confidence: whisperResult.confidence,
                reason: "Only Whisper result available",
                appleText: nil,
                whisperText: whisperResult.text,
                similarityScore: 0.0
            )
        }
        
        if let appleResult = appleResult, whisperResult == nil {
            return TranscriptComparisonResult(
                chosenTranscript: appleResult.text,
                chosenEngine: .appleSpeech,
                confidence: appleResult.confidence,
                reason: "Only Apple Speech result available",
                appleText: appleResult.text,
                whisperText: nil,
                similarityScore: 0.0
            )
        }
        
        // If both results are available, compare them
        guard let appleResult = appleResult, let whisperResult = whisperResult else {
            return TranscriptComparisonResult(
                chosenTranscript: "",
                chosenEngine: .none,
                confidence: 0.0,
                reason: "No transcription results available",
                appleText: nil,
                whisperText: nil,
                similarityScore: 0.0
            )
        }
        
        return compareTranscripts(apple: appleResult, whisper: whisperResult)
    }
    
    // MARK: - Private Methods
    
    private func compareTranscripts(apple: AppleTranscriptResult, whisper: WhisperResult) -> TranscriptComparisonResult {
        let appleText = apple.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let whisperText = whisper.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Calculate similarity between the two transcripts
        let similarity = calculateSimilarity(appleText, whisperText)
        
        // Decision logic based on confidence, similarity, and length
        let decision = makeTranscriptDecision(
            apple: apple,
            whisper: whisper,
            similarity: similarity
        )
        
        return TranscriptComparisonResult(
            chosenTranscript: decision.chosenText,
            chosenEngine: decision.engine,
            confidence: decision.confidence,
            reason: decision.reason,
            appleText: appleText,
            whisperText: whisperText,
            similarityScore: similarity
        )
    }
    
    private func makeTranscriptDecision(
        apple: AppleTranscriptResult,
        whisper: WhisperResult,
        similarity: Double
    ) -> (chosenText: String, engine: TranscriptEngine, confidence: Double, reason: String) {
        
        let appleText = apple.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let whisperText = whisper.text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Both empty - no good result
        if appleText.isEmpty && whisperText.isEmpty {
            return (appleText, .appleSpeech, 0.0, "Both transcripts empty")
        }
        
        // One empty - choose the non-empty one
        if appleText.isEmpty && !whisperText.isEmpty {
            return (whisperText, .whisper, whisper.confidence, "Apple transcript empty")
        }
        
        if !appleText.isEmpty && whisperText.isEmpty {
            return (appleText, .appleSpeech, apple.confidence, "Whisper transcript empty")
        }
        
        // Both have content - compare quality
        let confidenceThreshold = Config.transcriptConfidenceThreshold
        let similarityThreshold = 0.7 // 70% similarity threshold
        
        // High similarity - choose higher confidence
        if similarity >= similarityThreshold {
            if whisper.confidence > apple.confidence {
                return (whisperText, .whisper, whisper.confidence, "Similar transcripts, Whisper higher confidence")
            } else {
                return (appleText, .appleSpeech, apple.confidence, "Similar transcripts, Apple Speech higher confidence")
            }
        }
        
        // Low similarity - need to decide based on confidence and other factors
        
        // Very high confidence from one engine
        if whisper.confidence >= confidenceThreshold && apple.confidence < (confidenceThreshold - 0.1) {
            return (whisperText, .whisper, whisper.confidence, "Whisper very high confidence")
        }
        
        if apple.confidence >= confidenceThreshold && whisper.confidence < (confidenceThreshold - 0.1) {
            return (appleText, .appleSpeech, apple.confidence, "Apple Speech very high confidence")
        }
        
        // Length consideration - longer transcript might be more complete
        let lengthDifference = abs(appleText.count - whisperText.count)
        let averageLength = (appleText.count + whisperText.count) / 2
        let lengthDifferenceRatio = Double(lengthDifference) / Double(max(averageLength, 1))
        
        // Significant length difference with good confidence
        if lengthDifferenceRatio > 0.3 {
            if whisperText.count > appleText.count && whisper.confidence >= 0.6 {
                return (whisperText, .whisper, whisper.confidence, "Whisper significantly longer with good confidence")
            }
            
            if appleText.count > whisperText.count && apple.confidence >= 0.6 {
                return (appleText, .appleSpeech, apple.confidence, "Apple Speech significantly longer with good confidence")
            }
        }
        
        // Language consideration - Whisper is generally better at multilingual
        if let detectedLang = whisper.supportedLanguage,
           detectedLang != .english && whisper.confidence >= 0.5 {
            return (whisperText, .whisper, whisper.confidence, "Non-English language detected, Whisper preferred")
        }
        
        // Default fallback - choose based on overall confidence
        if whisper.confidence > apple.confidence {
            return (whisperText, .whisper, whisper.confidence, "Whisper higher overall confidence")
        } else {
            return (appleText, .appleSpeech, apple.confidence, "Apple Speech higher overall confidence")
        }
    }
    
    /// Calculate similarity between two strings using a combination of metrics
    private func calculateSimilarity(_ text1: String, _ text2: String) -> Double {
        guard !text1.isEmpty && !text2.isEmpty else { return 0.0 }
        
        // Normalize texts for comparison
        let normalized1 = text1.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized2 = text2.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Exact match
        if normalized1 == normalized2 {
            return 1.0
        }
        
        // Calculate word-level similarity
        let words1 = normalized1.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        let words2 = normalized2.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }
        
        let wordSimilarity = calculateWordSimilarity(words1: words1, words2: words2)
        
        // Calculate character-level similarity (Levenshtein distance)
        let charSimilarity = calculateCharacterSimilarity(text1: normalized1, text2: normalized2)
        
        // Weighted average: 70% word similarity, 30% character similarity
        return (wordSimilarity * 0.7) + (charSimilarity * 0.3)
    }
    
    private func calculateWordSimilarity(words1: [String], words2: [String]) -> Double {
        guard !words1.isEmpty && !words2.isEmpty else { return 0.0 }
        
        let set1 = Set(words1)
        let set2 = Set(words2)
        
        let intersection = set1.intersection(set2)
        let union = set1.union(set2)
        
        return Double(intersection.count) / Double(union.count)
    }
    
    private func calculateCharacterSimilarity(text1: String, text2: String) -> Double {
        let distance = levenshteinDistance(text1, text2)
        let maxLength = max(text1.count, text2.count)
        
        return maxLength > 0 ? 1.0 - (Double(distance) / Double(maxLength)) : 1.0
    }
    
    /// Calculate Levenshtein distance between two strings
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let a1 = Array(s1)
        let a2 = Array(s2)
        
        var dp = Array(repeating: Array(repeating: 0, count: a2.count + 1), count: a1.count + 1)
        
        for i in 0...a1.count {
            dp[i][0] = i
        }
        
        for j in 0...a2.count {
            dp[0][j] = j
        }
        
        for i in 1...a1.count {
            for j in 1...a2.count {
                if a1[i-1] == a2[j-1] {
                    dp[i][j] = dp[i-1][j-1]
                } else {
                    dp[i][j] = min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1]) + 1
                }
            }
        }
        
        return dp[a1.count][a2.count]
    }
}

// MARK: - Data Models

struct AppleTranscriptResult {
    let text: String
    let confidence: Double
    let isFinal: Bool
    let detectedLanguage: SupportedLanguage?
    
    init(text: String, confidence: Double = 1.0, isFinal: Bool = true, detectedLanguage: SupportedLanguage? = nil) {
        self.text = text
        self.confidence = confidence
        self.isFinal = isFinal
        self.detectedLanguage = detectedLanguage
    }
}

struct TranscriptComparisonResult {
    let chosenTranscript: String
    let chosenEngine: TranscriptEngine
    let confidence: Double
    let reason: String
    let appleText: String?
    let whisperText: String?
    let similarityScore: Double
    
    var isHighQuality: Bool {
        return confidence >= Config.transcriptConfidenceThreshold
    }
    
    var needsReview: Bool {
        return confidence < 0.6 || similarityScore < 0.5
    }
}

enum TranscriptEngine {
    case appleSpeech
    case whisper
    case none
    
    var displayName: String {
        switch self {
        case .appleSpeech: return "Apple Speech"
        case .whisper: return "Whisper"
        case .none: return "None"
        }
    }
}
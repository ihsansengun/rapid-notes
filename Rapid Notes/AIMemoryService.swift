import Foundation

/// AI-powered memory assistant that helps clarify, categorize, and enhance voice notes
/// Based on QuickDump_AI_Memory_Assistant.md specifications
@MainActor
class AIMemoryService: ObservableObject {
    private let aiService = AIService()
    private let languageService = LanguageService.shared
    private let languageDetector = LanguageDetector.shared
    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    // MARK: - Core Memory Assistant Functions
    
    /// Clarify messy or incomplete voice notes and suggest next actions
    func clarifyNote(_ content: String, language: SupportedLanguage? = nil) async -> NoteClarity? {
        guard Config.hasValidOpenAIKey else {
            return generateMockClarity(for: content, language: language)
        }
        
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        let languageContext = languageService.getAIContext(for: analysisLanguage)
        
        let prompt = """
        \(languageContext)
        
        You are an intelligent assistant that helps users make sense of short, spontaneous notes.
        
        Given this messy or incomplete voice note, help clarify its meaning:
        
        Note: "\(content)"
        
        Provide:
        1. A clear interpretation of what the user likely meant
        2. Suggest a category (idea, movie, task, product, person, reminder, etc.)
        3. Suggest helpful next steps
        4. If time-related words are detected, suggest reminder timing
        
        Be helpful, respectful of ambiguity, and non-intrusive.
        
        Respond in JSON format:
        {
            "interpretation": "Clear interpretation of the note",
            "category": "suggested_category",
            "next_steps": ["action1", "action2"],
            "reminder_suggestion": "optional reminder timing",
            "confidence": 0.85
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a smart memory assistant specializing in interpreting fragmentary voice notes."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.3
        ]
        
        do {
            guard let url = URL(string: openAIEndpoint) else { return nil }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let responseContent = message["content"] as? String {
                
                return parseNoteClarity(responseContent, originalContent: content)
            }
            
        } catch {
            print("OpenAI note clarity error: \(error)")
        }
        
        return generateMockClarity(for: content, language: analysisLanguage)
    }
    
    /// Expand a short note into a more complete thought or journal entry
    func expandNote(_ content: String, style: ExpansionStyle = .journal, language: SupportedLanguage? = nil) async -> NoteExpansion? {
        guard Config.hasValidOpenAIKey else {
            return generateMockExpansion(for: content, style: style, language: language)
        }
        
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        let languageContext = languageService.getAIContext(for: analysisLanguage)
        
        let stylePrompt = getExpansionStylePrompt(style, language: analysisLanguage)
        
        let prompt = """
        \(languageContext)
        
        Transform this short, fragmentary note into a more complete and meaningful \(stylePrompt):
        
        Original note: "\(content)"
        
        \(getExpansionInstructions(for: style, language: analysisLanguage))
        
        Respond in JSON format:
        {
            "expanded_text": "The expanded version",
            "expansion_type": "\(style.rawValue)",
            "key_additions": ["what was added1", "what was added2"],
            "confidence": 0.9
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a writing assistant that helps expand brief thoughts into meaningful content."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 400,
            "temperature": 0.4
        ]
        
        do {
            guard let url = URL(string: openAIEndpoint) else { return nil }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let responseContent = message["content"] as? String {
                
                return parseNoteExpansion(responseContent, originalContent: content, style: style)
            }
            
        } catch {
            print("OpenAI note expansion error: \(error)")
        }
        
        return generateMockExpansion(for: content, style: style, language: analysisLanguage)
    }
    
    /// Detect related notes based on entities, topics, or time proximity
    func findRelatedNotes(_ content: String, in notes: [String], language: SupportedLanguage? = nil) async -> [RelatedNote] {
        guard Config.hasValidOpenAIKey else {
            return generateMockRelatedNotes(for: content, in: notes)
        }
        
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        let languageContext = languageService.getAIContext(for: analysisLanguage)
        
        // Limit notes to prevent token overflow
        let limitedNotes = Array(notes.prefix(20))
        let notesText = limitedNotes.enumerated().map { index, note in
            "[\(index)]: \(note)"
        }.joined(separator: "\n")
        
        let prompt = """
        \(languageContext)
        
        Find notes related to this target note by analyzing:
        1. Named entities (people, places, products)
        2. Topic similarity
        3. Conceptual connections
        
        Target note: "\(content)"
        
        Available notes:
        \(notesText)
        
        Respond in JSON format:
        {
            "related_notes": [
                {
                    "index": 0,
                    "relation_type": "same_person",
                    "relation_explanation": "Both mention Claude",
                    "confidence": 0.9
                }
            ]
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "system",
                    "content": "You are an expert at finding connections between notes based on entities, topics, and concepts."
                ],
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 500,
            "temperature": 0.2
        ]
        
        do {
            guard let url = URL(string: openAIEndpoint) else { return [] }
            
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            
            if let response = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = response["choices"] as? [[String: Any]],
               let firstChoice = choices.first,
               let message = firstChoice["message"] as? [String: Any],
               let responseContent = message["content"] as? String {
                
                return parseRelatedNotes(responseContent, notes: limitedNotes)
            }
            
        } catch {
            print("OpenAI related notes error: \(error)")
        }
        
        return generateMockRelatedNotes(for: content, in: limitedNotes)
    }
    
    /// Suggest reminders based on time-related language in the note
    func suggestReminder(_ content: String, language: SupportedLanguage? = nil) async -> ReminderSuggestion? {
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        
        // Use rule-based detection for time phrases
        let timePatterns = getTimePatterns(for: analysisLanguage)
        let lowercaseContent = content.lowercased()
        
        for (pattern, timing) in timePatterns {
            if lowercaseContent.contains(pattern) {
                return ReminderSuggestion(
                    timeReference: pattern,
                    suggestedTiming: timing,
                    confidence: 0.8,
                    originalPhrase: pattern
                )
            }
        }
        
        return nil
    }
    
    // MARK: - Helper Functions
    
    private func parseNoteClarity(_ response: String, originalContent: String) -> NoteClarity? {
        do {
            guard let data = response.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let interpretation = json["interpretation"] as? String ?? originalContent
            let category = json["category"] as? String ?? "general"
            let nextSteps = json["next_steps"] as? [String] ?? []
            let reminderSuggestion = json["reminder_suggestion"] as? String
            let confidence = json["confidence"] as? Double ?? 0.5
            
            return NoteClarity(
                originalContent: originalContent,
                interpretation: interpretation,
                suggestedCategory: category,
                nextSteps: nextSteps,
                reminderSuggestion: reminderSuggestion,
                confidence: confidence
            )
            
        } catch {
            print("Failed to parse note clarity response: \(error)")
            return nil
        }
    }
    
    private func parseNoteExpansion(_ response: String, originalContent: String, style: ExpansionStyle) -> NoteExpansion? {
        do {
            guard let data = response.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            
            let expandedText = json["expanded_text"] as? String ?? originalContent
            let keyAdditions = json["key_additions"] as? [String] ?? []
            let confidence = json["confidence"] as? Double ?? 0.5
            
            return NoteExpansion(
                originalContent: originalContent,
                expandedText: expandedText,
                expansionStyle: style,
                keyAdditions: keyAdditions,
                confidence: confidence
            )
            
        } catch {
            print("Failed to parse note expansion response: \(error)")
            return nil
        }
    }
    
    private func parseRelatedNotes(_ response: String, notes: [String]) -> [RelatedNote] {
        do {
            guard let data = response.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let relatedArray = json["related_notes"] as? [[String: Any]] else {
                return []
            }
            
            var relatedNotes: [RelatedNote] = []
            
            for item in relatedArray {
                if let index = item["index"] as? Int,
                   index < notes.count,
                   let relationType = item["relation_type"] as? String,
                   let explanation = item["relation_explanation"] as? String {
                    
                    let confidence = item["confidence"] as? Double ?? 0.5
                    
                    relatedNotes.append(RelatedNote(
                        content: notes[index],
                        relationType: relationType,
                        explanation: explanation,
                        confidence: confidence
                    ))
                }
            }
            
            return relatedNotes
            
        } catch {
            print("Failed to parse related notes response: \(error)")
            return []
        }
    }
    
    // MARK: - Mock Implementations (Fallbacks)
    
    private func generateMockClarity(for content: String, language: SupportedLanguage?) -> NoteClarity {
        let lang = language ?? .english
        let category = detectCategory(content, language: lang)
        let steps = generateMockNextSteps(for: category, language: lang)
        
        return NoteClarity(
            originalContent: content,
            interpretation: getInterpretationTemplate(for: content, language: lang),
            suggestedCategory: category,
            nextSteps: steps,
            reminderSuggestion: detectReminderFromContent(content, language: lang),
            confidence: 0.7
        )
    }
    
    private func generateMockExpansion(for content: String, style: ExpansionStyle, language: SupportedLanguage?) -> NoteExpansion {
        let lang = language ?? .english
        let expanded = generateExpandedContent(content, style: style, language: lang)
        
        return NoteExpansion(
            originalContent: content,
            expandedText: expanded,
            expansionStyle: style,
            keyAdditions: ["More context", "Better structure"],
            confidence: 0.6
        )
    }
    
    private func generateMockRelatedNotes(for content: String, in notes: [String]) -> [RelatedNote] {
        let keywords = extractKeywords(from: content)
        var related: [RelatedNote] = []
        
        for note in notes {
            if note != content && keywords.contains(where: { note.lowercased().contains($0.lowercased()) }) {
                related.append(RelatedNote(
                    content: note,
                    relationType: "keyword_match",
                    explanation: "Contains similar keywords",
                    confidence: 0.6
                ))
            }
        }
        
        return Array(related.prefix(5))
    }
    
    // MARK: - Language-specific Helper Functions
    
    private func getTimePatterns(for language: SupportedLanguage) -> [String: String] {
        switch language {
        case .english:
            return [
                "tonight": "Today at 8:00 PM",
                "tomorrow": "Tomorrow at 9:00 AM",
                "next week": "Next Monday at 9:00 AM",
                "later": "In 2 hours",
                "morning": "Tomorrow at 9:00 AM",
                "friday": "This Friday at 9:00 AM"
            ]
        case .turkish:
            return [
                "bu akşam": "Bugün saat 20:00",
                "yarın": "Yarın saat 09:00",
                "gelecek hafta": "Gelecek Pazartesi saat 09:00",
                "sonra": "2 saat sonra",
                "sabah": "Yarın sabah 09:00",
                "cuma": "Bu Cuma saat 09:00"
            ]
        case .spanish:
            return [
                "esta noche": "Hoy a las 20:00",
                "mañana": "Mañana a las 09:00",
                "próxima semana": "Próximo lunes a las 09:00",
                "más tarde": "En 2 horas",
                "mañana": "Mañana a las 09:00"
            ]
        default:
            return [
                "tonight": "Today at 8:00 PM",
                "tomorrow": "Tomorrow at 9:00 AM",
                "later": "In 2 hours"
            ]
        }
    }
    
    private func getExpansionStylePrompt(_ style: ExpansionStyle, language: SupportedLanguage) -> String {
        switch (style, language) {
        case (.journal, .english): return "journal entry"
        case (.task, .english): return "actionable task"
        case (.idea, .english): return "developed idea"
        case (.journal, .turkish): return "günlük girişi"
        case (.task, .turkish): return "yapılacak görev"
        case (.idea, .turkish): return "geliştirilmiş fikir"
        default: return "structured note"
        }
    }
    
    private func getExpansionInstructions(for style: ExpansionStyle, language: SupportedLanguage) -> String {
        switch (style, language) {
        case (.journal, .english):
            return "Expand this into a personal journal entry with context, emotions, and reflection."
        case (.task, .english):
            return "Turn this into a clear, actionable task with steps and deadlines."
        case (.idea, .english):
            return "Develop this into a complete idea with background, details, and potential next steps."
        case (.journal, .turkish):
            return "Bunu kişisel bir günlük girişine dönüştürün, bağlam, duygular ve düşünceler ekleyin."
        case (.task, .turkish):
            return "Bunu net, uygulanabilir bir göreve dönüştürün, adımlar ve son tarihler ekleyin."
        case (.idea, .turkish):
            return "Bunu tam bir fikre geliştirin, arka plan, detaylar ve potansiyel sonraki adımlar ekleyin."
        default:
            return "Expand and structure this note with more detail and context."
        }
    }
    
    private func detectCategory(_ content: String, language: SupportedLanguage) -> String {
        let lowercaseContent = content.lowercased()
        
        // Use existing AIService category detection
        let keywords = getKeywordMappings(for: language)
        
        for (category, keywordList) in keywords {
            if keywordList.contains(where: { lowercaseContent.contains($0) }) {
                return category
            }
        }
        
        return "general"
    }
    
    private func getKeywordMappings(for language: SupportedLanguage) -> [String: [String]] {
        // Reuse the existing AIService keyword mappings
        switch language {
        case .english:
            return [
                "meeting": ["meeting", "call", "conference"],
                "idea": ["idea", "think", "concept"],
                "task": ["todo", "task", "do", "need to"],
                "reminder": ["remember", "remind", "don't forget"],
                "shopping": ["buy", "purchase", "shop"],
                "movie": ["movie", "film", "watch"],
                "person": ["call", "contact", "meet"],
                "location": ["go to", "visit", "at"]
            ]
        case .turkish:
            return [
                "meeting": ["toplantı", "arama", "konferans"],
                "idea": ["fikir", "düşünmek", "konsept"],
                "task": ["yapılacak", "görev", "yapmak"],
                "reminder": ["hatırlamak", "hatırlatma", "unutma"],
                "shopping": ["satın almak", "alışveriş", "mağaza"],
                "movie": ["film", "izlemek", "sinema"],
                "person": ["aramak", "iletişim", "buluşmak"],
                "location": ["gitmek", "ziyaret", "de", "da"]
            ]
        default:
            return [
                "meeting": ["meeting", "call"],
                "idea": ["idea", "think"],
                "task": ["todo", "task"],
                "reminder": ["remember", "remind"],
                "shopping": ["buy", "purchase"]
            ]
        }
    }
    
    private func generateMockNextSteps(for category: String, language: SupportedLanguage) -> [String] {
        switch (category, language) {
        case ("meeting", .english): return ["Schedule the meeting", "Prepare agenda"]
        case ("idea", .english): return ["Expand this idea", "Research similar concepts"]
        case ("task", .english): return ["Set a deadline", "Break into smaller steps"]
        case ("reminder", .english): return ["Set a reminder", "Add to calendar"]
        case ("meeting", .turkish): return ["Toplantıyı planla", "Ajanda hazırla"]
        case ("idea", .turkish): return ["Fikri geliştir", "Benzer konseptleri araştır"]
        case ("task", .turkish): return ["Son tarih belirle", "Küçük adımlara böl"]
        default: return ["Review later", "Add more detail"]
        }
    }
    
    private func getInterpretationTemplate(for content: String, language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return "You mentioned: \(content). This seems to be about \(detectCategory(content, language: language))."
        case .turkish:
            return "Şunu söylediniz: \(content). Bu \(detectCategory(content, language: language)) hakkında görünüyor."
        default:
            return "You mentioned: \(content)."
        }
    }
    
    private func detectReminderFromContent(_ content: String, language: SupportedLanguage) -> String? {
        let timePatterns = getTimePatterns(for: language)
        let lowercaseContent = content.lowercased()
        
        for (pattern, timing) in timePatterns {
            if lowercaseContent.contains(pattern) {
                return timing
            }
        }
        
        return nil
    }
    
    private func generateExpandedContent(_ content: String, style: ExpansionStyle, language: SupportedLanguage) -> String {
        switch (style, language) {
        case (.journal, .english):
            return "Today I had a thought about \(content). This is worth exploring further as it could lead to interesting insights."
        case (.task, .english):
            return "Task: \(content)\nSteps:\n1. Plan the approach\n2. Execute the task\n3. Review results"
        case (.idea, .english):
            return "Idea: \(content)\n\nThis concept has potential because it addresses a real need. Next steps would be to research similar ideas and develop a more detailed plan."
        case (.journal, .turkish):
            return "Bugün \(content) hakkında bir düşüncem oldu. Bu daha derinlemesine keşfetmeye değer çünkü ilginç içgörülere yol açabilir."
        case (.task, .turkish):
            return "Görev: \(content)\nAdımlar:\n1. Yaklaşımı planla\n2. Görevi gerçekleştir\n3. Sonuçları gözden geçir"
        default:
            return "\(content)\n\n[Expanded with more context and structure]"
        }
    }
    
    private func extractKeywords(from content: String) -> [String] {
        let words = content.split(separator: " ").map(String.init)
        return words.filter { word in
            word.count > 3 && !["this", "that", "with", "have", "will", "been", "from", "they", "were", "said", "each", "which", "their", "time", "would", "there", "could", "other"].contains(word.lowercased())
        }
    }
}

// MARK: - Data Models

struct NoteClarity {
    let originalContent: String
    let interpretation: String
    let suggestedCategory: String
    let nextSteps: [String]
    let reminderSuggestion: String?
    let confidence: Double
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

struct NoteExpansion {
    let originalContent: String
    let expandedText: String
    let expansionStyle: ExpansionStyle
    let keyAdditions: [String]
    let confidence: Double
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

struct RelatedNote: Identifiable {
    let id = UUID()
    let content: String
    let relationType: String
    let explanation: String
    let confidence: Double
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

struct ReminderSuggestion {
    let timeReference: String
    let suggestedTiming: String
    let confidence: Double
    let originalPhrase: String
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

enum ExpansionStyle: String, CaseIterable {
    case journal = "journal"
    case task = "task"
    case idea = "idea"
    
    var displayName: String {
        switch self {
        case .journal: return "Journal Entry"
        case .task: return "Action Items"
        case .idea: return "Developed Idea"
        }
    }
}
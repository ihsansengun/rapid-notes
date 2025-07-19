import Foundation

@MainActor
class AIService: ObservableObject {
    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    private let languageService = LanguageService.shared
    private let languageDetector = LanguageDetector.shared
    
    func analyzeNote(_ content: String, language: SupportedLanguage? = nil) async -> (tags: [String], summary: String) {
        // Determine the language to use for analysis
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        
        // Try OpenAI API first, fallback to mock if it fails
        if let result = await callOpenAIAPI(content: content, language: analysisLanguage) {
            return result
        } else {
            // Fallback to mock implementation
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let mockTags = self.generateMockTags(for: content, language: analysisLanguage)
                    let mockSummary = self.generateMockSummary(for: content, language: analysisLanguage)
                    continuation.resume(returning: (tags: mockTags, summary: mockSummary))
                }
            }
        }
    }
    
    private func callOpenAIAPI(content: String, language: SupportedLanguage) async -> (tags: [String], summary: String)? {
        // Skip API call if no API key is configured
        guard Config.hasValidOpenAIKey else {
            return nil
        }
        
        let languageContext = languageService.getAIContext(for: language)
        let tagCategories = getLocalizedTagCategories(for: language)
        
        let prompt = """
        \(languageContext)
        
        Analyze this note and provide:
        1. Up to 3 relevant tags from these categories: \(tagCategories.joined(separator: ", "))
        2. A brief 1-sentence summary
        
        Note: "\(content)"
        
        Respond in JSON format:
        {
            "tags": ["tag1", "tag2"],
            "summary": "Brief summary here"
        }
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 150,
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
               let content = message["content"] as? String {
                
                return parseOpenAIResponse(content)
            }
            
        } catch {
            print("OpenAI API error: \(error)")
        }
        
        return nil
    }
    
    private func parseOpenAIResponse(_ content: String) -> (tags: [String], summary: String)? {
        do {
            guard let data = content.data(using: .utf8),
                  let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tags = json["tags"] as? [String],
                  let summary = json["summary"] as? String else {
                return nil
            }
            
            return (tags: tags, summary: summary)
        } catch {
            print("Failed to parse OpenAI response: \(error)")
            return nil
        }
    }
    
    private func getLocalizedTagCategories(for language: SupportedLanguage) -> [String] {
        switch language {
        case .english:
            return ["meeting", "idea", "todo", "reminder", "shopping", "work", "personal", "health", "travel", "finance", "general"]
        case .spanish:
            return ["reunión", "idea", "tarea", "recordatorio", "compras", "trabajo", "personal", "salud", "viaje", "finanzas", "general"]
        case .french:
            return ["réunion", "idée", "tâche", "rappel", "shopping", "travail", "personnel", "santé", "voyage", "finance", "général"]
        case .german:
            return ["meeting", "idee", "aufgabe", "erinnerung", "einkaufen", "arbeit", "persönlich", "gesundheit", "reise", "finanzen", "allgemein"]
        case .italian:
            return ["riunione", "idea", "compito", "promemoria", "shopping", "lavoro", "personale", "salute", "viaggio", "finanza", "generale"]
        case .portuguese:
            return ["reunião", "ideia", "tarefa", "lembrete", "compras", "trabalho", "pessoal", "saúde", "viagem", "finanças", "geral"]
        case .japanese:
            return ["会議", "アイデア", "タスク", "リマインダー", "買い物", "仕事", "個人", "健康", "旅行", "金融", "一般"]
        case .chinese:
            return ["会议", "想法", "任务", "提醒", "购物", "工作", "个人", "健康", "旅行", "金融", "一般"]
        case .korean:
            return ["회의", "아이디어", "할일", "알림", "쇼핑", "업무", "개인", "건강", "여행", "금융", "일반"]
        case .russian:
            return ["встреча", "идея", "задача", "напоминание", "покупки", "работа", "личное", "здоровье", "путешествие", "финансы", "общее"]
        case .turkish:
            return ["toplantı", "fikir", "yapılacak", "hatırlatma", "alışveriş", "iş", "kişisel", "sağlık", "seyahat", "finans", "genel"]
        }
    }
    
    private func generateMockTags(for content: String, language: SupportedLanguage) -> [String] {
        let lowercaseContent = content.lowercased()
        var tags: [String] = []
        let tagCategories = getLocalizedTagCategories(for: language)
        
        // Use language-specific keywords for tag detection
        let keywords = getKeywordMappings(for: language)
        
        for (category, keywordList) in keywords {
            if keywordList.contains(where: { lowercaseContent.contains($0) }) {
                if let localizedTag = tagCategories.first(where: { mapToEnglishCategory($0, language: language) == category }) {
                    tags.append(localizedTag)
                }
            }
        }
        
        if tags.isEmpty {
            tags.append(tagCategories.last ?? "general")
        }
        
        return Array(tags.prefix(3))
    }
    
    private func getKeywordMappings(for language: SupportedLanguage) -> [String: [String]] {
        switch language {
        case .english:
            return [
                "meeting": ["meeting", "call", "conference"],
                "idea": ["idea", "think", "concept"],
                "todo": ["todo", "task", "do"],
                "reminder": ["remember", "remind", "don't forget"],
                "shopping": ["buy", "purchase", "shop"]
            ]
        case .spanish:
            return [
                "meeting": ["reunión", "llamada", "conferencia"],
                "idea": ["idea", "pensar", "concepto"],
                "todo": ["tarea", "hacer", "pendiente"],
                "reminder": ["recordar", "recordatorio", "no olvidar"],
                "shopping": ["comprar", "compra", "tienda"]
            ]
        case .french:
            return [
                "meeting": ["réunion", "appel", "conférence"],
                "idea": ["idée", "penser", "concept"],
                "todo": ["tâche", "faire", "à faire"],
                "reminder": ["rappeler", "rappel", "ne pas oublier"],
                "shopping": ["acheter", "achat", "magasin"]
            ]
        case .turkish:
            return [
                "meeting": ["toplantı", "arama", "konferans"],
                "idea": ["fikir", "düşünmek", "konsept"],
                "todo": ["yapılacak", "görev", "yapmak"],
                "reminder": ["hatırlamak", "hatırlatma", "unutma"],
                "shopping": ["satın almak", "alışveriş", "mağaza"]
            ]
        default:
            return [
                "meeting": ["meeting", "call"],
                "idea": ["idea", "think"],
                "todo": ["todo", "task"],
                "reminder": ["remember", "remind"],
                "shopping": ["buy", "purchase"]
            ]
        }
    }
    
    private func mapToEnglishCategory(_ localizedTag: String, language: SupportedLanguage) -> String {
        let categories = getLocalizedTagCategories(for: language)
        let englishCategories = getLocalizedTagCategories(for: .english)
        
        guard let index = categories.firstIndex(of: localizedTag) else { return "general" }
        return englishCategories[index]
    }
    
    private func generateMockSummary(for content: String, language: SupportedLanguage) -> String {
        let wordCount = content.split(separator: " ").count
        let keywords = extractKeywords(from: content)
        
        switch language {
        case .english:
            if wordCount <= 10 {
                return "Short note"
            } else if wordCount <= 30 {
                return "Medium-length note about \(keywords)"
            } else {
                return "Detailed note covering \(keywords)"
            }
        case .spanish:
            if wordCount <= 10 {
                return "Nota corta"
            } else if wordCount <= 30 {
                return "Nota de longitud media sobre \(keywords)"
            } else {
                return "Nota detallada que cubre \(keywords)"
            }
        case .french:
            if wordCount <= 10 {
                return "Note courte"
            } else if wordCount <= 30 {
                return "Note de longueur moyenne à propos de \(keywords)"
            } else {
                return "Note détaillée couvrant \(keywords)"
            }
        case .german:
            if wordCount <= 10 {
                return "Kurze Notiz"
            } else if wordCount <= 30 {
                return "Mittellange Notiz über \(keywords)"
            } else {
                return "Detaillierte Notiz zu \(keywords)"
            }
        case .italian:
            if wordCount <= 10 {
                return "Nota breve"
            } else if wordCount <= 30 {
                return "Nota di media lunghezza su \(keywords)"
            } else {
                return "Nota dettagliata che copre \(keywords)"
            }
        case .portuguese:
            if wordCount <= 10 {
                return "Nota curta"
            } else if wordCount <= 30 {
                return "Nota de comprimento médio sobre \(keywords)"
            } else {
                return "Nota detalhada cobrindo \(keywords)"
            }
        case .japanese:
            if wordCount <= 10 {
                return "短いメモ"
            } else if wordCount <= 30 {
                return "\(keywords)についての中程度のメモ"
            } else {
                return "\(keywords)を詳しく説明するメモ"
            }
        case .chinese:
            if wordCount <= 10 {
                return "简短笔记"
            } else if wordCount <= 30 {
                return "关于\(keywords)的中等长度笔记"
            } else {
                return "详细的笔记涵盖\(keywords)"
            }
        case .korean:
            if wordCount <= 10 {
                return "짧은 메모"
            } else if wordCount <= 30 {
                return "\(keywords)에 대한 중간 길이 메모"
            } else {
                return "\(keywords)를 다루는 자세한 메모"
            }
        case .russian:
            if wordCount <= 10 {
                return "Короткая заметка"
            } else if wordCount <= 30 {
                return "Заметка средней длины о \(keywords)"
            } else {
                return "Подробная заметка, охватывающая \(keywords)"
            }
        case .turkish:
            if wordCount <= 10 {
                return "Kısa not"
            } else if wordCount <= 30 {
                return "\(keywords) hakkında orta uzunlukta not"
            } else {
                return "\(keywords) konusunu ele alan ayrıntılı not"
            }
        }
    }
    
    private func extractKeywords(from content: String) -> String {
        let words = content.split(separator: " ").map(String.init)
        let meaningfulWords = words.filter { word in
            word.count > 3 && !["this", "that", "with", "have", "will", "been", "from", "they", "were", "said", "each", "which", "their", "time", "would", "there", "could", "other"].contains(word.lowercased())
        }
        
        return meaningfulWords.prefix(3).joined(separator: ", ")
    }
    
    /// Analyze note with language detection and confidence scoring
    func analyzeNoteWithLanguageDetection(_ content: String) async -> (tags: [String], summary: String, detectedLanguage: SupportedLanguage?, confidence: Double) {
        let (detectedLang, confidence) = languageDetector.detectLanguageWithConfidence(from: content)
        let (tags, summary) = await analyzeNote(content, language: detectedLang)
        
        return (tags, summary, detectedLang, confidence)
    }
    
    /// Improve transcription using AI (language-aware)
    func improveTranscription(_ transcription: String, language: SupportedLanguage) async -> String? {
        guard Config.hasValidOpenAIKey else { return nil }
        
        let languageContext = languageService.getAIContext(for: language)
        
        let prompt = """
        \(languageContext)
        
        Improve this voice transcription by:
        1. Fixing any obvious speech recognition errors
        2. Correcting proper names and technical terms
        3. Improving punctuation and capitalization
        4. Maintaining the original meaning and tone
        
        Original transcription: "\(transcription)"
        
        Return only the improved text without explanations.
        """
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                [
                    "role": "user",
                    "content": prompt
                ]
            ],
            "max_tokens": 300,
            "temperature": 0.2
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
               let content = message["content"] as? String {
                
                return content.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
        } catch {
            print("OpenAI transcription improvement error: \(error)")
        }
        
        return nil
    }
    
    /// Get language-specific suggestions for better note organization
    func getOrganizationSuggestions(for content: String, language: SupportedLanguage) async -> [String] {
        guard Config.hasValidOpenAIKey else {
            return getDefaultOrganizationSuggestions(for: language)
        }
        
        let languageContext = languageService.getAIContext(for: language)
        
        let prompt = """
        \(languageContext)
        
        Suggest 3 ways to better organize or expand this note:
        
        Note: "\(content)"
        
        Provide suggestions as a JSON array of strings:
        ["suggestion1", "suggestion2", "suggestion3"]
        """
        
        // Implementation similar to other OpenAI calls...
        return getDefaultOrganizationSuggestions(for: language)
    }
    
    private func getDefaultOrganizationSuggestions(for language: SupportedLanguage) -> [String] {
        switch language {
        case .english:
            return ["Add more context", "Include action items", "Set a reminder"]
        case .spanish:
            return ["Añadir más contexto", "Incluir elementos de acción", "Establecer un recordatorio"]
        case .french:
            return ["Ajouter plus de contexte", "Inclure des éléments d'action", "Définir un rappel"]
        default:
            return ["Add more context", "Include action items", "Set a reminder"]
        }
    }
    
    /// Debug AI service with language information
    func debugAIAnalysis(for content: String) async {
        print("=== AI Analysis Debug ===")
        print("Content length: \(content.count) characters")
        
        let (detectedLang, confidence) = languageDetector.detectLanguageWithConfidence(from: content)
        print("Detected language: \(detectedLang?.displayName ?? "Unknown") (confidence: \(String(format: "%.2f", confidence)))")
        print("Current service language: \(languageService.currentLanguage.displayName)")
        
        let (tags, summary, _, _) = await analyzeNoteWithLanguageDetection(content)
        print("Generated tags: \(tags)")
        print("Generated summary: \(summary)")
        
        if let detected = detectedLang {
            let tagCategories = getLocalizedTagCategories(for: detected)
            print("Available tag categories for \(detected.displayName): \(tagCategories)")
        }
        
        print("OpenAI API available: \(Config.hasValidOpenAIKey)")
        print("========================")
    }
}
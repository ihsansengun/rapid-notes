import Foundation

/// Service for automatic categorization of notes based on content analysis
@MainActor
class CategoryService: ObservableObject {
    static let shared = CategoryService()
    
    private let aiMemoryService = AIMemoryService()
    private let languageService = LanguageService.shared
    private let languageDetector = LanguageDetector.shared
    
    // Category statistics for better predictions
    @Published var categoryStats: [String: Int] = [:]
    @Published var recentCategories: [String] = []
    
    private init() {
        loadCategoryStats()
    }
    
    // MARK: - Auto-Categorization
    
    /// Automatically categorize a note based on its content
    func categorizeNote(_ content: String, language: SupportedLanguage? = nil) async -> CategoryResult {
        let analysisLanguage = language ?? languageDetector.detectLanguage(from: content) ?? languageService.currentLanguage
        
        // Use AI service for classification if available
        if Config.hasValidOpenAIKey {
            let clarity = await aiMemoryService.clarifyNote(content, language: analysisLanguage)
            if let clarity = clarity, clarity.confidence >= 0.6 {
                let result = CategoryResult(
                    category: clarity.suggestedCategory,
                    confidence: clarity.confidence,
                    method: .aiClassification,
                    language: analysisLanguage
                )
                
                // Update statistics
                updateCategoryStats(clarity.suggestedCategory)
                
                return result
            }
        }
        
        // Fallback to rule-based classification
        return classifyWithRules(content, language: analysisLanguage)
    }
    
    /// Batch categorize multiple notes
    func categorizeNotes(_ notes: [Note]) async {
        for note in notes {
            guard let content = note.content,
                  !content.isEmpty,
                  note.aiCategory == nil else { continue }
            
            let result = await categorizeNote(content, language: note.supportedLanguage)
            
            note.aiCategory = result.category
            note.aiConfidence = result.confidence
            
            // Save individual note updates
            do {
                try note.managedObjectContext?.save()
            } catch {
                print("Error saving note category: \(error)")
            }
        }
    }
    
    /// Suggest category based on partial input
    func suggestCategory(for partialContent: String, language: SupportedLanguage? = nil) -> [CategorySuggestion] {
        let analysisLanguage = language ?? languageService.currentLanguage
        let lowercaseContent = partialContent.lowercased()
        
        var suggestions: [CategorySuggestion] = []
        let keywordMappings = getKeywordMappings(for: analysisLanguage)
        
        // Check each category for matches
        for (category, keywords) in keywordMappings {
            var matchScore = 0.0
            var matchedKeywords: [String] = []
            
            for keyword in keywords {
                if lowercaseContent.contains(keyword) {
                    matchScore += 1.0
                    matchedKeywords.append(keyword)
                }
            }
            
            if matchScore > 0 {
                let confidence = min(matchScore / Double(keywords.count), 1.0)
                suggestions.append(CategorySuggestion(
                    category: category,
                    confidence: confidence,
                    matchedKeywords: matchedKeywords,
                    displayName: LocalizedCategory.getDisplayName(for: category, language: analysisLanguage),
                    icon: LocalizedCategory.getIcon(for: category)
                ))
            }
        }
        
        // Add frequent categories as suggestions
        let frequentCategories = getMostFrequentCategories(limit: 3)
        for category in frequentCategories {
            if !suggestions.contains(where: { $0.category == category }) {
                suggestions.append(CategorySuggestion(
                    category: category,
                    confidence: 0.3,
                    matchedKeywords: [],
                    displayName: LocalizedCategory.getDisplayName(for: category, language: analysisLanguage),
                    icon: LocalizedCategory.getIcon(for: category)
                ))
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    // MARK: - Category Management
    
    /// Get all available categories for a language
    func getAllCategories(for language: SupportedLanguage) -> [CategoryInfo] {
        let categories = LocalizedCategory.getAllCategories(for: language)
        
        return categories.map { key, displayName in
            CategoryInfo(
                key: key,
                displayName: displayName,
                icon: LocalizedCategory.getIcon(for: key),
                count: categoryStats[key] ?? 0
            )
        }.sorted { $0.displayName < $1.displayName }
    }
    
    /// Get most frequently used categories
    func getMostFrequentCategories(limit: Int = 5) -> [String] {
        return categoryStats
            .sorted { $0.value > $1.value }
            .prefix(limit)
            .map { $0.key }
    }
    
    /// Get category usage statistics
    func getCategoryStatistics() -> [String: Int] {
        return categoryStats
    }
    
    /// Reset category statistics
    func resetCategoryStats() {
        categoryStats.removeAll()
        recentCategories.removeAll()
        saveCategoryStats()
    }
    
    // MARK: - Rule-based Classification
    
    private func classifyWithRules(_ content: String, language: SupportedLanguage) -> CategoryResult {
        let lowercaseContent = content.lowercased()
        let keywordMappings = getKeywordMappings(for: language)
        
        var bestMatch: (category: String, score: Double) = ("general", 0.0)
        
        for (category, keywords) in keywordMappings {
            var score = 0.0
            
            for keyword in keywords {
                if lowercaseContent.contains(keyword) {
                    score += 1.0
                }
                
                // Boost score for exact word matches
                let words = lowercaseContent.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                if words.contains(keyword) {
                    score += 0.5
                }
            }
            
            // Normalize score by keyword count
            score = score / Double(keywords.count)
            
            if score > bestMatch.score {
                bestMatch = (category, score)
            }
        }
        
        // Apply frequency boost for commonly used categories
        if let frequentBoost = getFrequencyBoost(for: bestMatch.category) {
            bestMatch.score += frequentBoost
        }
        
        let confidence = min(bestMatch.score, 1.0)
        updateCategoryStats(bestMatch.category)
        
        return CategoryResult(
            category: bestMatch.category,
            confidence: confidence,
            method: .ruleBasedClassification,
            language: language
        )
    }
    
    private func getKeywordMappings(for language: SupportedLanguage) -> [String: [String]] {
        switch language {
        case .english:
            return [
                "meeting": ["meeting", "call", "conference", "zoom", "teams", "discuss", "agenda"],
                "idea": ["idea", "think", "concept", "brainstorm", "inspiration", "thought"],
                "task": ["todo", "task", "do", "need to", "must", "should", "complete", "finish"],
                "reminder": ["remember", "remind", "don't forget", "note to self", "remind me"],
                "shopping": ["buy", "purchase", "shop", "store", "mall", "order", "groceries"],
                "movie": ["movie", "film", "watch", "cinema", "netflix", "show", "series"],
                "person": ["call", "contact", "meet", "person", "friend", "colleague", "family"],
                "location": ["go to", "visit", "at", "place", "location", "address", "directions"],
                "work": ["work", "office", "project", "client", "deadline", "meeting", "email"],
                "personal": ["personal", "private", "me", "myself", "family", "relationship"],
                "health": ["doctor", "appointment", "medicine", "health", "exercise", "gym"],
                "travel": ["travel", "trip", "flight", "hotel", "vacation", "visit", "journey"],
                "finance": ["money", "pay", "bill", "bank", "budget", "investment", "expense"]
            ]
        case .turkish:
            return [
                "meeting": ["toplantı", "arama", "konferans", "zoom", "görüşme", "randevu"],
                "idea": ["fikir", "düşünce", "konsept", "beyin fırtınası", "ilham"],
                "task": ["yapılacak", "görev", "yapmak", "tamamlamak", "bitirmek", "gerekli"],
                "reminder": ["hatırlamak", "hatırlatma", "unutma", "kendime not"],
                "shopping": ["satın almak", "alışveriş", "mağaza", "sipariş", "market"],
                "movie": ["film", "izlemek", "sinema", "netflix", "dizi", "program"],
                "person": ["aramak", "kişi", "arkadaş", "meslektaş", "aile", "buluşmak"],
                "location": ["gitmek", "ziyaret", "yer", "konum", "adres", "yön"],
                "work": ["iş", "ofis", "proje", "müşteri", "son tarih", "toplantı"],
                "personal": ["kişisel", "özel", "ben", "aile", "ilişki"],
                "health": ["doktor", "randevu", "ilaç", "sağlık", "egzersiz", "spor"],
                "travel": ["seyahat", "yolculuk", "uçak", "otel", "tatil", "ziyaret"],
                "finance": ["para", "ödemek", "fatura", "banka", "bütçe", "gider"]
            ]
        case .spanish:
            return [
                "meeting": ["reunión", "llamada", "conferencia", "zoom", "discutir"],
                "idea": ["idea", "pensar", "concepto", "lluvia de ideas", "inspiración"],
                "task": ["tarea", "hacer", "completar", "terminar", "pendiente"],
                "reminder": ["recordar", "recordatorio", "no olvidar"],
                "shopping": ["comprar", "compra", "tienda", "pedido", "supermercado"],
                "movie": ["película", "ver", "cine", "netflix", "serie"],
                "person": ["llamar", "persona", "amigo", "colega", "familia"],
                "location": ["ir a", "visitar", "lugar", "ubicación", "dirección"],
                "work": ["trabajo", "oficina", "proyecto", "cliente", "fecha límite"],
                "personal": ["personal", "privado", "familia", "relación"],
                "health": ["doctor", "cita", "medicina", "salud", "ejercicio"],
                "travel": ["viajar", "viaje", "vuelo", "hotel", "vacaciones"],
                "finance": ["dinero", "pagar", "factura", "banco", "presupuesto"]
            ]
        default:
            return [
                "meeting": ["meeting", "call"],
                "idea": ["idea", "think"],
                "task": ["todo", "task"],
                "reminder": ["remember", "remind"],
                "shopping": ["buy", "purchase"],
                "general": ["note", "thought"]
            ]
        }
    }
    
    // MARK: - Statistics Management
    
    private func updateCategoryStats(_ category: String) {
        categoryStats[category, default: 0] += 1
        
        // Update recent categories
        recentCategories.removeAll { $0 == category }
        recentCategories.insert(category, at: 0)
        if recentCategories.count > 10 {
            recentCategories.removeLast()
        }
        
        saveCategoryStats()
    }
    
    private func getFrequencyBoost(for category: String) -> Double? {
        let count = categoryStats[category] ?? 0
        let totalNotes = categoryStats.values.reduce(0, +)
        
        if totalNotes > 0 {
            let frequency = Double(count) / Double(totalNotes)
            return frequency * 0.1 // Small boost based on usage frequency
        }
        
        return nil
    }
    
    private func loadCategoryStats() {
        if let data = UserDefaults.standard.data(forKey: "categoryStats"),
           let stats = try? JSONDecoder().decode([String: Int].self, from: data) {
            categoryStats = stats
        }
        
        recentCategories = UserDefaults.standard.stringArray(forKey: "recentCategories") ?? []
    }
    
    private func saveCategoryStats() {
        if let data = try? JSONEncoder().encode(categoryStats) {
            UserDefaults.standard.set(data, forKey: "categoryStats")
        }
        
        UserDefaults.standard.set(recentCategories, forKey: "recentCategories")
    }
}

// MARK: - Data Models

struct CategoryResult {
    let category: String
    let confidence: Double
    let method: ClassificationMethod
    let language: SupportedLanguage
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
}

struct CategorySuggestion {
    let category: String
    let confidence: Double
    let matchedKeywords: [String]
    let displayName: String
    let icon: String
    
    var isRelevant: Bool {
        return confidence >= 0.3
    }
}

struct CategoryInfo {
    let key: String
    let displayName: String
    let icon: String
    let count: Int
}

enum ClassificationMethod {
    case aiClassification
    case ruleBasedClassification
    case userManual
    
    var displayName: String {
        switch self {
        case .aiClassification: return "AI"
        case .ruleBasedClassification: return "Rule-based"
        case .userManual: return "Manual"
        }
    }
}
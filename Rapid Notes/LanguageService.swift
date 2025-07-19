import Foundation
import Speech

/// Supported languages for speech recognition and AI processing
enum SupportedLanguage: String, CaseIterable, Identifiable {
    case english = "en-US"
    case spanish = "es-ES"
    case french = "fr-FR"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case japanese = "ja-JP"
    case chinese = "zh-CN"
    case korean = "ko-KR"
    case russian = "ru-RU"
    case turkish = "tr-TR"
    
    var id: String { rawValue }
    
    /// Human-readable display name
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .italian: return "Italiano"
        case .portuguese: return "Português"
        case .japanese: return "日本語"
        case .chinese: return "中文"
        case .korean: return "한국어"
        case .russian: return "Русский"
        case .turkish: return "Türkçe"
        }
    }
    
    /// Flag emoji for the language
    var flag: String {
        switch self {
        case .english: return "🇺🇸"
        case .spanish: return "🇪🇸"
        case .french: return "🇫🇷"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .japanese: return "🇯🇵"
        case .chinese: return "🇨🇳"
        case .korean: return "🇰🇷"
        case .russian: return "🇷🇺"
        case .turkish: return "🇹🇷"
        }
    }
    
    /// Short language code for API calls
    var languageCode: String {
        switch self {
        case .english: return "en"
        case .spanish: return "es"
        case .french: return "fr"
        case .german: return "de"
        case .italian: return "it"
        case .portuguese: return "pt"
        case .japanese: return "ja"
        case .chinese: return "zh"
        case .korean: return "ko"
        case .russian: return "ru"
        case .turkish: return "tr"
        }
    }
    
    /// Locale for speech recognition
    var locale: Locale {
        return Locale(identifier: rawValue)
    }
    
    /// Check if this language is supported by SFSpeechRecognizer
    var isSpeechRecognitionSupported: Bool {
        return SFSpeechRecognizer.supportedLocales().contains(locale)
    }
}

/// Service for managing language preferences and speech recognizer instances
class LanguageService: ObservableObject {
    static let shared = LanguageService()
    
    @Published var currentLanguage: SupportedLanguage {
        didSet {
            saveLanguagePreference()
        }
    }
    
    @Published var autoDetectLanguage: Bool {
        didSet {
            UserDefaults.standard.set(autoDetectLanguage, forKey: "autoDetectLanguage")
        }
    }
    
    private var speechRecognizers: [SupportedLanguage: SFSpeechRecognizer] = [:]
    private let userDefaults = UserDefaults.standard
    
    init() {
        // Load saved language preference or default to device language
        if let savedLanguageCode = userDefaults.string(forKey: "selectedLanguage"),
           let savedLanguage = SupportedLanguage(rawValue: savedLanguageCode) {
            self.currentLanguage = savedLanguage
        } else {
            // Default to device language if supported, otherwise English
            self.currentLanguage = Self.detectDeviceLanguage()
        }
        
        self.autoDetectLanguage = userDefaults.bool(forKey: "autoDetectLanguage")
        
        initializeSpeechRecognizers()
    }
    
    /// Detect the device's current language and return supported equivalent
    static func detectDeviceLanguage() -> SupportedLanguage {
        let deviceLanguage = Locale.current.language.languageCode?.identifier ?? "en"
        let deviceRegion = Locale.current.region?.identifier ?? "US"
        let fullCode = "\(deviceLanguage)-\(deviceRegion)"
        
        // Try exact match first
        if let language = SupportedLanguage(rawValue: fullCode) {
            return language
        }
        
        // Try language code match
        switch deviceLanguage {
        case "en": return .english
        case "es": return .spanish
        case "fr": return .french
        case "de": return .german
        case "it": return .italian
        case "pt": return .portuguese
        case "ja": return .japanese
        case "zh": return .chinese
        case "ko": return .korean
        case "ru": return .russian
        case "tr": return .turkish
        default: return .english
        }
    }
    
    /// Initialize speech recognizers for supported languages
    private func initializeSpeechRecognizers() {
        for language in SupportedLanguage.allCases {
            if language.isSpeechRecognitionSupported {
                speechRecognizers[language] = SFSpeechRecognizer(locale: language.locale)
            }
        }
    }
    
    /// Get speech recognizer for a specific language
    func speechRecognizer(for language: SupportedLanguage) -> SFSpeechRecognizer? {
        return speechRecognizers[language]
    }
    
    /// Get the current speech recognizer
    var currentSpeechRecognizer: SFSpeechRecognizer? {
        return speechRecognizer(for: currentLanguage)
    }
    
    /// Change the current language
    func setLanguage(_ language: SupportedLanguage) {
        currentLanguage = language
    }
    
    /// Save language preference to UserDefaults
    private func saveLanguagePreference() {
        userDefaults.set(currentLanguage.rawValue, forKey: "selectedLanguage")
    }
    
    /// Get all supported languages that have working speech recognition
    var availableLanguages: [SupportedLanguage] {
        return SupportedLanguage.allCases.filter { $0.isSpeechRecognitionSupported }
    }
    
    /// Toggle auto-detection
    func toggleAutoDetection() {
        autoDetectLanguage.toggle()
    }
    
    /// Get language-specific AI prompt context
    func getAIContext(for language: SupportedLanguage) -> String {
        switch language {
        case .english:
            return "The user is writing notes in English. Provide responses in English."
        case .spanish:
            return "El usuario está escribiendo notas en español. Proporciona respuestas en español."
        case .french:
            return "L'utilisateur écrit des notes en français. Fournissez des réponses en français."
        case .german:
            return "Der Benutzer schreibt Notizen auf Deutsch. Geben Sie Antworten auf Deutsch."
        case .italian:
            return "L'utente sta scrivendo note in italiano. Fornisci risposte in italiano."
        case .portuguese:
            return "O usuário está escrevendo notas em português. Forneça respostas em português."
        case .japanese:
            return "ユーザーは日本語でメモを書いています。日本語で回答してください。"
        case .chinese:
            return "用户正在用中文写笔记。请用中文回答。"
        case .korean:
            return "사용자가 한국어로 노트를 작성하고 있습니다. 한국어로 응답해 주세요."
        case .russian:
            return "Пользователь пишет заметки на русском языке. Предоставляйте ответы на русском языке."
        case .turkish:
            return "Kullanıcı Türkçe notlar yazıyor. Lütfen Türkçe yanıtlar verin."
        }
    }
    
    /// Debug information about language support
    func debugLanguageSupport() {
        print("=== Language Support Debug ===")
        print("Current Language: \(currentLanguage.displayName) (\(currentLanguage.rawValue))")
        print("Auto-detect: \(autoDetectLanguage)")
        print("Available Languages:")
        
        print("iOS Supported Locales: \(SFSpeechRecognizer.supportedLocales().map { $0.identifier }.sorted())")
        
        for language in SupportedLanguage.allCases {
            let supported = language.isSpeechRecognitionSupported ? "✓" : "✗"
            let recognizer = speechRecognizers[language] != nil ? "R" : "-"
            print("  \(supported)\(recognizer) \(language.flag) \(language.displayName) (\(language.rawValue))")
        }
        
        print("Speech recognizers initialized: \(speechRecognizers.count)")
        print("================================")
    }
}
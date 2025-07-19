import Foundation

struct Config {
    static let openAIAPIKey: String = {
        // Try .env file first (preferred method)
        if let envFileKey = loadFromEnvFile(key: "OPENAI_API_KEY"), !envFileKey.isEmpty {
            print("🔑 Using .env file API key")
            return envFileKey
        }
        
        // Try environment variable
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            print("🔑 Using environment variable API key")
            return envKey
        }
        
        // Try Info.plist as fallback
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OpenAIAPIKey"] as? String, !key.isEmpty {
            print("🔑 Using Info.plist API key")
            return key
        }
        
        print("❌ No OpenAI API key found")
        return ""
    }()
    
    static var hasValidOpenAIKey: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey.hasPrefix("sk-")
    }
    
    // Debug function to check configuration
    static func debugConfiguration() {
        print("=== OpenAI Configuration Debug ===")
        print("API Key exists: \(!openAIAPIKey.isEmpty)")
        print("API Key is valid format: \(hasValidOpenAIKey)")
        if hasValidOpenAIKey {
            print("API Key preview: \(openAIAPIKey.prefix(10))...")
        }
        
        // Check if .env file exists in various locations
        let possiblePaths = [
            Bundle.main.path(forResource: ".env", ofType: nil),
            Bundle.main.path(forResource: "Info", ofType: "plist")?.replacingOccurrences(of: "/Info.plist", with: "/.env"),
            Bundle.main.bundlePath.replacingOccurrences(of: "/Rapid Notes.app", with: "/.env")
        ]
        
        for (index, path) in possiblePaths.enumerated() {
            if let path = path {
                let exists = FileManager.default.fileExists(atPath: path)
                print("Path \(index + 1): \(exists ? "✓" : "✗") \(path)")
                
                // If file exists, try to read first few lines
                if exists {
                    do {
                        let content = try String(contentsOfFile: path, encoding: .utf8)
                        let lines = content.components(separatedBy: .newlines).prefix(3)
                        print("  Content preview: \(lines.joined(separator: " | "))")
                    } catch {
                        print("  Error reading file: \(error)")
                    }
                }
            } else {
                print("Path \(index + 1): ✗ (nil)")
            }
        }
        print("==================================")
    }
    
    private static func loadFromEnvFile(key: String) -> String? {
        // Try multiple common locations for .env file
        let possiblePaths = [
            // In the app bundle
            Bundle.main.path(forResource: ".env", ofType: nil),
            // In the same directory as Info.plist
            Bundle.main.path(forResource: "Info", ofType: "plist")?.replacingOccurrences(of: "/Info.plist", with: "/.env"),
            // In the project directory (when running in simulator)
            Bundle.main.bundlePath.replacingOccurrences(of: "/Rapid Notes.app", with: "/.env")
        ]
        
        for envPath in possiblePaths {
            guard let path = envPath, FileManager.default.fileExists(atPath: path) else { continue }
            
            do {
                let envContent = try String(contentsOfFile: path, encoding: .utf8)
                let lines = envContent.components(separatedBy: .newlines)
                
                for line in lines {
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("\(key)=") && !trimmed.hasPrefix("#") {
                        let value = String(trimmed.dropFirst("\(key)=".count))
                        return value.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch {
                print("Error reading .env file at \(path): \(error)")
            }
        }
        
        return nil
    }
    
    // MARK: - Language Configuration
    
    /// Default language for speech recognition and AI processing
    static var defaultLanguage: String {
        return UserDefaults.standard.string(forKey: "defaultLanguage") ?? LanguageService.detectDeviceLanguage().rawValue
    }
    
    /// Set the default language
    static func setDefaultLanguage(_ language: SupportedLanguage) {
        UserDefaults.standard.set(language.rawValue, forKey: "defaultLanguage")
    }
    
    /// Auto-detect language during transcription
    static var autoDetectLanguage: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "autoDetectLanguage")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "autoDetectLanguage")
        }
    }
    
    /// Enable AI transcription improvement
    static var enableAITranscriptionImprovement: Bool {
        get {
            return UserDefaults.standard.bool(forKey: "enableAITranscriptionImprovement")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "enableAITranscriptionImprovement")
        }
    }
    
    /// Minimum confidence threshold for language detection
    static var languageDetectionThreshold: Double {
        get {
            let threshold = UserDefaults.standard.double(forKey: "languageDetectionThreshold")
            return threshold > 0 ? threshold : 0.7 // Default to 0.7
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "languageDetectionThreshold")
        }
    }
    
    /// Preferred languages (ordered by preference)
    static var preferredLanguages: [String] {
        get {
            return UserDefaults.standard.stringArray(forKey: "preferredLanguages") ?? [defaultLanguage]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "preferredLanguages")
        }
    }
    
    /// Add a language to preferred languages
    static func addPreferredLanguage(_ language: SupportedLanguage) {
        var current = preferredLanguages
        let languageCode = language.rawValue
        
        // Remove if already exists
        current.removeAll { $0 == languageCode }
        
        // Add to front
        current.insert(languageCode, at: 0)
        
        // Keep only top 5 languages
        preferredLanguages = Array(current.prefix(5))
    }
    
    /// Debug language configuration
    static func debugLanguageConfiguration() {
        print("=== Language Configuration Debug ===")
        print("Default Language: \(defaultLanguage)")
        print("Auto-detect: \(autoDetectLanguage)")
        print("AI Transcription Improvement: \(enableAITranscriptionImprovement)")
        print("Detection Threshold: \(languageDetectionThreshold)")
        print("Preferred Languages: \(preferredLanguages)")
        print("OpenAI API Key Available: \(hasValidOpenAIKey)")
        print("===================================")
    }
}
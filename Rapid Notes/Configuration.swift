import Foundation

/// Configuration manager for environment variables and app settings
struct Configuration {
    
    /// OpenAI API Key for AI features
    static var openAIAPIKey: String {
        // First try to load from .env file
        if let path = Bundle.main.path(forResource: ".env", ofType: nil),
           let contents = try? String(contentsOfFile: path, encoding: .utf8) {
            let lines = contents.components(separatedBy: .newlines)
            for line in lines {
                if line.hasPrefix("OPENAI_API_KEY=") {
                    let key = String(line.dropFirst("OPENAI_API_KEY=".count))
                    if !key.isEmpty && key != "your_openai_api_key_here" {
                        return key
                    }
                }
            }
        }
        
        // Fallback to environment variable
        return ProcessInfo.processInfo.environment["OPENAI_API_KEY"] ?? ""
    }
    
    /// Check if AI features are properly configured
    static var isAIConfigured: Bool {
        let key = openAIAPIKey
        return !key.isEmpty && key != "your_openai_api_key_here"
    }
    
    /// Check if OpenAI API key is valid (alias for compatibility)
    static var hasValidOpenAIKey: Bool {
        return isAIConfigured
    }
    
    /// Debug configuration information
    static func debugConfiguration() {
        print("OpenAI API Key configured: \(hasValidOpenAIKey)")
    }
    
    /// App configuration constants
    enum AppConfig {
        static let appGroupIdentifier = "group.Theory-of-Web.Rapid-Notes"
        static let widgetKind = "QuickDumpWidget"
        static let urlScheme = "quickdump"
    }
}

// MARK: - Compatibility Typealias
// Note: Config class is defined in Config.swift with more robust implementation
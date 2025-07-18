import Foundation

struct Config {
    static let openAIAPIKey: String = {
        // Try environment variable first
        if let envKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !envKey.isEmpty {
            return envKey
        }
        
        // Try .env file
        if let envFileKey = loadFromEnvFile(key: "OPENAI_API_KEY"), !envFileKey.isEmpty {
            return envFileKey
        }
        
        // Try Info.plist
        if let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
           let plist = NSDictionary(contentsOfFile: path),
           let key = plist["OpenAIAPIKey"] as? String, !key.isEmpty {
            return key
        }
        
        // Return empty string if not found
        return ""
    }()
    
    static var hasValidOpenAIKey: Bool {
        return !openAIAPIKey.isEmpty && openAIAPIKey.hasPrefix("sk-")
    }
    
    private static func loadFromEnvFile(key: String) -> String? {
        // Get the project root directory
        guard let projectPath = Bundle.main.path(forResource: "Info", ofType: "plist")?.replacingOccurrences(of: "/Rapid Notes/Info.plist", with: ""),
              let envPath = findEnvFile(startingFrom: projectPath) else {
            return nil
        }
        
        do {
            let envContent = try String(contentsOfFile: envPath)
            let lines = envContent.components(separatedBy: .newlines)
            
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.hasPrefix("\(key)=") && !trimmed.hasPrefix("#") {
                    let value = String(trimmed.dropFirst("\(key)=".count))
                    return value.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        } catch {
            print("Error reading .env file: \(error)")
        }
        
        return nil
    }
    
    private static func findEnvFile(startingFrom path: String) -> String? {
        let fileManager = FileManager.default
        var currentPath = path
        
        // Look for .env file in current directory and parent directories
        for _ in 0..<5 { // Limit search to 5 levels up
            let envPath = currentPath + "/.env"
            if fileManager.fileExists(atPath: envPath) {
                return envPath
            }
            
            // Move up one directory
            currentPath = (currentPath as NSString).deletingLastPathComponent
            if currentPath == "/" {
                break
            }
        }
        
        return nil
    }
}
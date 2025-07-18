import Foundation

@MainActor
class AIService: ObservableObject {
    private let openAIEndpoint = "https://api.openai.com/v1/chat/completions"
    
    func analyzeNote(_ content: String) async -> (tags: [String], summary: String) {
        // Try OpenAI API first, fallback to mock if it fails
        if let result = await callOpenAIAPI(content: content) {
            return result
        } else {
            // Fallback to mock implementation
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let mockTags = self.generateMockTags(for: content)
                    let mockSummary = self.generateMockSummary(for: content)
                    continuation.resume(returning: (tags: mockTags, summary: mockSummary))
                }
            }
        }
    }
    
    private func callOpenAIAPI(content: String) async -> (tags: [String], summary: String)? {
        // Skip API call if no API key is configured
        guard Config.hasValidOpenAIKey else {
            return nil
        }
        
        let prompt = """
        Analyze this note and provide:
        1. Up to 3 relevant tags from these categories: meeting, idea, todo, reminder, shopping, work, personal, health, travel, finance, general
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
    
    private func generateMockTags(for content: String) -> [String] {
        let lowercaseContent = content.lowercased()
        var tags: [String] = []
        
        if lowercaseContent.contains("meeting") || lowercaseContent.contains("call") {
            tags.append("meeting")
        }
        if lowercaseContent.contains("idea") || lowercaseContent.contains("think") {
            tags.append("idea")
        }
        if lowercaseContent.contains("todo") || lowercaseContent.contains("task") {
            tags.append("todo")
        }
        if lowercaseContent.contains("remember") || lowercaseContent.contains("remind") {
            tags.append("reminder")
        }
        if lowercaseContent.contains("buy") || lowercaseContent.contains("purchase") {
            tags.append("shopping")
        }
        
        if tags.isEmpty {
            tags.append("general")
        }
        
        return tags
    }
    
    private func generateMockSummary(for content: String) -> String {
        let wordCount = content.split(separator: " ").count
        
        if wordCount <= 10 {
            return "Short note"
        } else if wordCount <= 30 {
            return "Medium-length note about \(extractKeywords(from: content))"
        } else {
            return "Detailed note covering \(extractKeywords(from: content))"
        }
    }
    
    private func extractKeywords(from content: String) -> String {
        let words = content.split(separator: " ").map(String.init)
        let meaningfulWords = words.filter { word in
            word.count > 3 && !["this", "that", "with", "have", "will", "been", "from", "they", "were", "said", "each", "which", "their", "time", "would", "there", "could", "other"].contains(word.lowercased())
        }
        
        return meaningfulWords.prefix(3).joined(separator: ", ")
    }
}
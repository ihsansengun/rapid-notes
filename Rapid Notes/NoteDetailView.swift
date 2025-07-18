import SwiftUI
import CoreData
import MapKit

struct NoteDetailView: View {
    @ObservedObject var note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIService()
    
    @State private var isExpanding = false
    @State private var expandedContent = ""
    @State private var showingExpandedContent = false
    @State private var showingMap = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original note content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note Content")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Text(note.content ?? "")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .padding(16)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                }
                
                // Note metadata
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: note.isVoiceNote ? "mic.fill" : "text.bubble")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                        Text(note.isVoiceNote ? "Voice Note" : "Text Note")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                        Text(note.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    if let locationName = note.locationName, !locationName.isEmpty {
                        Button(action: {
                            showingMap = true
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "location")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                                Text(locationName)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.blue)
                                Image(systemName: "map")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue.opacity(0.6))
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                // AI Tags
                if let aiTags = note.aiTags, !aiTags.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Tags")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(aiTags.components(separatedBy: ","), id: \.self) { tag in
                                    Text(tag.trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(16)
                                }
                            }
                            .padding(.horizontal, 1)
                        }
                    }
                }
                
                // AI Summary
                if let aiSummary = note.aiSummary, !aiSummary.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Summary")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Text(aiSummary)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                
                // AI Expand button
                if Config.hasValidOpenAIKey {
                    Button(action: {
                        Task {
                            await expandNote()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .medium))
                            Text(isExpanding ? "Expanding..." : "Expand with AI")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.purple.opacity(0.3))
                        .cornerRadius(12)
                    }
                    .disabled(isExpanding)
                    
                    // Expanded content
                    if showingExpandedContent && !expandedContent.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("AI-Expanded Note")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text(expandedContent)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color.black)
        .navigationTitle("Note Details")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .preferredColorScheme(.dark)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.blue)
            }
        }
        .sheet(isPresented: $showingMap) {
            if note.latitude != 0 && note.longitude != 0 {
                MapView(latitude: note.latitude, longitude: note.longitude, locationName: note.locationName ?? "Unknown Location")
            }
        }
    }
    
    private func expandNote() async {
        guard let content = note.content, !content.isEmpty else { return }
        
        isExpanding = true
        
        let expandedNote = await aiService.expandNote(content)
        
        await MainActor.run {
            self.expandedContent = expandedNote
            self.showingExpandedContent = true
            self.isExpanding = false
        }
    }
}

extension AIService {
    func expandNote(_ content: String) async -> String {
        // Try OpenAI API first, fallback to mock if it fails
        if let result = await callOpenAIForExpansion(content: content) {
            return result
        } else {
            // Fallback to mock expansion
            return await withCheckedContinuation { continuation in
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let mockExpansion = self.generateMockExpansion(for: content)
                    continuation.resume(returning: mockExpansion)
                }
            }
        }
    }
    
    private func callOpenAIForExpansion(content: String) async -> String? {
        guard Config.hasValidOpenAIKey else { return nil }
        
        let prompt = """
        Take this brief note and expand it into a more detailed, well-structured note. Add context, suggestions, and relevant details while maintaining the original intent. Make it practical and actionable.
        
        Original note: "\(content)"
        
        Provide an expanded version (2-3 paragraphs maximum):
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
            "temperature": 0.7
        ]
        
        do {
            guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else { return nil }
            
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
            print("OpenAI API error for expansion: \(error)")
        }
        
        return nil
    }
    
    private func generateMockExpansion(for content: String) -> String {
        let baseExpansion = """
        This note appears to be about \(content.lowercased()). Here are some additional thoughts and suggestions:
        
        Consider breaking this down into actionable steps and setting specific deadlines. It might also be helpful to identify any resources or people you need to involve in this process.
        
        Remember to follow up on this item and track your progress. You could set a reminder to check back on this in a few days to see how things are developing.
        """
        
        return baseExpansion
    }
}

struct MapView: View {
    let latitude: Double
    let longitude: Double
    let locationName: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [MapLocation(coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude), name: locationName)]) { location in
                MapPin(coordinate: location.coordinate, tint: .blue)
            }
            .navigationTitle("Note Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct MapLocation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let name: String
}

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let sampleNote = Note(context: context)
    sampleNote.content = "Remember to buy groceries for the dinner party"
    sampleNote.createdAt = Date()
    sampleNote.isVoiceNote = true
    sampleNote.locationName = "Home"
    sampleNote.aiTags = "shopping,reminder"
    sampleNote.aiSummary = "Note about buying groceries for dinner party"
    
    return NavigationView {
        NoteDetailView(note: sampleNote)
    }
    .environment(\.managedObjectContext, context)
}
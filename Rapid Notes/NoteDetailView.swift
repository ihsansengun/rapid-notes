import SwiftUI
import CoreData
import MapKit

struct NoteDetailView: View {
    @ObservedObject var note: Note
    let startInEditMode: Bool
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var aiService = AIService()
    
    @State private var isExpanding = false
    @State private var expandedContent = ""
    @State private var showingExpandedContent = false
    @State private var showingMap = false
    @State private var isEditing = false
    @State private var editedContent = ""
    
    init(note: Note, startInEditMode: Bool = false) {
        self.note = note
        self.startInEditMode = startInEditMode
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Original note content
                VStack(alignment: .leading, spacing: 12) {
                    Text("Note Content")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if isEditing {
                        TextField("Note content", text: $editedContent, axis: .vertical)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(12)
                            .textFieldStyle(PlainTextFieldStyle())
                    } else {
                        Text(note.content ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                    }
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
                    
                    // Language information
                    HStack(spacing: 12) {
                        Image(systemName: "globe")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.6))
                        
                        HStack(spacing: 6) {
                            Text(note.languageFlag)
                                .font(.system(size: 14))
                            
                            Text(note.languageDisplayName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.8))
                            
                            // Show language mismatch indicator if detected language differs
                            if note.hasLanguageMismatch {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange)
                                
                                Text("(\(note.detectedSupportedLanguage?.displayName ?? "Unknown") detected)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.orange.opacity(0.8))
                            }
                        }
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
                
                // Memory connections (discovered in background)
                MemoryConnectionsView(note: note)
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
            #if os(iOS)
            ToolbarItem(placement: .navigationBarLeading) {
                if isEditing {
                    Button("Cancel") {
                        cancelEditing()
                    }
                    .foregroundColor(.red)
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                if isEditing {
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundColor(.blue)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                    .foregroundColor(.blue)
                }
            }
            #else
            ToolbarItem(placement: .confirmationAction) {
                if isEditing {
                    Button("Save") {
                        saveNote()
                    }
                    .foregroundColor(.blue)
                } else {
                    Button("Edit") {
                        startEditing()
                    }
                    .foregroundColor(.blue)
                }
            }
            #endif
        }
        .sheet(isPresented: $showingMap) {
            if note.latitude != 0 && note.longitude != 0 {
                MapView(latitude: note.latitude, longitude: note.longitude, locationName: note.locationName ?? "Unknown Location")
            }
        }
        .onAppear {
            editedContent = note.content ?? ""
            if startInEditMode {
                isEditing = true
            }
        }
    }
    
    // MARK: - Edit Functions
    
    private func startEditing() {
        editedContent = note.content ?? ""
        isEditing = true
    }
    
    private func cancelEditing() {
        editedContent = note.content ?? ""
        isEditing = false
    }
    
    private func saveNote() {
        note.content = editedContent
        
        do {
            try viewContext.save()
            isEditing = false
        } catch {
            print("Error saving note: \(error)")
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
            VStack(spacing: 20) {
                Text("📍 Note Location")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Location: \(locationName)")
                        .font(.body)
                        .foregroundColor(.white)
                    
                    Text("Coordinates:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Lat: \(String(format: "%.6f", latitude))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Lng: \(String(format: "%.6f", longitude))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                
                // Note: Map functionality temporarily simplified
                // The full map view with annotations will be restored
                // once SwiftUI Map API compatibility issues are resolved
                Text("📍 Map view temporarily unavailable")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .italic()
                
                Spacer()
            }
            .padding()
            .background(Color.black)
            .navigationTitle("Note Location")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                #endif
            }
        }
        .preferredColorScheme(.dark)
    }
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
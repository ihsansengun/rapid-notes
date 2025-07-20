import SwiftUI

/// Subtle memory insights view - shows discovered patterns without immediate processing
/// Only displays background-analyzed insights when they naturally emerge
struct NoteEnhancementView: View {
    @ObservedObject var note: Note
    
    var body: some View {
        VStack(spacing: 8) {
            // Only show insights if they exist from background processing
            if note.hasBackgroundInsights {
                subtleInsightsCard
            }
        }
        .animation(.easeInOut(duration: 0.3), value: note.hasBackgroundInsights)
    }
    
    // MARK: - Subtle Insights Card
    
    private var subtleInsightsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Only show discovered patterns, no processing actions
            if let category = note.localizedAICategory {
                HStack {
                    Text(LocalizedCategory.getIcon(for: category))
                        .font(.caption)
                    Text(LocalizedCategory.getDisplayName(for: category, language: note.supportedLanguage ?? .english))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            
            // Show if this note connects to others (discovered in background)
            if note.hasMemoryConnections {
                HStack {
                    Image(systemName: "link")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Part of a thread")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(6)
    }
    
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "Claude super idea"
    note.createdAt = Date()
    note.isVoiceNote = true
    note.setLanguage(.english)
    note.needsAIProcessing = true
    
    return VStack {
        NoteEnhancementView(note: note)
        Spacer()
    }
    .padding()
}

#Preview("With AI Results") {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "Call Victor about the book club meeting"
    note.createdAt = Date()
    note.isVoiceNote = true
    note.setLanguage(.english)
    note.aiInterpretation = "You want to contact Victor regarding a book club meeting arrangement."
    note.aiCategory = "meeting"
    note.setAINextSteps(["Find Victor's contact", "Schedule the call", "Prepare meeting agenda"])
    note.aiReminderSuggestion = "Today at 3:00 PM"
    note.aiConfidence = 0.85
    
    return VStack {
        NoteEnhancementView(note: note)
        Spacer()
    }
    .padding()
}
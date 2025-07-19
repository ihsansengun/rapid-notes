import SwiftUI

/// Compact note card with language indicator for list views
struct NoteCardView: View {
    let note: Note
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Header with language and type info
                HStack {
                    // Language flag
                    Text(note.languageFlag)
                        .font(.caption)
                    
                    // Note type indicator
                    Image(systemName: note.isVoiceNote ? "mic.fill" : "text.bubble")
                        .font(.caption)
                        .foregroundColor(note.isVoiceNote ? .blue : .green)
                    
                    Spacer()
                    
                    // Language mismatch warning
                    if note.hasLanguageMismatch {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    // Creation date
                    if let createdAt = note.createdAt {
                        Text(createdAt.formatted(.relative(presentation: .named)))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Note content preview
                Text(note.content ?? "")
                    .font(.body)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .foregroundColor(.primary)
                
                // AI tags if available
                if let aiTags = note.aiTags, !aiTags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 4) {
                            ForEach(Array(aiTags.components(separatedBy: ",").prefix(3)), id: \.self) { tag in
                                Text(tag.trimmingCharacters(in: .whitespaces))
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                
                // Additional info footer
                HStack {
                    // Language detection confidence
                    if note.languageConfidence > 0 && note.languageConfidence < 0.9 {
                        HStack(spacing: 2) {
                            Image(systemName: "waveform.path.ecg")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            
                            Text("\(Int(note.languageConfidence * 100))%")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    // Location indicator
                    if let locationName = note.locationName, !locationName.isEmpty {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            Text(locationName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Minimal language indicator for compact views
struct LanguageIndicator: View {
    let note: Note
    let style: Style
    
    enum Style {
        case flagOnly
        case flagWithName
        case detailed
    }
    
    var body: some View {
        Group {
            switch style {
            case .flagOnly:
                Text(note.languageFlag)
                    .font(.caption)
                
            case .flagWithName:
                HStack(spacing: 2) {
                    Text(note.languageFlag)
                        .font(.caption)
                    
                    Text(note.languageDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
            case .detailed:
                HStack(spacing: 4) {
                    Text(note.languageFlag)
                        .font(.caption)
                    
                    Text(note.languageDisplayName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    if note.hasLanguageMismatch {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                    
                    if note.languageConfidence < 0.8 {
                        Text("(\(Int(note.languageConfidence * 100))%)")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }
    }
}

#Preview {
    let context = PersistenceController.shared.container.viewContext
    let mockNote = Note(context: context)
    mockNote.content = "This is a sample note with some content to show how the language indicator works in the card view."
    mockNote.createdAt = Date()
    mockNote.isVoiceNote = true
    mockNote.language = "en-US"
    mockNote.detectedLanguage = "es-ES"
    mockNote.languageConfidence = 0.75
    mockNote.aiTags = "meeting,idea,work"
    mockNote.locationName = "San Francisco"
    
    return VStack(spacing: 16) {
        NoteCardView(note: mockNote) {
            print("Note tapped")
        }
        
        HStack {
            LanguageIndicator(note: mockNote, style: .flagOnly)
            LanguageIndicator(note: mockNote, style: .flagWithName)
            LanguageIndicator(note: mockNote, style: .detailed)
        }
        .padding()
    }
    .padding()
}
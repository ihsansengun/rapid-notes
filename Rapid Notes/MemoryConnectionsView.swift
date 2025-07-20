import SwiftUI

/// Shows memory connections and threads discovered for this note through background analysis
/// No immediate processing - only displays insights that have been quietly discovered over time
struct MemoryConnectionsView: View {
    @ObservedObject var note: Note
    @StateObject private var memoryEngine = MemoryEngine.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Show thread connections if discovered
            if !relatedThreads.isEmpty {
                threadConnectionsSection
            }
            
            // Show memory archaeology if note is old and relevant
            if isArchaeologyGem {
                archaeologySection
            }
            
            // Show contextual patterns if discovered
            if !contextualPatterns.isEmpty {
                patternsSection
            }
        }
    }
    
    // MARK: - Thread Connections
    
    private var threadConnectionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "link")
                    .foregroundColor(.blue)
                    .font(.caption)
                
                Text("Memory Thread")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            ForEach(relatedThreads.prefix(2), id: \.id) { thread in
                NavigationLink(destination: ThreadDetailView(thread: thread)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(thread.theme.capitalized)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("\(thread.notes.count) connected notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
    
    // MARK: - Archaeology Section
    
    private var archaeologySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "archivebox")
                    .foregroundColor(.orange)
                    .font(.caption)
                
                Text("Memory Gem")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("This note has aged like fine wine")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                if let ageDescription = noteAgeDescription {
                    Text(ageDescription)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Patterns Section
    
    private var patternsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Patterns")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            
            ForEach(contextualPatterns.prefix(2), id: \.id) { pattern in
                HStack {
                    Image(systemName: pattern.type.icon)
                        .foregroundColor(.green)
                        .font(.caption2)
                    
                    Text(pattern.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var relatedThreads: [MemoryThread] {
        return memoryEngine.getRelatedThreads(for: note)
    }
    
    private var isArchaeologyGem: Bool {
        guard let createdAt = note.createdAt else { return false }
        let ageInDays = Date().timeIntervalSince(createdAt) / (24 * 3600)
        return ageInDays >= 7 && note.aiCategory != nil // At least a week old with some insights
    }
    
    private var noteAgeDescription: String? {
        guard let createdAt = note.createdAt else { return nil }
        let ageInDays = Int(Date().timeIntervalSince(createdAt) / (24 * 3600))
        
        if ageInDays >= 365 {
            return "From \(ageInDays / 365) year\(ageInDays / 365 == 1 ? "" : "s") ago"
        } else if ageInDays >= 30 {
            return "From \(ageInDays / 30) month\(ageInDays / 30 == 1 ? "" : "s") ago"
        } else if ageInDays >= 7 {
            return "From \(ageInDays / 7) week\(ageInDays / 7 == 1 ? "" : "s") ago"
        } else {
            return "From \(ageInDays) day\(ageInDays == 1 ? "" : "s") ago"
        }
    }
    
    private var contextualPatterns: [MemoryPattern] {
        return memoryEngine.memoryPatterns.filter { pattern in
            // Show patterns that relate to this note's context
            if let location = note.locationName {
                return pattern.description.localizedCaseInsensitiveContains(location)
            }
            
            if let category = note.aiCategory {
                return pattern.description.localizedCaseInsensitiveContains(category)
            }
            
            return false
        }
    }
}

// MARK: - Thread Detail View

struct ThreadDetailView: View {
    let thread: MemoryThread
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Thread overview
                VStack(alignment: .leading, spacing: 8) {
                    Text(thread.theme.capitalized)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(thread.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text("Discovered: \(thread.discoveredAt, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                
                // Thread evolution (chronological)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Thread Evolution")
                        .font(.headline)
                    
                    ForEach(thread.notes.sorted(by: { ($0.createdAt ?? Date()) < ($1.createdAt ?? Date()) }), id: \.id) { note in
                        ThreadNoteCard(note: note)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle("Memory Thread")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ThreadNoteCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let date = note.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if let location = note.locationName {
                    HStack {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Text(note.content ?? "")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "Hugging face API"
    note.createdAt = Date()
    note.setLanguage(.english)
    note.aiCategory = "product"
    note.locationName = "Coffee Shop"
    
    return NavigationView {
        VStack {
            MemoryConnectionsView(note: note)
            Spacer()
        }
        .padding()
    }
}
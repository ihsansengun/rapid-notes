import SwiftUI
import CoreData

/// View for displaying related notes grouped by entities, topics, or time proximity
struct RelatedNotesView: View {
    let currentNote: Note
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var aiMemoryService = AIMemoryService()
    @StateObject private var categoryService = CategoryService.shared
    
    @State private var relatedNotes: [RelatedNote] = []
    @State private var groupedNotes: [NoteGroup] = []
    @State private var isLoading = false
    @State private var selectedGroupType: GroupType = .category
    
    enum GroupType: String, CaseIterable {
        case category = "Category"
        case entity = "Entity"
        case time = "Time"
        case language = "Language"
        
        var displayName: String { rawValue }
        var icon: String {
            switch self {
            case .category: return "folder"
            case .entity: return "person.2"
            case .time: return "clock"
            case .language: return "globe"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Grouping options
            groupingSelector
            
            // Content
            if isLoading {
                loadingView
            } else if groupedNotes.isEmpty && relatedNotes.isEmpty {
                emptyStateView
            } else {
                contentScrollView
            }
        }
        .onAppear {
            loadRelatedNotes()
        }
        .onChange(of: selectedGroupType) {
            updateGrouping()
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Related Notes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    loadRelatedNotes()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Notes connected to: \"\(currentNote.content?.prefix(50) ?? "")...\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - Grouping Selector
    
    private var groupingSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(GroupType.allCases, id: \.self) { groupType in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedGroupType = groupType
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: groupType.icon)
                                .font(.caption)
                            
                            Text(groupType.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            selectedGroupType == groupType ?
                            Color.blue : Color.gray.opacity(0.1)
                        )
                        .foregroundColor(
                            selectedGroupType == groupType ?
                            .white : .secondary
                        )
                        .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Finding related notes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Related Notes Found")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("As you create more notes, connections will appear here based on shared topics, entities, and categories.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var contentScrollView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Direct related notes (AI-found relationships)
                if !relatedNotes.isEmpty {
                    relatedNotesSection
                }
                
                // Grouped notes
                ForEach(groupedNotes, id: \.id) { group in
                    noteGroupView(group)
                }
            }
            .padding()
        }
    }
    
    private var relatedNotesSection: some View {
        let limitedNotes = Array(relatedNotes.prefix(5))
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("🧠 AI-Detected Connections")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(limitedNotes, id: \.id) { relatedNote in
                RelatedNoteCard(
                    relatedNote: relatedNote,
                    onTap: { /* Navigate to note */ }
                )
            }
        }
    }
    
    private func noteGroupView(_ group: NoteGroup) -> some View {
        let limitedGroupNotes = Array(group.notes.prefix(3))
        
        return VStack(alignment: .leading, spacing: 12) {
            // Group header
            HStack {
                Image(systemName: group.icon)
                    .foregroundColor(.blue)
                
                Text(group.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(group.notes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)
            }
            
            // Group notes
            ForEach(limitedGroupNotes, id: \.id) { note in
                CompactNoteCard(note: note)
            }
            
            // Show more button if there are more notes
            if group.notes.count > 3 {
                Button("Show \(group.notes.count - 3) more notes") {
                    // TODO: Show expanded view
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Data Loading
    
    private func loadRelatedNotes() {
        guard let content = currentNote.content, !content.isEmpty else { return }
        
        isLoading = true
        
        Task {
            // Get all notes except current one
            let allNotes = await fetchAllNotes()
            let otherNotes = allNotes.filter { $0.id != currentNote.id }
            let noteContents = otherNotes.compactMap { $0.content }
            
            // Find AI-detected relationships
            let foundRelatedNotes = await aiMemoryService.findRelatedNotes(
                content,
                in: noteContents,
                language: currentNote.supportedLanguage
            )
            
            await MainActor.run {
                self.relatedNotes = foundRelatedNotes
                self.updateGrouping()
                self.isLoading = false
            }
        }
    }
    
    private func fetchAllNotes() async -> [Note] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
                
                do {
                    let notes = try viewContext.fetch(request)
                    continuation.resume(returning: notes)
                } catch {
                    print("Error fetching notes: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func updateGrouping() {
        Task {
            let allNotes = await fetchAllNotes()
            let otherNotes = allNotes.filter { $0.id != currentNote.id }
            
            await MainActor.run {
                switch selectedGroupType {
                case .category:
                    groupedNotes = groupNotesByCategory(otherNotes)
                case .entity:
                    groupedNotes = groupNotesByEntity(otherNotes)
                case .time:
                    groupedNotes = groupNotesByTime(otherNotes)
                case .language:
                    groupedNotes = groupNotesByLanguage(otherNotes)
                }
            }
        }
    }
    
    // MARK: - Grouping Logic
    
    private func groupNotesByCategory(_ notes: [Note]) -> [NoteGroup] {
        let currentCategory = currentNote.aiCategory
        
        var groups: [NoteGroup] = []
        
        // Same category group
        if let category = currentCategory {
            let sameCategory = notes.filter { $0.aiCategory == category }
            if !sameCategory.isEmpty {
                groups.append(NoteGroup(
                    id: "category-\(category)",
                    title: LocalizedCategory.getDisplayName(for: category, language: currentNote.supportedLanguage ?? .english),
                    icon: LocalizedCategory.getIcon(for: category),
                    notes: sameCategory
                ))
            }
        }
        
        // Other categories with multiple notes
        let categorizedNotes = Dictionary(grouping: notes.filter { $0.aiCategory != currentCategory && $0.aiCategory != nil }) { $0.aiCategory! }
        
        for (category, categoryNotes) in categorizedNotes {
            if categoryNotes.count >= 2 {
                groups.append(NoteGroup(
                    id: "category-\(category)",
                    title: LocalizedCategory.getDisplayName(for: category, language: currentNote.supportedLanguage ?? .english),
                    icon: LocalizedCategory.getIcon(for: category),
                    notes: categoryNotes
                ))
            }
        }
        
        return groups.sorted { $0.notes.count > $1.notes.count }
    }
    
    private func groupNotesByEntity(_ notes: [Note]) -> [NoteGroup] {
        // Extract entities from current note
        let currentContent = currentNote.content?.lowercased() ?? ""
        let currentWords = currentContent.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 }
        
        var groups: [String: [Note]] = [:]
        
        for note in notes {
            let noteContent = note.content?.lowercased() ?? ""
            
            // Find shared entities (words longer than 3 characters)
            for word in currentWords {
                if noteContent.contains(word) {
                    groups[word, default: []].append(note)
                }
            }
        }
        
        return Array(groups
            .filter { $0.value.count >= 2 }
            .map { key, notes in
                NoteGroup(
                    id: "entity-\(key)",
                    title: "Contains \"\(key.capitalized)\"",
                    icon: "person.2",
                    notes: notes
                )
            }
            .sorted { $0.notes.count > $1.notes.count }
            .prefix(5))
    }
    
    private func groupNotesByTime(_ notes: [Note]) -> [NoteGroup] {
        guard let currentDate = currentNote.createdAt else { return [] }
        
        let calendar = Calendar.current
        var groups: [NoteGroup] = []
        
        // Same day
        let sameDay = notes.filter { note in
            guard let noteDate = note.createdAt else { return false }
            return calendar.isDate(noteDate, inSameDayAs: currentDate)
        }
        
        if !sameDay.isEmpty {
            groups.append(NoteGroup(
                id: "time-same-day",
                title: "Same Day",
                icon: "sun.max",
                notes: sameDay
            ))
        }
        
        // Same week
        let sameWeek = notes.filter { note in
            guard let noteDate = note.createdAt else { return false }
            return calendar.isDate(noteDate, equalTo: currentDate, toGranularity: .weekOfYear) &&
                   !calendar.isDate(noteDate, inSameDayAs: currentDate)
        }
        
        if !sameWeek.isEmpty {
            groups.append(NoteGroup(
                id: "time-same-week",
                title: "Same Week",
                icon: "calendar.badge.clock",
                notes: sameWeek
            ))
        }
        
        return groups
    }
    
    private func groupNotesByLanguage(_ notes: [Note]) -> [NoteGroup] {
        let languageGroups = Dictionary(grouping: notes) { $0.supportedLanguage }
        
        return languageGroups.compactMap { language, notes in
            guard let lang = language, notes.count >= 2 else { return nil }
            
            return NoteGroup(
                id: "language-\(lang.rawValue)",
                title: "\(lang.flag) \(lang.displayName)",
                icon: "globe",
                notes: notes
            )
        }.sorted { $0.notes.count > $1.notes.count }
    }
}

// MARK: - Supporting Views

struct RelatedNoteCard: View {
    let relatedNote: RelatedNote
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Content preview
                Text(relatedNote.content)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Relationship info
                HStack {
                    Text(relatedNote.relationType.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                    
                    Text(relatedNote.explanation)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Confidence indicator
                    Circle()
                        .fill(relatedNote.isHighConfidence ? Color.green : Color.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CompactNoteCard: View {
    let note: Note
    
    var body: some View {
        HStack(spacing: 12) {
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(note.content ?? "")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 8) {
                    if note.isVoiceNote {
                        Image(systemName: "mic.fill")
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                    
                    Text(note.languageFlag)
                        .font(.caption2)
                    
                    Text(note.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Navigation arrow
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - Data Models

struct NoteGroup {
    let id: String
    let title: String
    let icon: String
    let notes: [Note]
}

// MARK: - Preview

#Preview {
    let context = PersistenceController.preview.container.viewContext
    let note = Note(context: context)
    note.id = UUID()
    note.content = "Meeting with John about the project proposal"
    note.createdAt = Date()
    note.setLanguage(.english)
    note.aiCategory = "meeting"
    
    return RelatedNotesView(currentNote: note)
        .environment(\.managedObjectContext, context)
}
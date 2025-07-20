import Foundation
import CoreData

/// Background memory analysis engine that discovers patterns, threads, and connections across notes over time
/// This is the core of the memory augmentation system - it quietly builds understanding without user intervention
@MainActor
class MemoryEngine: ObservableObject {
    static let shared = MemoryEngine()
    
    private let aiMemoryService = AIMemoryService()
    private let categoryService = CategoryService.shared
    
    @Published var isAnalyzing = false
    @Published var lastAnalysis: Date?
    @Published var discoveredThreads: [MemoryThread] = []
    @Published var memoryPatterns: [MemoryPattern] = []
    
    private init() {
        loadMemoryCache()
        schedulePeriodicAnalysis()
    }
    
    // MARK: - Memory Analysis
    
    /// Analyze all notes to discover threads, patterns, and connections
    func analyzeMemory(context: NSManagedObjectContext) async {
        guard !isAnalyzing else { return }
        
        isAnalyzing = true
        defer { isAnalyzing = false }
        
        print("🧠 Memory Engine: Starting background analysis...")
        
        // Get all notes
        let allNotes = await fetchAllNotes(context: context)
        
        // Discover threads and patterns
        await discoverThreads(notes: allNotes)
        await discoverPatterns(notes: allNotes)
        await categorizeUncategorized(notes: allNotes, context: context)
        
        lastAnalysis = Date()
        saveMemoryCache()
        
        print("🧠 Memory Engine: Analysis complete. Found \(discoveredThreads.count) threads, \(memoryPatterns.count) patterns")
    }
    
    /// Quick analysis for new notes (called when notes are added)
    func quickAnalysis(for newNote: Note, context: NSManagedObjectContext) async {
        guard let content = newNote.content, !content.isEmpty else { return }
        
        // Background categorization
        let result = await categoryService.categorizeNote(content, language: newNote.supportedLanguage)
        newNote.aiCategory = result.category
        newNote.aiConfidence = result.confidence
        
        // Check if this note extends existing threads
        await connectToExistingThreads(newNote: newNote)
        
        // Save
        try? context.save()
    }
    
    // MARK: - Thread Discovery
    
    private func discoverThreads(notes: [Note]) async {
        var threads: [MemoryThread] = []
        
        // Group notes by semantic similarity
        let noteGroups = await groupNotesBySemantic(notes: notes)
        
        for (theme, groupedNotes) in noteGroups {
            if groupedNotes.count >= 2 {
                let thread = MemoryThread(
                    id: UUID(),
                    theme: theme,
                    notes: groupedNotes,
                    discoveredAt: Date(),
                    strength: calculateThreadStrength(notes: groupedNotes)
                )
                threads.append(thread)
            }
        }
        
        // Sort by strength and recency
        discoveredThreads = threads.sorted { 
            $0.strength > $1.strength || ($0.strength == $1.strength && $0.discoveredAt > $1.discoveredAt)
        }
    }
    
    private func groupNotesBySemantic(notes: [Note]) async -> [String: [Note]] {
        var groups: [String: [Note]] = [:]
        
        // Use AI to find semantic themes
        for note in notes {
            guard let content = note.content, !content.isEmpty else { continue }
            
            // Extract key concepts
            let concepts = extractKeyConcepts(from: content)
            
            for concept in concepts {
                groups[concept, default: []].append(note)
            }
        }
        
        // Filter out single-note groups
        return groups.filter { $0.value.count >= 2 }
    }
    
    private func extractKeyConcepts(from content: String) -> [String] {
        let words = content.lowercased()
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
            .filter { $0.count > 3 } // Only meaningful words
        
        // Return unique significant words
        return Array(Set(words)).prefix(5).map { $0 }
    }
    
    private func calculateThreadStrength(notes: [Note]) -> Double {
        // Factors: number of notes, recency, time span
        let noteCount = Double(notes.count)
        let recency = notes.compactMap { $0.createdAt }.max()?.timeIntervalSinceNow ?? -1000000
        let recencyScore = max(0, 1 + recency / (7 * 24 * 3600)) // Decay over week
        
        return (noteCount / 10.0) * recencyScore
    }
    
    private func connectToExistingThreads(newNote: Note) async {
        guard let content = newNote.content else { return }
        
        let concepts = extractKeyConcepts(from: content)
        
        for thread in discoveredThreads {
            let threadConcepts = Set(thread.notes.flatMap { note in
                extractKeyConcepts(from: note.content ?? "")
            })
            
            let commonConcepts = Set(concepts).intersection(threadConcepts)
            if !commonConcepts.isEmpty {
                // This note belongs to an existing thread
                thread.notes.append(newNote)
                thread.strength = calculateThreadStrength(notes: thread.notes)
                break
            }
        }
    }
    
    // MARK: - Pattern Discovery
    
    private func discoverPatterns(notes: [Note]) async {
        var patterns: [MemoryPattern] = []
        
        // Time-based patterns
        patterns.append(contentsOf: discoverTimePatterns(notes: notes))
        
        // Location-based patterns
        patterns.append(contentsOf: discoverLocationPatterns(notes: notes))
        
        // Content patterns
        patterns.append(contentsOf: discoverContentPatterns(notes: notes))
        
        memoryPatterns = patterns
    }
    
    private func discoverTimePatterns(notes: [Note]) -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        // Group by hour of day
        let hourGroups = Dictionary(grouping: notes.compactMap { note -> (Int, Note)? in
            guard let date = note.createdAt else { return nil }
            let hour = Calendar.current.component(.hour, from: date)
            return (hour, note)
        }) { $0.0 }
        
        for (hour, entries) in hourGroups {
            if entries.count >= 3 {
                patterns.append(MemoryPattern(
                    id: UUID(),
                    type: .temporal,
                    description: "Most creative at \(hour):00",
                    strength: Double(entries.count) / Double(notes.count),
                    relatedNotes: entries.map { $0.1 }
                ))
            }
        }
        
        return patterns
    }
    
    private func discoverLocationPatterns(notes: [Note]) -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        // Group by location name
        let locationGroups = Dictionary(grouping: notes) { note in
            note.locationName ?? "unknown"
        }
        
        for (location, locationNotes) in locationGroups {
            if locationNotes.count >= 2 && location != "unknown" {
                patterns.append(MemoryPattern(
                    id: UUID(),
                    type: .spatial,
                    description: "Think often at \(location)",
                    strength: Double(locationNotes.count) / Double(notes.count),
                    relatedNotes: locationNotes
                ))
            }
        }
        
        return patterns
    }
    
    private func discoverContentPatterns(notes: [Note]) -> [MemoryPattern] {
        var patterns: [MemoryPattern] = []
        
        // Category frequency patterns
        let categoryGroups = Dictionary(grouping: notes.compactMap { $0.aiCategory }) { $0 }
        
        for (category, instances) in categoryGroups {
            if instances.count >= 3 {
                patterns.append(MemoryPattern(
                    id: UUID(),
                    type: .thematic,
                    description: "Often thinks about \(category)",
                    strength: Double(instances.count) / Double(notes.count),
                    relatedNotes: notes.filter { $0.aiCategory == category }
                ))
            }
        }
        
        return patterns
    }
    
    private func categorizeUncategorized(notes: [Note], context: NSManagedObjectContext) async {
        let uncategorized = notes.filter { $0.aiCategory == nil }
        
        for note in uncategorized {
            guard let content = note.content, !content.isEmpty else { continue }
            
            let result = await categoryService.categorizeNote(content, language: note.supportedLanguage)
            note.aiCategory = result.category
            note.aiConfidence = result.confidence
        }
        
        try? context.save()
    }
    
    // MARK: - Memory Queries
    
    /// Get threads related to a specific note
    func getRelatedThreads(for note: Note) -> [MemoryThread] {
        return discoveredThreads.filter { thread in
            thread.notes.contains { $0.id == note.id }
        }
    }
    
    /// Get forgotten gems - old notes that might be relevant again
    func getForgottenGems(olderThan days: Int = 30) -> [Note] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return discoveredThreads
            .flatMap { $0.notes }
            .filter { note in
                guard let createdAt = note.createdAt else { return false }
                return createdAt < cutoffDate
            }
            .sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
            .prefix(10)
            .map { $0 }
    }
    
    /// Suggest memory review sessions
    func shouldSuggestMemoryReview() -> Bool {
        guard let lastAnalysis = lastAnalysis else { return true }
        
        let daysSinceAnalysis = Date().timeIntervalSince(lastAnalysis) / (24 * 3600)
        return daysSinceAnalysis >= 3 || discoveredThreads.count >= 3
    }
    
    // MARK: - Data Persistence
    
    private func saveMemoryCache() {
        // Save discovered patterns to UserDefaults for quick access
        if let threadsData = try? JSONEncoder().encode(discoveredThreads.map { $0.toCacheData() }) {
            UserDefaults.standard.set(threadsData, forKey: "memoryThreads")
        }
        
        if let patternsData = try? JSONEncoder().encode(memoryPatterns.map { $0.toCacheData() }) {
            UserDefaults.standard.set(patternsData, forKey: "memoryPatterns")
        }
        
        UserDefaults.standard.set(lastAnalysis, forKey: "lastMemoryAnalysis")
    }
    
    private func loadMemoryCache() {
        // Load cached patterns (note references won't be valid, but themes/descriptions will be)
        lastAnalysis = UserDefaults.standard.object(forKey: "lastMemoryAnalysis") as? Date
        
        if let threadsData = UserDefaults.standard.data(forKey: "memoryThreads"),
           let threadCache = try? JSONDecoder().decode([MemoryThreadCache].self, from: threadsData) {
            // Convert cache back to memory threads (without note references for now)
            discoveredThreads = threadCache.map { $0.toMemoryThread() }
        }
        
        if let patternsData = UserDefaults.standard.data(forKey: "memoryPatterns"),
           let patternCache = try? JSONDecoder().decode([MemoryPatternCache].self, from: patternsData) {
            memoryPatterns = patternCache.map { $0.toMemoryPattern() }
        }
    }
    
    private func schedulePeriodicAnalysis() {
        // Run analysis every few hours in background
        Timer.scheduledTimer(withTimeInterval: 3 * 3600, repeats: true) { _ in
            Task {
                // TODO: Get context from app
                // await self.analyzeMemory(context: context)
            }
        }
    }
    
    // MARK: - Utilities
    
    private func fetchAllNotes(context: NSManagedObjectContext) async -> [Note] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
                
                do {
                    let notes = try context.fetch(request)
                    continuation.resume(returning: notes)
                } catch {
                    print("Error fetching notes for memory analysis: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
}

// MARK: - Data Models

/// A discovered thread of related notes across time
class MemoryThread: ObservableObject, Identifiable {
    let id: UUID
    let theme: String
    var notes: [Note]
    let discoveredAt: Date
    var strength: Double
    
    init(id: UUID, theme: String, notes: [Note], discoveredAt: Date, strength: Double) {
        self.id = id
        self.theme = theme
        self.notes = notes
        self.discoveredAt = discoveredAt
        self.strength = strength
    }
    
    var description: String {
        "\(notes.count) notes about \(theme)"
    }
    
    func toCacheData() -> MemoryThreadCache {
        return MemoryThreadCache(
            id: id,
            theme: theme,
            noteCount: notes.count,
            discoveredAt: discoveredAt,
            strength: strength
        )
    }
}

/// Discovered behavioral or content patterns
struct MemoryPattern: Identifiable {
    let id: UUID
    let type: PatternType
    let description: String
    let strength: Double
    let relatedNotes: [Note]
    
    func toCacheData() -> MemoryPatternCache {
        return MemoryPatternCache(
            id: id,
            type: type,
            description: description,
            strength: strength,
            noteCount: relatedNotes.count
        )
    }
}

enum PatternType: String, CaseIterable, Codable {
    case temporal = "temporal"
    case spatial = "spatial"
    case thematic = "thematic"
}

// MARK: - Cache Data Models

struct MemoryThreadCache: Codable {
    let id: UUID
    let theme: String
    let noteCount: Int
    let discoveredAt: Date
    let strength: Double
    
    func toMemoryThread() -> MemoryThread {
        return MemoryThread(
            id: id,
            theme: theme,
            notes: [], // Will be populated when needed
            discoveredAt: discoveredAt,
            strength: strength
        )
    }
}

struct MemoryPatternCache: Codable {
    let id: UUID
    let type: PatternType
    let description: String
    let strength: Double
    let noteCount: Int
    
    func toMemoryPattern() -> MemoryPattern {
        return MemoryPattern(
            id: id,
            type: type,
            description: description,
            strength: strength,
            relatedNotes: [] // Will be populated when needed
        )
    }
}
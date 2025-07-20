import SwiftUI
import CoreData

/// Memory Sessions - Structured review experiences that help users make sense of their scattered thoughts
/// This is the heart of memory augmentation - turning chaos into understanding
struct MemorySessionsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var memoryEngine = MemoryEngine.shared
    @StateObject private var contextualTriggers = ContextualMemoryTriggers.shared
    
    @State private var selectedSession: SessionType?
    @State private var isSessionActive = false
    
    enum SessionType: String, CaseIterable, Identifiable {
        case dailyReview = "daily"
        case weeklyReflection = "weekly"
        case threadExploration = "threads"
        case randomRediscovery = "random"
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .dailyReview: return "Daily Review"
            case .weeklyReflection: return "Weekly Reflection"
            case .threadExploration: return "Thread Deep Dive"
            case .randomRediscovery: return "Random Rediscovery"
            }
        }
        
        var description: String {
            switch self {
            case .dailyReview: return "Make sense of today's scattered thoughts"
            case .weeklyReflection: return "Discover patterns from the past week"
            case .threadExploration: return "Follow your strongest thinking threads"
            case .randomRediscovery: return "Rediscover forgotten gems and connections"
            }
        }
        
        var icon: String {
            switch self {
            case .dailyReview: return "sun.max"
            case .weeklyReflection: return "calendar"
            case .threadExploration: return "link"
            case .randomRediscovery: return "shuffle"
            }
        }
        
        var estimatedTime: String {
            switch self {
            case .dailyReview: return "2-5 min"
            case .weeklyReflection: return "5-10 min"
            case .threadExploration: return "3-8 min"
            case .randomRediscovery: return "2-5 min"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            if isSessionActive, let selectedSession = selectedSession {
                SessionExperienceView(
                    sessionType: selectedSession,
                    onComplete: {
                        isSessionActive = false
                        self.selectedSession = nil
                    }
                )
            } else {
                sessionSelectionView
            }
        }
    }
    
    // MARK: - Session Selection
    
    private var sessionSelectionView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                headerSection
                
                // Contextual suggestions
                if !contextualTriggers.getCurrentMemorySuggestions().isEmpty {
                    contextualSuggestionsSection
                }
                
                // Available sessions
                sessionTypesSection
                
                // Quick insights
                quickInsightsSection
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle("Memory Sessions")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            Task {
                await contextualTriggers.refreshMemoryContext(context: viewContext)
            }
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Make Sense of Your Mind")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Transform scattered thoughts into meaningful insights through guided memory sessions.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var contextualSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggested Right Now")
                .font(.headline)
            
            ForEach(contextualTriggers.getCurrentMemorySuggestions().prefix(2), id: \.id) { trigger in
                ContextualSuggestionCard(trigger: trigger) {
                    // Start relevant session based on trigger type
                    switch trigger.type {
                    case .location, .temporal:
                        selectedSession = .dailyReview
                    case .pattern, .behavioral:
                        selectedSession = .threadExploration
                    case .archaeology:
                        selectedSession = .randomRediscovery
                    }
                    isSessionActive = true
                }
            }
        }
    }
    
    private var sessionTypesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Available Sessions")
                .font(.headline)
            
            ForEach(SessionType.allCases) { sessionType in
                SessionTypeCard(sessionType: sessionType) {
                    selectedSession = sessionType
                    isSessionActive = true
                }
            }
        }
    }
    
    private var quickInsightsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Insights")
                .font(.headline)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InsightCard(
                    icon: "link",
                    title: "\(memoryEngine.discoveredThreads.count)",
                    subtitle: "Active Threads"
                )
                
                InsightCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "\(memoryEngine.memoryPatterns.count)",
                    subtitle: "Patterns Found"
                )
                
                InsightCard(
                    icon: "archivebox",
                    title: "\(memoryEngine.getForgottenGems().count)",
                    subtitle: "Forgotten Gems"
                )
                
                InsightCard(
                    icon: "brain.head.profile",
                    title: memoryEngine.lastAnalysis != nil ? "Active" : "Pending",
                    subtitle: "Memory Analysis"
                )
            }
        }
    }
}

// MARK: - Session Experience View

struct SessionExperienceView: View {
    let sessionType: MemorySessionsView.SessionType
    let onComplete: () -> Void
    
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var memoryEngine = MemoryEngine.shared
    
    @State private var currentStep = 0
    @State private var sessionData: SessionData = SessionData()
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Progress bar
            ProgressView(value: Double(currentStep), total: Double(totalSteps))
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.horizontal)
            
            // Current step content
            currentStepView
            
            Spacer()
            
            // Navigation buttons
            navigationButtons
        }
        .padding()
        .navigationTitle(sessionType.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Exit") {
                    onComplete()
                }
            }
        }
        .onAppear {
            startSession()
        }
    }
    
    private var totalSteps: Int {
        switch sessionType {
        case .dailyReview: return 4
        case .weeklyReflection: return 5
        case .threadExploration: return 3
        case .randomRediscovery: return 3
        }
    }
    
    @ViewBuilder
    private var currentStepView: some View {
        if isLoading {
            LoadingStepView()
        } else {
            switch sessionType {
            case .dailyReview:
                dailyReviewStep
            case .weeklyReflection:
                weeklyReflectionStep
            case .threadExploration:
                threadExplorationStep
            case .randomRediscovery:
                randomRediscoveryStep
            }
        }
    }
    
    // MARK: - Daily Review Steps
    
    @ViewBuilder
    private var dailyReviewStep: some View {
        switch currentStep {
        case 0:
            TodaysNotesStepView(notes: sessionData.todaysNotes)
        case 1:
            EmergingPatternsStepView(patterns: sessionData.emergingPatterns)
        case 2:
            ConnectionsStepView(connections: sessionData.discoveredConnections)
        case 3:
            ReflectionStepView(sessionType: sessionType)
        default:
            CompletionView(sessionType: sessionType, onComplete: onComplete)
        }
    }
    
    // MARK: - Weekly Reflection Steps
    
    @ViewBuilder
    private var weeklyReflectionStep: some View {
        switch currentStep {
        case 0:
            WeekOverviewStepView(notes: sessionData.weekNotes)
        case 1:
            ThreadEvolutionStepView(threads: sessionData.evolvingThreads)
        case 2:
            PatternDiscoveryStepView(patterns: sessionData.weeklyPatterns)
        case 3:
            InsightSynthesisStepView(insights: sessionData.synthesizedInsights)
        case 4:
            ReflectionStepView(sessionType: sessionType)
        default:
            CompletionView(sessionType: sessionType, onComplete: onComplete)
        }
    }
    
    // MARK: - Thread Exploration Steps
    
    @ViewBuilder
    private var threadExplorationStep: some View {
        switch currentStep {
        case 0:
            ThreadSelectionStepView(threads: sessionData.availableThreads)
        case 1:
            ThreadJourneyStepView(thread: sessionData.selectedThread)
        case 2:
            ThreadInsightsStepView(thread: sessionData.selectedThread)
        default:
            CompletionView(sessionType: sessionType, onComplete: onComplete)
        }
    }
    
    // MARK: - Random Rediscovery Steps
    
    @ViewBuilder
    private var randomRediscoveryStep: some View {
        switch currentStep {
        case 0:
            ForgottenGemsStepView(gems: sessionData.forgottenGems)
        case 1:
            SurprisingConnectionsStepView(connections: sessionData.surprisingConnections)
        case 2:
            RediscoveryReflectionStepView(discoveries: sessionData.rediscoveries)
        default:
            CompletionView(sessionType: sessionType, onComplete: onComplete)
        }
    }
    
    private var navigationButtons: some View {
        HStack {
            if currentStep > 0 {
                Button("Previous") {
                    currentStep -= 1
                }
                .buttonStyle(.bordered)
            }
            
            Spacer()
            
            Button(currentStep >= totalSteps - 1 ? "Complete" : "Next") {
                if currentStep >= totalSteps - 1 {
                    onComplete()
                } else {
                    currentStep += 1
                    if shouldLoadDataForStep(currentStep) {
                        loadStepData()
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
    
    // MARK: - Session Logic
    
    private func startSession() {
        isLoading = true
        
        Task {
            await loadInitialSessionData()
            
            await MainActor.run {
                isLoading = false
            }
        }
    }
    
    private func loadInitialSessionData() async {
        switch sessionType {
        case .dailyReview:
            sessionData.todaysNotes = await fetchTodaysNotes()
            sessionData.emergingPatterns = await findEmergingPatterns()
        case .weeklyReflection:
            sessionData.weekNotes = await fetchWeekNotes()
            sessionData.evolvingThreads = await findEvolvingThreads()
        case .threadExploration:
            sessionData.availableThreads = memoryEngine.discoveredThreads
        case .randomRediscovery:
            sessionData.forgottenGems = memoryEngine.getForgottenGems()
            sessionData.surprisingConnections = await findSurprisingConnections()
        }
    }
    
    private func shouldLoadDataForStep(_ step: Int) -> Bool {
        // Some steps require additional data loading
        return false // For now, load all data upfront
    }
    
    private func loadStepData() {
        // Load additional data for specific steps if needed
    }
    
    // MARK: - Data Fetching
    
    private func fetchTodaysNotes() async -> [Note] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                let startOfDay = Calendar.current.startOfDay(for: Date())
                request.predicate = NSPredicate(format: "createdAt >= %@", startOfDay as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
                
                do {
                    let notes = try viewContext.fetch(request)
                    continuation.resume(returning: notes)
                } catch {
                    print("Error fetching today's notes: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func fetchWeekNotes() async -> [Note] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
                request.predicate = NSPredicate(format: "createdAt >= %@", weekAgo as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)]
                
                do {
                    let notes = try viewContext.fetch(request)
                    continuation.resume(returning: notes)
                } catch {
                    print("Error fetching week notes: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func findEmergingPatterns() async -> [MemoryPattern] {
        // Find patterns that are just starting to emerge
        return memoryEngine.memoryPatterns.filter { $0.strength > 0.2 && $0.strength < 0.7 }
    }
    
    private func findEvolvingThreads() async -> [MemoryThread] {
        // Find threads that have grown recently
        return memoryEngine.discoveredThreads.filter { thread in
            thread.notes.count >= 2 && thread.strength > 0.3
        }
    }
    
    private func findSurprisingConnections() async -> [SurprisingConnection] {
        // Find unexpected connections between old and new notes
        // This would use more sophisticated analysis
        return []
    }
}

// MARK: - Supporting Views

struct ContextualSuggestionCard: View {
    let trigger: MemoryTrigger
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: trigger.type.icon)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(trigger.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(trigger.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SessionTypeCard: View {
    let sessionType: MemorySessionsView.SessionType
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: sessionType.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text(sessionType.estimatedTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Text(sessionType.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(sessionType.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct InsightCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

// MARK: - Step Views (Placeholder implementations)

struct LoadingStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Analyzing your memory...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct TodaysNotesStepView: View {
    let notes: [Note]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Thoughts")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("You captured \(notes.count) thoughts today. Let's see what emerged.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Show recent notes
            // Implementation details...
        }
    }
}

// Additional step view implementations would go here...
// For brevity, I'm showing the structure but not implementing every single step view

struct EmergingPatternsStepView: View {
    let patterns: [MemoryPattern]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Emerging Patterns")
                .font(.title2)
                .fontWeight(.bold)
            
            if patterns.isEmpty {
                Text("No new patterns detected yet. Keep capturing thoughts!")
            } else {
                ForEach(patterns, id: \.id) { pattern in
                    Text(pattern.description)
                }
            }
        }
    }
}

struct ConnectionsStepView: View {
    let connections: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Connections")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Connections discovered between your thoughts...")
        }
    }
}

struct ReflectionStepView: View {
    let sessionType: MemorySessionsView.SessionType
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Reflection")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("What insights did you gain from this session?")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}

struct CompletionView: View {
    let sessionType: MemorySessionsView.SessionType
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.green)
            
            Text("Session Complete")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Your memory has been refreshed and connections have been strengthened.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// Placeholder step views for other session types
struct WeekOverviewStepView: View {
    let notes: [Note]
    var body: some View { Text("Week Overview - \(notes.count) notes") }
}

struct ThreadEvolutionStepView: View {
    let threads: [MemoryThread]
    var body: some View { Text("Thread Evolution - \(threads.count) threads") }
}

struct PatternDiscoveryStepView: View {
    let patterns: [MemoryPattern]
    var body: some View { Text("Pattern Discovery") }
}

struct InsightSynthesisStepView: View {
    let insights: [String]
    var body: some View { Text("Insight Synthesis") }
}

struct ThreadSelectionStepView: View {
    let threads: [MemoryThread]
    var body: some View { Text("Select Thread") }
}

struct ThreadJourneyStepView: View {
    let thread: MemoryThread?
    var body: some View { Text("Thread Journey") }
}

struct ThreadInsightsStepView: View {
    let thread: MemoryThread?
    var body: some View { Text("Thread Insights") }
}

struct ForgottenGemsStepView: View {
    let gems: [Note]
    var body: some View { Text("Forgotten Gems - \(gems.count) found") }
}

struct SurprisingConnectionsStepView: View {
    let connections: [SurprisingConnection]
    var body: some View { Text("Surprising Connections") }
}

struct RediscoveryReflectionStepView: View {
    let discoveries: [String]
    var body: some View { Text("Rediscovery Reflection") }
}

// MARK: - Data Models

class SessionData: ObservableObject {
    @Published var todaysNotes: [Note] = []
    @Published var weekNotes: [Note] = []
    @Published var emergingPatterns: [MemoryPattern] = []
    @Published var discoveredConnections: [String] = []
    @Published var evolvingThreads: [MemoryThread] = []
    @Published var weeklyPatterns: [MemoryPattern] = []
    @Published var synthesizedInsights: [String] = []
    @Published var availableThreads: [MemoryThread] = []
    @Published var selectedThread: MemoryThread?
    @Published var forgottenGems: [Note] = []
    @Published var surprisingConnections: [SurprisingConnection] = []
    @Published var rediscoveries: [String] = []
}

struct SurprisingConnection: Identifiable {
    let id = UUID()
    let note1: Note
    let note2: Note
    let connectionReason: String
    let strength: Double
}

// MARK: - Preview

#Preview {
    MemorySessionsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
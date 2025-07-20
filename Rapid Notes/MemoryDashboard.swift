import SwiftUI
import CoreData

/// Memory Dashboard - The central view for exploring thinking patterns and discovered threads
/// This is where users come to understand their mind and see connections across their notes
struct MemoryDashboard: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var memoryEngine = MemoryEngine.shared
    
    @State private var selectedTab: DashboardTab = .overview
    @State private var isAnalyzing = false
    
    enum DashboardTab: String, CaseIterable {
        case overview = "Overview"
        case threads = "Threads"
        case patterns = "Patterns"
        case archaeology = "Archaeology"
        
        var icon: String {
            switch self {
            case .overview: return "brain.head.profile"
            case .threads: return "link"
            case .patterns: return "chart.line.uptrend.xyaxis"
            case .archaeology: return "archivebox"
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Selector
                tabSelector
                
                // Main Content
                TabView(selection: $selectedTab) {
                    overviewTab
                        .tag(DashboardTab.overview)
                    
                    threadsTab
                        .tag(DashboardTab.threads)
                    
                    patternsTab
                        .tag(DashboardTab.patterns)
                    
                    archaeologyTab
                        .tag(DashboardTab.archaeology)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .navigationTitle("Memory")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        refreshMemory()
                    } label: {
                        Image(systemName: isAnalyzing ? "brain.filled.head.profile" : "arrow.clockwise")
                            .foregroundColor(isAnalyzing ? .blue : .primary)
                    }
                    .disabled(isAnalyzing)
                }
            }
        }
        .onAppear {
            if memoryEngine.lastAnalysis == nil {
                refreshMemory()
            }
        }
    }
    
    // MARK: - Tab Selector
    
    private var tabSelector: some View {
        HStack {
            ForEach(DashboardTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .foregroundColor(selectedTab == tab ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
    
    // MARK: - Overview Tab
    
    private var overviewTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Memory Status
                memoryStatusCard
                
                // Quick Stats
                quickStatsCard
                
                // Recent Discoveries
                if !memoryEngine.discoveredThreads.isEmpty {
                    recentDiscoveriesCard
                }
                
                // Memory Suggestions
                memorySuggestionsCard
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    private var memoryStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("Memory Status")
                    .font(.headline)
                Spacer()
            }
            
            if let lastAnalysis = memoryEngine.lastAnalysis {
                Text("Last analyzed: \(lastAnalysis, style: .relative) ago")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("No analysis yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if memoryEngine.shouldSuggestMemoryReview() {
                HStack {
                    Image(systemName: "lightbulb")
                        .foregroundColor(.orange)
                    Text("Ready for memory review")
                        .font(.subheadline)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var quickStatsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Memory")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(
                    icon: "link",
                    value: "\(memoryEngine.discoveredThreads.count)",
                    label: "Threads"
                )
                
                StatItem(
                    icon: "chart.line.uptrend.xyaxis",
                    value: "\(memoryEngine.memoryPatterns.count)",
                    label: "Patterns"
                )
                
                StatItem(
                    icon: "archivebox",
                    value: "\(memoryEngine.getForgottenGems().count)",
                    label: "Gems"
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var recentDiscoveriesCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Discoveries")
                .font(.headline)
            
            ForEach(Array(memoryEngine.discoveredThreads.prefix(3)), id: \.id) { thread in
                ThreadPreviewCard(thread: thread)
            }
            
            if memoryEngine.discoveredThreads.count > 3 {
                Button("View all threads") {
                    selectedTab = .threads
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var memorySuggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Suggestions")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                if memoryEngine.discoveredThreads.isEmpty {
                    MemorySuggestion(
                        icon: "plus.circle",
                        text: "Keep capturing thoughts - patterns will emerge after 5-10 notes",
                        action: nil
                    )
                } else {
                    MemorySuggestion(
                        icon: "archivebox",
                        text: "Check forgotten gems - old ideas that might be relevant again",
                        action: { selectedTab = .archaeology }
                    )
                    
                    if let strongestThread = memoryEngine.discoveredThreads.first {
                        MemorySuggestion(
                            icon: "link",
                            text: "Explore your '\(strongestThread.theme)' thread",
                            action: { selectedTab = .threads }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    // MARK: - Threads Tab
    
    private var threadsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if memoryEngine.discoveredThreads.isEmpty {
                    emptyThreadsView
                } else {
                    ForEach(memoryEngine.discoveredThreads, id: \.id) { thread in
                        ThreadCard(thread: thread)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    private var emptyThreadsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "link")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Threads Yet")
                .font(.headline)
            
            Text("Threads are patterns of related notes across time. Keep capturing thoughts and they'll emerge naturally.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Patterns Tab
    
    private var patternsTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if memoryEngine.memoryPatterns.isEmpty {
                    emptyPatternsView
                } else {
                    ForEach(memoryEngine.memoryPatterns, id: \.id) { pattern in
                        PatternCard(pattern: pattern)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    private var emptyPatternsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Patterns Yet")
                .font(.headline)
            
            Text("Patterns reveal when and where you're most creative. More data needed for insights.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Archaeology Tab
    
    private var archaeologyTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Forgotten Gems")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Old notes that might be relevant again")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                let forgottenGems = memoryEngine.getForgottenGems()
                
                if forgottenGems.isEmpty {
                    emptyArchaeologyView
                } else {
                    ForEach(forgottenGems, id: \.id) { note in
                        ForgottenGemCard(note: note)
                    }
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
    }
    
    private var emptyArchaeologyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "archivebox")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Forgotten Gems")
                .font(.headline)
            
            Text("Your memories are still fresh! Gems appear after notes age for a while.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Actions
    
    private func refreshMemory() {
        isAnalyzing = true
        
        Task {
            await memoryEngine.analyzeMemory(context: viewContext)
            
            await MainActor.run {
                isAnalyzing = false
            }
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(.blue)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ThreadPreviewCard: View {
    let thread: MemoryThread
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(thread.theme.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("\(thread.notes.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct ThreadCard: View {
    let thread: MemoryThread
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(thread.theme.capitalized)
                    .font(.headline)
                
                Spacer()
                
                Text("\(thread.notes.count) notes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
            }
            
            Text(thread.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !thread.notes.isEmpty {
                Text("Recent: \"\(thread.notes.first?.content?.prefix(50) ?? "")...\"")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct PatternCard: View {
    let pattern: MemoryPattern
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: pattern.type.icon)
                    .foregroundColor(.blue)
                
                Text(pattern.description)
                    .font(.headline)
                
                Spacer()
            }
            
            Text(pattern.type.displayName)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ForgottenGemCard: View {
    let note: Note
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let category = note.aiCategory {
                    Text(LocalizedCategory.getIcon(for: category))
                        .font(.caption)
                }
                
                Text(note.content?.prefix(60) ?? "")
                    .font(.subheadline)
                    .lineLimit(2)
                
                Spacer()
            }
            
            HStack {
                if let date = note.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let location = note.locationName {
                    Text("• \(location)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
    }
}

struct MemorySuggestion: View {
    let icon: String
    let text: String
    let action: (() -> Void)?
    
    var body: some View {
        Button {
            action?()
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                
                Text(text)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(action == nil)
    }
}

// MARK: - Extensions

extension PatternType {
    var icon: String {
        switch self {
        case .temporal: return "clock"
        case .spatial: return "location"
        case .thematic: return "tag"
        }
    }
    
    var displayName: String {
        switch self {
        case .temporal: return "Time Pattern"
        case .spatial: return "Location Pattern"
        case .thematic: return "Theme Pattern"
        }
    }
}

// MARK: - Preview

#Preview {
    MemoryDashboard()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
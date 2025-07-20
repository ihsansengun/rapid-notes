import Foundation
import CoreLocation
import CoreData

/// Contextual memory triggers that surface relevant memories based on location, time, and behavioral patterns
/// This is the ambient intelligence that makes memory augmentation feel magical
@MainActor
class ContextualMemoryTriggers: NSObject, ObservableObject {
    static let shared = ContextualMemoryTriggers()
    
    private let memoryEngine = MemoryEngine.shared
    private let locationManager = CLLocationManager()
    
    @Published var currentTriggers: [MemoryTrigger] = []
    @Published var pendingNotifications: [MemoryNotification] = []
    
    // Context tracking
    @Published var currentLocation: CLLocation?
    @Published var currentLocationName: String?
    @Published var timeContext: TimeContext = .unknown
    
    private override init() {
        super.init()
        setupLocationTracking()
        setupTimeContextTracking()
        loadCachedTriggers()
    }
    
    // MARK: - Context Tracking
    
    private func setupLocationTracking() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        
        // Request permission if not already granted
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationTracking()
        default:
            break
        }
    }
    
    private func startLocationTracking() {
        locationManager.startUpdatingLocation()
        locationManager.startMonitoringSignificantLocationChanges()
    }
    
    private func setupTimeContextTracking() {
        // Update time context every hour
        Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            Task {
                await self.updateTimeContext()
            }
        }
        
        Task {
            await updateTimeContext()
        }
    }
    
    private func updateTimeContext() {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 6..<9:
            timeContext = .morning
        case 9..<12:
            timeContext = .workMorning
        case 12..<14:
            timeContext = .lunch
        case 14..<17:
            timeContext = .workAfternoon
        case 17..<20:
            timeContext = .evening
        case 20..<23:
            timeContext = .nighttime
        default:
            timeContext = .lateNight
        }
        
        // Trigger context-based memory suggestions
        Task {
            await evaluateTimeBasedTriggers()
        }
    }
    
    // MARK: - Memory Trigger Evaluation
    
    /// Evaluate all possible memory triggers based on current context
    func evaluateAllTriggers(context: NSManagedObjectContext) async {
        var newTriggers: [MemoryTrigger] = []
        
        // Location-based triggers
        newTriggers.append(contentsOf: await evaluateLocationTriggers(context: context))
        
        // Time-based triggers
        newTriggers.append(contentsOf: await evaluateTimeBasedTriggers())
        
        // Pattern-based triggers
        newTriggers.append(contentsOf: await evaluatePatternTriggers(context: context))
        
        // Behavioral triggers
        newTriggers.append(contentsOf: await evaluateBehavioralTriggers(context: context))
        
        // Update UI
        currentTriggers = newTriggers.sorted { $0.relevanceScore > $1.relevanceScore }
        
        // Generate notifications for high-priority triggers
        generateNotifications(from: newTriggers)
    }
    
    private func evaluateLocationTriggers(context: NSManagedObjectContext) async -> [MemoryTrigger] {
        guard let location = currentLocation else { return [] }
        
        var triggers: [MemoryTrigger] = []
        
        // Find notes from this location
        let nearbyNotes = await fetchNotesNear(location: location, context: context)
        
        if !nearbyNotes.isEmpty {
            triggers.append(MemoryTrigger(
                id: UUID(),
                type: .location,
                title: "Memories from here",
                description: "You've had \(nearbyNotes.count) thoughts at this location",
                relevanceScore: Double(nearbyNotes.count) * 0.8,
                relatedNotes: nearbyNotes,
                context: currentLocationName ?? "this location"
            ))
        }
        
        // Check for location patterns
        if let locationName = currentLocationName {
            let locationPatterns = memoryEngine.memoryPatterns.filter { 
                $0.type == .spatial && $0.description.contains(locationName) 
            }
            
            for pattern in locationPatterns {
                triggers.append(MemoryTrigger(
                    id: UUID(),
                    type: .pattern,
                    title: "Your \(locationName) pattern",
                    description: pattern.description,
                    relevanceScore: pattern.strength,
                    relatedNotes: pattern.relatedNotes,
                    context: locationName
                ))
            }
        }
        
        return triggers
    }
    
    private func evaluateTimeBasedTriggers() async -> [MemoryTrigger] {
        var triggers: [MemoryTrigger] = []
        
        // Check for time-based patterns
        let timePatterns = memoryEngine.memoryPatterns.filter { $0.type == .temporal }
        
        let currentHour = Calendar.current.component(.hour, from: Date())
        
        for pattern in timePatterns {
            // Extract hour from pattern description if possible
            if pattern.description.contains("\(currentHour):00") {
                triggers.append(MemoryTrigger(
                    id: UUID(),
                    type: .temporal,
                    title: "Your \(timeContext.displayName) creativity",
                    description: pattern.description,
                    relevanceScore: pattern.strength * 1.2, // Boost current time patterns
                    relatedNotes: pattern.relatedNotes,
                    context: timeContext.displayName
                ))
            }
        }
        
        // Check for "same time last week/month/year"
        let historicalNotes = await findHistoricalNotes()
        if !historicalNotes.isEmpty {
            triggers.append(MemoryTrigger(
                id: UUID(),
                type: .temporal,
                title: "Same time, different day",
                description: "You had similar thoughts around this time before",
                relevanceScore: 0.6,
                relatedNotes: historicalNotes,
                context: "historical"
            ))
        }
        
        return triggers
    }
    
    private func evaluatePatternTriggers(context: NSManagedObjectContext) async -> [MemoryTrigger] {
        var triggers: [MemoryTrigger] = []
        
        // Check for strong thematic patterns
        let thematicPatterns = memoryEngine.memoryPatterns.filter { 
            $0.type == .thematic && $0.strength > 0.3 
        }
        
        for pattern in thematicPatterns {
            triggers.append(MemoryTrigger(
                id: UUID(),
                type: .pattern,
                title: "Your \(pattern.description.lowercased()) thread",
                description: "You've been exploring this theme recently",
                relevanceScore: pattern.strength,
                relatedNotes: pattern.relatedNotes,
                context: "thematic"
            ))
        }
        
        return triggers
    }
    
    private func evaluateBehavioralTriggers(context: NSManagedObjectContext) async -> [MemoryTrigger] {
        var triggers: [MemoryTrigger] = []
        
        // Check for forgotten threads that haven't been updated recently
        let staleThreads = memoryEngine.discoveredThreads.filter { thread in
            guard let lastNoteDate = thread.notes.compactMap({ $0.createdAt }).max() else { return false }
            let daysSinceUpdate = Date().timeIntervalSince(lastNoteDate) / (24 * 3600)
            return daysSinceUpdate >= 7 && thread.strength > 0.3
        }
        
        for thread in staleThreads {
            triggers.append(MemoryTrigger(
                id: UUID(),
                type: .behavioral,
                title: "Quiet thread: \(thread.theme)",
                description: "This thread hasn't seen activity for a while",
                relevanceScore: thread.strength * 0.7,
                relatedNotes: thread.notes,
                context: "dormant"
            ))
        }
        
        // Check for memory archaeology opportunities
        let forgottenGems = memoryEngine.getForgottenGems()
        if !forgottenGems.isEmpty {
            triggers.append(MemoryTrigger(
                id: UUID(),
                type: .archaeology,
                title: "Forgotten gems",
                description: "Old ideas that might be relevant again",
                relevanceScore: 0.5,
                relatedNotes: forgottenGems,
                context: "archaeology"
            ))
        }
        
        return triggers
    }
    
    // MARK: - Notification Generation
    
    private func generateNotifications(from triggers: [MemoryTrigger]) {
        // Only generate notifications for high-relevance triggers
        let highPriorityTriggers = triggers.filter { $0.relevanceScore > 0.7 }
        
        for trigger in highPriorityTriggers.prefix(3) { // Max 3 notifications at once
            let notification = MemoryNotification(
                id: UUID(),
                trigger: trigger,
                scheduledFor: Date(),
                delivered: false
            )
            
            if !pendingNotifications.contains(where: { $0.trigger.id == trigger.id }) {
                pendingNotifications.append(notification)
            }
        }
        
        // Schedule actual system notifications
        scheduleSystemNotifications()
    }
    
    private func scheduleSystemNotifications() {
        // TODO: Implement actual push notifications
        // For now, just mark as ready for in-app display
        for notification in pendingNotifications.filter({ !$0.delivered }) {
            print("🧠 Memory Trigger: \(notification.trigger.title) - \(notification.trigger.description)")
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchNotesNear(location: CLLocation, context: NSManagedObjectContext) async -> [Note] {
        return await withCheckedContinuation { continuation in
            context.perform {
                let request: NSFetchRequest<Note> = Note.fetchRequest()
                
                do {
                    let allNotes = try context.fetch(request)
                    let nearbyNotes = allNotes.filter { note in
                        let noteLocation = CLLocation(latitude: note.latitude, longitude: note.longitude)
                        return location.distance(from: noteLocation) < 500 // Within 500m
                    }
                    continuation.resume(returning: nearbyNotes)
                } catch {
                    print("Error fetching nearby notes: \(error)")
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    private func findHistoricalNotes() async -> [Note] {
        // Find notes from same time of day/week in the past
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        let currentWeekday = calendar.component(.weekday, from: now)
        
        // This would need Core Data implementation to filter by time patterns
        // For now, return empty - could be implemented with custom predicates
        return []
    }
    
    // MARK: - Cache Management
    
    private func loadCachedTriggers() {
        // Load cached triggers from UserDefaults
        // This would help maintain context across app launches
    }
    
    private func saveCachedTriggers() {
        // Save current triggers for quick access on next launch
    }
    
    // MARK: - Public Interface
    
    /// Manually trigger memory evaluation (called when app becomes active)
    func refreshMemoryContext(context: NSManagedObjectContext) async {
        await evaluateAllTriggers(context: context)
    }
    
    /// Get current high-priority memory suggestions
    func getCurrentMemorySuggestions() -> [MemoryTrigger] {
        return currentTriggers.filter { $0.relevanceScore > 0.5 }.prefix(5).map { $0 }
    }
    
    /// Mark a trigger as acknowledged (so it doesn't keep appearing)
    func acknowledgeTrigger(_ trigger: MemoryTrigger) {
        currentTriggers.removeAll { $0.id == trigger.id }
        pendingNotifications.removeAll { $0.trigger.id == trigger.id }
    }
}

// MARK: - Location Manager Delegate

extension ContextualMemoryTriggers: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Reverse geocode to get location name
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            if let placemark = placemarks?.first {
                Task { @MainActor in
                    self?.currentLocationName = placemark.name ?? placemark.locality
                    
                    // Trigger location-based memory evaluation
                    // TODO: Pass context here
                    // await self?.evaluateAllTriggers(context: context)
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationTracking()
        default:
            break
        }
    }
}

// MARK: - Data Models

struct MemoryTrigger: Identifiable, Equatable {
    let id: UUID
    let type: TriggerType
    let title: String
    let description: String
    let relevanceScore: Double
    let relatedNotes: [Note]
    let context: String
    
    static func == (lhs: MemoryTrigger, rhs: MemoryTrigger) -> Bool {
        lhs.id == rhs.id
    }
}

struct MemoryNotification: Identifiable {
    let id: UUID
    let trigger: MemoryTrigger
    let scheduledFor: Date
    var delivered: Bool
}

enum TriggerType: String, CaseIterable {
    case location = "location"
    case temporal = "temporal"
    case pattern = "pattern"
    case behavioral = "behavioral"
    case archaeology = "archaeology"
    
    var icon: String {
        switch self {
        case .location: return "location"
        case .temporal: return "clock"
        case .pattern: return "chart.line.uptrend.xyaxis"
        case .behavioral: return "brain.head.profile"
        case .archaeology: return "archivebox"
        }
    }
}

enum TimeContext: String, CaseIterable {
    case morning = "morning"
    case workMorning = "work_morning"
    case lunch = "lunch"
    case workAfternoon = "work_afternoon"
    case evening = "evening"
    case nighttime = "nighttime"
    case lateNight = "late_night"
    case unknown = "unknown"
    
    var displayName: String {
        switch self {
        case .morning: return "Morning"
        case .workMorning: return "Work Morning"
        case .lunch: return "Lunch"
        case .workAfternoon: return "Work Afternoon"
        case .evening: return "Evening"
        case .nighttime: return "Night"
        case .lateNight: return "Late Night"
        case .unknown: return "Unknown"
        }
    }
}
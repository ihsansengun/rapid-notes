import Foundation
import EventKit

/// Service for detecting time-based reminders and integrating with system reminders
@MainActor
class ReminderService: ObservableObject {
    static let shared = ReminderService()
    
    private let eventStore = EKEventStore()
    private let languageService = LanguageService.shared
    private let aiMemoryService = AIMemoryService()
    
    @Published var hasReminderAccess = false
    @Published var pendingReminders: [DetectedReminder] = []
    
    private init() {
        checkReminderAccess()
    }
    
    // MARK: - Reminder Detection
    
    /// Detect reminder phrases in note content
    func detectReminders(in content: String, language: SupportedLanguage? = nil) async -> [DetectedReminder] {
        let analysisLanguage = language ?? languageService.currentLanguage
        
        // Use AI service for advanced reminder detection
        if let aiReminder = await aiMemoryService.suggestReminder(content, language: analysisLanguage) {
            return [DetectedReminder(
                originalPhrase: aiReminder.originalPhrase,
                timeReference: aiReminder.timeReference,
                suggestedDateTime: parseTimeReference(aiReminder.suggestedTiming, language: analysisLanguage),
                confidence: aiReminder.confidence,
                content: content,
                language: analysisLanguage,
                source: .aiDetection
            )]
        }
        
        // Fallback to rule-based detection
        return detectWithRules(content, language: analysisLanguage)
    }
    
    /// Suggest optimal reminder time based on content and context
    func suggestReminderTime(for content: String, language: SupportedLanguage? = nil) -> Date? {
        let analysisLanguage = language ?? languageService.currentLanguage
        let patterns = getTimePatterns(for: analysisLanguage)
        let lowercaseContent = content.lowercased()
        
        for (pattern, timeInfo) in patterns {
            if lowercaseContent.contains(pattern) {
                return calculateDateTime(from: timeInfo)
            }
        }
        
        // Default suggestion based on time of day
        return getSmartDefaultTime()
    }
    
    /// Create system reminder from detected reminder
    func createSystemReminder(_ detectedReminder: DetectedReminder) async -> Bool {
        guard hasReminderAccess else {
            await requestReminderAccess()
            return false
        }
        
        let reminder = EKReminder(eventStore: eventStore)
        reminder.title = detectedReminder.content
        reminder.notes = "Created from voice note: \"\(detectedReminder.originalPhrase)\""
        
        if let dateTime = detectedReminder.suggestedDateTime {
            let alarm = EKAlarm(absoluteDate: dateTime)
            reminder.addAlarm(alarm)
        }
        
        // Set calendar (default reminders list)
        reminder.calendar = eventStore.defaultCalendarForNewReminders()
        
        do {
            try eventStore.save(reminder, commit: true)
            return true
        } catch {
            print("Error creating system reminder: \(error)")
            return false
        }
    }
    
    /// Batch process notes for reminder detection
    func processNotesForReminders(_ notes: [Note]) async {
        var newReminders: [DetectedReminder] = []
        
        for note in notes {
            guard let content = note.content, !content.isEmpty else { continue }
            
            let detectedReminders = await detectReminders(in: content, language: note.supportedLanguage)
            newReminders.append(contentsOf: detectedReminders)
            
            // Update note with reminder suggestions
            if let firstReminder = detectedReminders.first {
                note.aiReminderSuggestion = firstReminder.timeReference
            }
        }
        
        pendingReminders.append(contentsOf: newReminders)
    }
    
    // MARK: - Rule-based Detection
    
    private func detectWithRules(_ content: String, language: SupportedLanguage) -> [DetectedReminder] {
        let lowercaseContent = content.lowercased()
        let patterns = getTimePatterns(for: language)
        var detectedReminders: [DetectedReminder] = []
        
        for (pattern, timeInfo) in patterns {
            if lowercaseContent.contains(pattern) {
                let suggestedTime = calculateDateTime(from: timeInfo)
                let confidence = getPatternConfidence(pattern, in: lowercaseContent)
                
                detectedReminders.append(DetectedReminder(
                    originalPhrase: pattern,
                    timeReference: timeInfo.description,
                    suggestedDateTime: suggestedTime,
                    confidence: confidence,
                    content: content,
                    language: language,
                    source: .ruleBasedDetection
                ))
            }
        }
        
        return detectedReminders
    }
    
    private func getTimePatterns(for language: SupportedLanguage) -> [String: TimeInfo] {
        switch language {
        case .english:
            return [
                "tonight": TimeInfo(type: .today, hour: 20, description: "Tonight at 8:00 PM"),
                "tomorrow": TimeInfo(type: .tomorrow, hour: 9, description: "Tomorrow at 9:00 AM"),
                "next week": TimeInfo(type: .nextWeek, hour: 9, description: "Next Monday at 9:00 AM"),
                "later": TimeInfo(type: .relative, hour: 2, description: "In 2 hours"),
                "morning": TimeInfo(type: .nextMorning, hour: 9, description: "Tomorrow morning at 9:00 AM"),
                "afternoon": TimeInfo(type: .today, hour: 15, description: "This afternoon at 3:00 PM"),
                "evening": TimeInfo(type: .today, hour: 18, description: "This evening at 6:00 PM"),
                "friday": TimeInfo(type: .nextWeekday, hour: 9, weekday: 6, description: "This Friday at 9:00 AM"),
                "monday": TimeInfo(type: .nextWeekday, hour: 9, weekday: 2, description: "This Monday at 9:00 AM"),
                "in an hour": TimeInfo(type: .relative, hour: 1, description: "In 1 hour"),
                "in 30 minutes": TimeInfo(type: .relative, minute: 30, description: "In 30 minutes"),
                "next month": TimeInfo(type: .nextMonth, hour: 9, description: "Next month"),
                "end of week": TimeInfo(type: .endOfWeek, hour: 17, description: "End of this week")
            ]
        case .turkish:
            return [
                "bu akşam": TimeInfo(type: .today, hour: 20, description: "Bu akşam saat 20:00"),
                "yarın": TimeInfo(type: .tomorrow, hour: 9, description: "Yarın saat 09:00"),
                "gelecek hafta": TimeInfo(type: .nextWeek, hour: 9, description: "Gelecek Pazartesi saat 09:00"),
                "sonra": TimeInfo(type: .relative, hour: 2, description: "2 saat sonra"),
                "sabah": TimeInfo(type: .nextMorning, hour: 9, description: "Yarın sabah 09:00"),
                "öğleden sonra": TimeInfo(type: .today, hour: 15, description: "Bugün öğleden sonra 15:00"),
                "akşam": TimeInfo(type: .today, hour: 18, description: "Bu akşam 18:00"),
                "cuma": TimeInfo(type: .nextWeekday, hour: 9, weekday: 6, description: "Bu Cuma saat 09:00"),
                "pazartesi": TimeInfo(type: .nextWeekday, hour: 9, weekday: 2, description: "Bu Pazartesi saat 09:00"),
                "bir saat sonra": TimeInfo(type: .relative, hour: 1, description: "1 saat sonra"),
                "30 dakika sonra": TimeInfo(type: .relative, minute: 30, description: "30 dakika sonra"),
                "gelecek ay": TimeInfo(type: .nextMonth, hour: 9, description: "Gelecek ay"),
                "hafta sonu": TimeInfo(type: .endOfWeek, hour: 17, description: "Hafta sonu")
            ]
        case .spanish:
            return [
                "esta noche": TimeInfo(type: .today, hour: 20, description: "Esta noche a las 20:00"),
                "mañana": TimeInfo(type: .tomorrow, hour: 9, description: "Mañana a las 09:00"),
                "próxima semana": TimeInfo(type: .nextWeek, hour: 9, description: "Próximo lunes a las 09:00"),
                "más tarde": TimeInfo(type: .relative, hour: 2, description: "En 2 horas"),
                "por la mañana": TimeInfo(type: .nextMorning, hour: 9, description: "Mañana por la mañana a las 09:00"),
                "por la tarde": TimeInfo(type: .today, hour: 15, description: "Esta tarde a las 15:00"),
                "por la noche": TimeInfo(type: .today, hour: 18, description: "Esta noche a las 18:00"),
                "viernes": TimeInfo(type: .nextWeekday, hour: 9, weekday: 6, description: "Este viernes a las 09:00"),
                "lunes": TimeInfo(type: .nextWeekday, hour: 9, weekday: 2, description: "Este lunes a las 09:00")
            ]
        default:
            return [
                "tonight": TimeInfo(type: .today, hour: 20, description: "Tonight at 8:00 PM"),
                "tomorrow": TimeInfo(type: .tomorrow, hour: 9, description: "Tomorrow at 9:00 AM"),
                "later": TimeInfo(type: .relative, hour: 2, description: "In 2 hours")
            ]
        }
    }
    
    private func calculateDateTime(from timeInfo: TimeInfo) -> Date? {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeInfo.type {
        case .today:
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: now)
            
        case .tomorrow:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: tomorrow)
            
        case .nextMorning:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow)
            
        case .nextWeek:
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: now) else { return nil }
            let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: nextWeek)?.start ?? nextWeek
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: startOfWeek)
            
        case .nextWeekday:
            let weekday = timeInfo.weekday
            let currentWeekday = calendar.component(.weekday, from: now)
            let daysToAdd = weekday > currentWeekday ? weekday - currentWeekday : 7 - currentWeekday + weekday
            
            guard let targetDay = calendar.date(byAdding: .day, value: daysToAdd, to: now) else { return nil }
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: targetDay)
            
        case .nextMonth:
            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: now) else { return nil }
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: nextMonth)
            
        case .endOfWeek:
            guard let endOfWeek = calendar.date(byAdding: .day, value: 7 - calendar.component(.weekday, from: now), to: now) else { return nil }
            return calendar.date(bySettingHour: timeInfo.hour, minute: timeInfo.minute, second: 0, of: endOfWeek)
            
        case .relative:
            if timeInfo.hour > 0 {
                return calendar.date(byAdding: .hour, value: timeInfo.hour, to: now)
            } else if timeInfo.minute > 0 {
                return calendar.date(byAdding: .minute, value: timeInfo.minute, to: now)
            }
            return nil
        }
    }
    
    private func parseTimeReference(_ reference: String, language: SupportedLanguage) -> Date? {
        // Try to parse common time formats from AI suggestions
        let patterns = getTimePatterns(for: language)
        
        for (_, timeInfo) in patterns {
            if reference.lowercased().contains(timeInfo.description.lowercased()) {
                return calculateDateTime(from: timeInfo)
            }
        }
        
        // Try to parse specific times like "3:00 PM", "15:00"
        if let specificTime = parseSpecificTime(reference) {
            return specificTime
        }
        
        return nil
    }
    
    private func parseSpecificTime(_ timeString: String) -> Date? {
        let timeFormats = [
            "h:mm a",    // 3:00 PM
            "HH:mm",     // 15:00
            "h a",       // 3 PM
            "h:mm",      // 3:00
        ]
        
        let dateFormatter = DateFormatter()
        let calendar = Calendar.current
        let today = Date()
        
        for format in timeFormats {
            dateFormatter.dateFormat = format
            if let time = dateFormatter.date(from: timeString) {
                let hour = calendar.component(.hour, from: time)
                let minute = calendar.component(.minute, from: time)
                
                if let scheduledTime = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) {
                    // If the time has already passed today, schedule for tomorrow
                    if scheduledTime < Date() {
                        return calendar.date(byAdding: .day, value: 1, to: scheduledTime)
                    }
                    return scheduledTime
                }
            }
        }
        
        return nil
    }
    
    private func getPatternConfidence(_ pattern: String, in content: String) -> Double {
        let words = content.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
        let exactMatch = words.contains(where: { $0.lowercased() == pattern.lowercased() })
        
        if exactMatch {
            return 0.9
        } else if content.lowercased().contains(pattern) {
            return 0.7
        } else {
            return 0.5
        }
    }
    
    private func getSmartDefaultTime() -> Date {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)
        
        // Suggest times based on current time of day
        if currentHour < 12 {
            // Morning: suggest afternoon
            return calendar.date(bySettingHour: 15, minute: 0, second: 0, of: now) ?? now
        } else if currentHour < 17 {
            // Afternoon: suggest evening
            return calendar.date(bySettingHour: 19, minute: 0, second: 0, of: now) ?? now
        } else {
            // Evening: suggest tomorrow morning
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return calendar.date(bySettingHour: 9, minute: 0, second: 0, of: tomorrow) ?? now
        }
    }
    
    // MARK: - Permissions
    
    private func checkReminderAccess() {
        if #available(macOS 14.0, iOS 17.0, *) {
            let status = EKEventStore.authorizationStatus(for: .reminder)
            hasReminderAccess = status == .fullAccess
        } else {
            let status = EKEventStore.authorizationStatus(for: .reminder)
            hasReminderAccess = status == .authorized
        }
    }
    
    private func requestReminderAccess() async {
        do {
            if #available(macOS 14.0, iOS 17.0, *) {
                let status = try await eventStore.requestFullAccessToReminders()
                await MainActor.run {
                    hasReminderAccess = status
                }
            } else {
                let status = try await eventStore.requestAccess(to: .reminder)
                await MainActor.run {
                    hasReminderAccess = status
                }
            }
        } catch {
            print("Error requesting reminder access: \(error)")
            await MainActor.run {
                hasReminderAccess = false
            }
        }
    }
    
    // MARK: - Reminder Management
    
    func dismissReminder(_ reminder: DetectedReminder) {
        pendingReminders.removeAll { $0.id == reminder.id }
    }
    
    func dismissAllReminders() {
        pendingReminders.removeAll()
    }
    
    func getUpcomingReminders() -> [DetectedReminder] {
        return pendingReminders.filter { reminder in
            guard let dateTime = reminder.suggestedDateTime else { return true }
            return dateTime > Date()
        }
    }
}

// MARK: - Data Models

struct DetectedReminder: Identifiable {
    let id = UUID()
    let originalPhrase: String
    let timeReference: String
    let suggestedDateTime: Date?
    let confidence: Double
    let content: String
    let language: SupportedLanguage
    let source: ReminderSource
    
    var isHighConfidence: Bool {
        return confidence >= 0.7
    }
    
    var formattedDateTime: String {
        guard let dateTime = suggestedDateTime else { return timeReference }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: dateTime)
    }
}

struct TimeInfo {
    let type: TimeType
    let hour: Int
    let minute: Int
    let weekday: Int // 1 = Sunday, 2 = Monday, etc.
    let description: String
    
    init(type: TimeType, hour: Int = 0, minute: Int = 0, weekday: Int = 0, description: String) {
        self.type = type
        self.hour = hour
        self.minute = minute
        self.weekday = weekday
        self.description = description
    }
}

enum TimeType {
    case today
    case tomorrow
    case nextMorning
    case nextWeek
    case nextWeekday
    case nextMonth
    case endOfWeek
    case relative
}

enum ReminderSource {
    case aiDetection
    case ruleBasedDetection
    case userManual
    
    var displayName: String {
        switch self {
        case .aiDetection: return "AI Detected"
        case .ruleBasedDetection: return "Pattern Detected"
        case .userManual: return "Manual"
        }
    }
}
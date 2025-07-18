import WidgetKit
import SwiftUI

struct QuickDumpWidget: Widget {
    let kind: String = "QuickDumpWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickDumpWidgetProvider()) { entry in
            QuickDumpWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Quick Note")
        .description("Instantly capture notes with voice or text")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}

struct QuickDumpWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickDumpWidgetEntry {
        QuickDumpWidgetEntry(date: Date(), lastNotePreview: "Tap to create your first note")
    }
    
    func getSnapshot(in context: Context, completion: @escaping (QuickDumpWidgetEntry) -> ()) {
        let entry = QuickDumpWidgetEntry(date: Date(), lastNotePreview: "Tap to create a quick note")
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuickDumpWidgetEntry>) -> ()) {
        let currentDate = Date()
        
        // Try to get the last note from shared UserDefaults
        let lastNotePreview = getLastNotePreview()
        
        let entry = QuickDumpWidgetEntry(
            date: currentDate,
            lastNotePreview: lastNotePreview
        )
        
        // Update the widget every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate)!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
    
    private func getLastNotePreview() -> String {
        // Access shared UserDefaults using App Groups
        if let sharedDefaults = UserDefaults(suiteName: "group.Theory-of-Web.Rapid-Notes") {
            return sharedDefaults.string(forKey: "lastNotePreview") ?? "Ready to capture your thoughts..."
        }
        return "Ready to capture your thoughts..."
    }
}

struct QuickDumpWidgetEntry: TimelineEntry {
    let date: Date
    let lastNotePreview: String
}

struct QuickDumpWidgetEntryView: View {
    var entry: QuickDumpWidgetProvider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            systemSmallView
        case .systemMedium:
            systemMediumView
        case .accessoryInline:
            accessoryInlineView
        case .accessoryRectangular:
            accessoryRectangularView
        default:
            systemSmallView
        }
    }
    
    // MARK: - System Small Widget (Home Screen)
    private var systemSmallView: some View {
        VStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Quick Note")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text("Tap to record")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .containerBackground(for: .widget) {
            quickNoteGradient
        }
        .widgetURL(URL(string: "quickdump://new-note"))
    }
    
    // MARK: - System Medium Widget (Home Screen)
    private var systemMediumView: some View {
        HStack(spacing: 16) {
            // Quick Note Button
            VStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                
                Text("New Note")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(quickNoteGradient)
            .cornerRadius(12)
            
            // Recent Note Preview
            VStack(alignment: .leading, spacing: 4) {
                Text("Recent")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                
                Text(entry.lastNotePreview)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    
                    Text(entry.date.formatted(.relative(presentation: .named)))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding(4)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "quickdump://new-note"))
    }
    
    // MARK: - Accessory Inline Widget (Lock Screen)
    private var accessoryInlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: "mic.fill")
                .font(.system(size: 12))
            
            Text("Quick Note")
                .font(.system(size: 12, weight: .medium))
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "quickdump://new-note"))
    }
    
    // MARK: - Accessory Rectangular Widget (Lock Screen)
    private var accessoryRectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "mic.fill")
                    .font(.system(size: 12))
                
                Text("QuickDump")
                    .font(.system(size: 12, weight: .semibold))
                
                Spacer()
            }
            
            Text("Tap to record")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
            
            Text("or type a note")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(for: .widget) {
            Color.clear
        }
        .widgetURL(URL(string: "quickdump://new-note"))
    }
    
    // MARK: - Helper Views
    private var quickNoteGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.blue.opacity(0.8),
                Color.purple.opacity(0.8)
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    QuickDumpWidget()
} timeline: {
    QuickDumpWidgetEntry(date: .now, lastNotePreview: "Remember to buy groceries")
    QuickDumpWidgetEntry(date: .now.addingTimeInterval(3600), lastNotePreview: "Meeting with John at 3pm")
}

#Preview(as: .systemMedium) {
    QuickDumpWidget()
} timeline: {
    QuickDumpWidgetEntry(date: .now, lastNotePreview: "Remember to buy groceries for dinner party tonight")
}

#Preview(as: .accessoryInline) {
    QuickDumpWidget()
} timeline: {
    QuickDumpWidgetEntry(date: .now, lastNotePreview: "")
}

#Preview(as: .accessoryRectangular) {
    QuickDumpWidget()
} timeline: {
    QuickDumpWidgetEntry(date: .now, lastNotePreview: "")
}
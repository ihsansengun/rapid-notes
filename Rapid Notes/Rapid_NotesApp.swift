//
//  Rapid_NotesApp.swift
//  Rapid Notes
//
//  Created by FF on 17/07/2025.
//

import SwiftUI

@main
struct Rapid_NotesApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var connectivityManager = PhoneConnectivityManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(persistenceController)
                .environmentObject(connectivityManager)
                .onOpenURL { url in
                    handleDeepLink(url: url)
                }
                .onAppear {
                    connectivityManager.configure(with: persistenceController.container.viewContext)
                    // Initialize Config defaults
                    Config.initializeDefaults()
                    // Debug OpenAI configuration
                    Config.debugConfiguration()
                }
        }
    }
    
    private func handleDeepLink(url: URL) {
        let urlString = url.absoluteString
        
        // Widget launches
        if urlString.contains("/new-note") {
            let userInfo: [String: Any] = [
                "source": "widget",
                "autoStartRecording": true,
                "preferredMode": "voice"
            ]
            NotificationCenter.default.post(name: .openNewNote, object: nil, userInfo: userInfo)
        }
        else if urlString.contains("/new-voice-note") {
            let userInfo: [String: Any] = [
                "source": "widget",
                "autoStartRecording": true,
                "preferredMode": "voice"
            ]
            NotificationCenter.default.post(name: .openNewNote, object: nil, userInfo: userInfo)
        }
        else if urlString.contains("/new-text-note") {
            let userInfo: [String: Any] = [
                "source": "widget",
                "autoStartRecording": false,
                "preferredMode": "text"
            ]
            NotificationCenter.default.post(name: .openNewNote, object: nil, userInfo: userInfo)
        }
        else if urlString.contains("/notes") {
            // Deep link to notes list
            let userInfo: [String: Any] = ["source": "widget"]
            NotificationCenter.default.post(name: .openNotesList, object: nil, userInfo: userInfo)
        }
    }
}

extension Notification.Name {
    static let openNewNote = Notification.Name("openNewNote")
    static let openNotesList = Notification.Name("openNotesList")
}

import Foundation
import CoreData
import Combine
#if canImport(UIKit)
import UIKit
#endif
#if canImport(WidgetKit)
import WidgetKit
#endif
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif

class PhoneConnectivityManager: NSObject, ObservableObject {
    @Published var isConnected = false
    @Published var isWatchReachable = false
    
    #if canImport(WatchConnectivity)
    private var session: WCSession?
    #endif
    private var viewContext: NSManagedObjectContext?
    
    override init() {
        super.init()
        setupConnectivity()
    }
    
    func configure(with context: NSManagedObjectContext) {
        self.viewContext = context
    }
    
    private func setupConnectivity() {
        #if canImport(WatchConnectivity)
        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
        #endif
    }
    
    func sendPingToWatch() {
        #if canImport(WatchConnectivity)
        guard let session = session,
              session.isReachable else { return }
        
        let message: [String: Any] = [
            "type": "ping",
            "timestamp": Date().timeIntervalSince1970
        ]
        
        session.sendMessage(message, replyHandler: { response in
            print("Watch responded to ping: \(response)")
        }, errorHandler: { error in
            print("Ping error: \(error)")
        })
        #endif
    }
    
    private func saveWatchNote(content: String, timestamp: TimeInterval) -> Bool {
        guard let context = viewContext else { return false }
        
        let note = Note(context: context)
        note.id = UUID()
        note.content = content
        note.createdAt = Date(timeIntervalSince1970: timestamp)
        note.isVoiceNote = true
        note.latitude = 0
        note.longitude = 0
        note.locationName = "Apple Watch"
        
        do {
            try context.save()
            
            // Update widget with the new note
            updateWidgetWithLastNote(content)
            
            // Send success notification
            NotificationCenter.default.post(name: Notification.Name("WatchNoteReceived"), object: nil)
            
            return true
        } catch {
            print("Error saving watch note: \(error)")
            return false
        }
    }
    
    private func updateWidgetWithLastNote(_ content: String) {
        // Save to shared UserDefaults for widget access
        if let sharedDefaults = UserDefaults(suiteName: "group.Theory-of-Web.Rapid-Notes") {
            let preview = String(content.prefix(100)) // First 100 characters
            sharedDefaults.set(preview, forKey: "lastNotePreview")
            sharedDefaults.synchronize()
            
            // Refresh widget timeline
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadTimelines(ofKind: "QuickDumpWidget")
            #endif
        }
    }
}

// MARK: - WCSessionDelegate
#if canImport(WatchConnectivity)
extension PhoneConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = activationState == .activated
            self.isWatchReachable = session.isReachable
        }
        
        if let error = error {
            print("Phone session activation error: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Phone session became inactive")
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        print("Phone session deactivated")
        // Reactivate the session on the phone
        session.activate()
    }
    
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            self.isWatchReachable = session.isReachable
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        print("Phone received message: \(message)")
        
        guard let type = message["type"] as? String else {
            replyHandler(["success": false, "error": "Invalid message type"])
            return
        }
        
        switch type {
        case "newNote":
            handleNewNoteFromWatch(message: message, replyHandler: replyHandler)
        case "heartbeat":
            replyHandler(["success": true, "timestamp": Date().timeIntervalSince1970])
        case "pong":
            print("Watch responded to ping")
            replyHandler(["success": true])
        default:
            replyHandler(["success": false, "error": "Unknown message type"])
        }
    }
    
    private func handleNewNoteFromWatch(message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard let content = message["content"] as? String,
              let timestamp = message["timestamp"] as? TimeInterval else {
            replyHandler(["success": false, "error": "Invalid note data"])
            return
        }
        
        DispatchQueue.main.async {
            let success = self.saveWatchNote(content: content, timestamp: timestamp)
            replyHandler(["success": success])
            
            if success {
                // Show success notification or update UI
                self.showWatchNoteReceivedNotification(content: content)
            }
        }
    }
    
    private func showWatchNoteReceivedNotification(content: String) {
        // You could show a toast notification or update the UI
        print("Watch note received: \(content)")
        
        // Optionally trigger haptic feedback
        #if os(iOS) && canImport(UIKit)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
}
#endif
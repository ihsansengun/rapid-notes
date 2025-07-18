import SwiftUI
import CoreData

struct NewNoteView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speechService = SpeechService()
    @StateObject private var locationService = LocationService()
    @StateObject private var aiService = AIService()
    
    @State private var noteText = ""
    @State private var isTyping = false
    @State private var recordingTimer: Timer?
    @State private var recordingDuration: TimeInterval = 0
    @State private var showingSaveAnimation = false
    @State private var launchedFromWidget = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if !isTyping {
                    voiceRecordingView
                } else {
                    textInputView
                }
                
                Spacer()
                
                toggleButton
            }
            .padding()
            .navigationTitle("Quick Note")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        Task {
                            await saveNote()
                        }
                    }
                    .disabled(noteText.isEmpty && speechService.transcribedText.isEmpty)
                }
            }
        }
        .onAppear {
            // Auto-start recording if launched from widget or manually opened
            if !isTyping {
                startVoiceRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .openNewNote)) { notification in
            if let userInfo = notification.userInfo,
               let source = userInfo["source"] as? String,
               source == "widget" {
                launchedFromWidget = true
                // Ensure we're in voice mode when launched from widget
                if isTyping {
                    isTyping = false
                }
                startVoiceRecording()
            }
        }
        .onDisappear {
            stopVoiceRecording()
        }
        .overlay(
            saveAnimationOverlay
        )
    }
    
    private var voiceRecordingView: some View {
        VStack(spacing: 20) {
            recordingIndicator
            
            Text(speechService.transcribedText.isEmpty ? "Speak your note..." : speechService.transcribedText)
                .font(.body)
                .foregroundColor(speechService.transcribedText.isEmpty ? .secondary : .primary)
                .multilineTextAlignment(.center)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
            
            if speechService.isRecording {
                recordingControls
            }
        }
    }
    
    private var textInputView: some View {
        VStack {
            TextField("Type your note...", text: $noteText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(5...10)
                .focused()
        }
    }
    
    private var recordingIndicator: some View {
        VStack {
            Circle()
                .fill(speechService.isRecording ? Color.red : Color.gray)
                .frame(width: 60, height: 60)
                .scaleEffect(speechService.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: speechService.isRecording)
            
            Text(speechService.isRecording ? "Recording..." : "Tap to record")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onTapGesture {
            if speechService.isRecording {
                stopVoiceRecording()
            } else {
                startVoiceRecording()
            }
        }
    }
    
    private var recordingControls: some View {
        HStack {
            Button("Stop") {
                stopVoiceRecording()
            }
            .foregroundColor(.red)
            
            Spacer()
            
            Text(formatDuration(recordingDuration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var toggleButton: some View {
        Button(isTyping ? "Switch to Voice" : "Type Instead") {
            isTyping.toggle()
            if isTyping {
                stopVoiceRecording()
            } else {
                startVoiceRecording()
            }
        }
        .foregroundColor(.blue)
    }
    
    @ViewBuilder
    private var saveAnimationOverlay: some View {
        if showingSaveAnimation {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .overlay(
                    VStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Note Saved!")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                )
                .transition(.opacity)
        }
    }
    
    private func startVoiceRecording() {
        locationService.requestLocation()
        speechService.startRecording()
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            recordingDuration += 1
        }
    }
    
    private func stopVoiceRecording() {
        speechService.stopRecording()
        recordingTimer?.invalidate()
        recordingTimer = nil
        recordingDuration = 0
    }
    
    private func saveNote() async {
        let finalText = isTyping ? noteText : speechService.transcribedText
        guard !finalText.isEmpty else { return }
        
        let note = Note(context: viewContext)
        note.id = UUID()
        note.content = finalText
        note.createdAt = Date()
        note.isVoiceNote = !isTyping
        note.latitude = locationService.currentLocation?.coordinate.latitude ?? 0
        note.longitude = locationService.currentLocation?.coordinate.longitude ?? 0
        note.locationName = locationService.getLocationName()
        
        let aiResult = await aiService.analyzeNote(finalText)
        note.aiTags = aiResult.tags.joined(separator: ",")
        note.aiSummary = aiResult.summary
        
        do {
            try viewContext.save()
            
            withAnimation(.easeInOut(duration: 0.5)) {
                showingSaveAnimation = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                showingSaveAnimation = false
                dismiss()
            }
        } catch {
            print("Error saving note: \(error)")
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

extension View {
    func focused() -> some View {
        self.onAppear {
            #if os(iOS)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first {
                    window.rootViewController?.view.endEditing(false)
                }
            }
            #endif
        }
    }
}

#Preview {
    NewNoteView()
        .environment(\.managedObjectContext, PersistenceController.shared.container.viewContext)
}

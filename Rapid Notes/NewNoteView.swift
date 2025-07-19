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
    @State private var showingLanguageMismatch = false
    @State private var detectedLanguageMismatch: (detected: SupportedLanguage, confidence: Double)?
    
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
        .overlay(
            languageMismatchOverlay
        )
    }
    
    private var voiceRecordingView: some View {
        VStack(spacing: 20) {
            // Language switcher at the top
            QuickLanguageSwitcher()
            
            recordingIndicator
            
            VStack(spacing: 12) {
                Text(speechService.transcribedText.isEmpty ? "Speak your note..." : speechService.transcribedText)
                    .font(.body)
                    .foregroundColor(speechService.transcribedText.isEmpty ? .secondary : .primary)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(10)
                
                // Language detection indicator
                if let detectedLang = speechService.detectedLanguage,
                   speechService.languageConfidence > 0.5 {
                    HStack {
                        Image(systemName: "waveform.path.ecg")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("Detected: \(detectedLang.flag) \(detectedLang.displayName)")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text("(\(Int(speechService.languageConfidence * 100))%)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            
            if speechService.isRecording {
                recordingControls
            }
        }
        .onReceive(speechService.$transcribedText) { transcribedText in
            // Check for language mismatch when transcription is updated
            checkForLanguageMismatch(transcribedText)
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
    
    @ViewBuilder
    private var languageMismatchOverlay: some View {
        if showingLanguageMismatch,
           let mismatch = detectedLanguageMismatch {
            VStack {
                Spacer()
                
                LanguageMismatchView(
                    detectedLanguage: mismatch.detected,
                    currentLanguage: speechService.currentLanguage,
                    confidence: mismatch.confidence,
                    onSwitch: {
                        speechService.changeLanguage(to: mismatch.detected)
                        showingLanguageMismatch = false
                        detectedLanguageMismatch = nil
                    },
                    onDismiss: {
                        showingLanguageMismatch = false
                        detectedLanguageMismatch = nil
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            .ignoresSafeArea(.keyboard)
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
    
    private func checkForLanguageMismatch(_ text: String) {
        guard !text.isEmpty && !isTyping else { return }
        
        if speechService.shouldSuggestLanguageSwitch(for: text) {
            let suggestions = speechService.getLanguageSuggestions(for: text)
            if let firstSuggestion = suggestions.first,
               firstSuggestion.confidence > Config.languageDetectionThreshold {
                
                detectedLanguageMismatch = (detected: firstSuggestion.language, confidence: firstSuggestion.confidence)
                
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showingLanguageMismatch = true
                }
                
                // Auto-dismiss after 10 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                    if showingLanguageMismatch {
                        withAnimation {
                            showingLanguageMismatch = false
                            detectedLanguageMismatch = nil
                        }
                    }
                }
            }
        }
    }
    
    private func saveNote() async {
        let finalText = isTyping ? noteText : speechService.transcribedText
        guard !finalText.isEmpty else { return }
        
        // Get language information
        let noteLanguage = speechService.currentLanguage
        let (detectedLang, confidence) = await withCheckedContinuation { continuation in
            DispatchQueue.main.async {
                if let detected = speechService.detectedLanguage {
                    continuation.resume(returning: (detected, speechService.languageConfidence))
                } else {
                    continuation.resume(returning: (noteLanguage, 1.0))
                }
            }
        }
        
        let note = Note(context: viewContext)
        note.id = UUID()
        note.content = finalText
        note.createdAt = Date()
        note.isVoiceNote = !isTyping
        note.latitude = locationService.currentLocation?.coordinate.latitude ?? 0
        note.longitude = locationService.currentLocation?.coordinate.longitude ?? 0
        note.locationName = locationService.getLocationName()
        
        // Set language information
        note.setLanguage(noteLanguage)
        note.setDetectedLanguage(detectedLang, confidence: confidence)
        
        // Use language-aware AI analysis
        let aiResult = await aiService.analyzeNote(finalText, language: noteLanguage)
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

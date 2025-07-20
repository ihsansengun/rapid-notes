//
//  ContentView.swift
//  QuickDump
//
//  Created by FF on 17/07/2025.
//

import SwiftUI
import CoreData
import Combine
import WidgetKit

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)])
    private var notes: FetchedResults<Note>
    
    @State private var currentScreen: AppScreen = .newNote
    @StateObject private var notificationService = NotificationService.shared
    @StateObject private var recordingState = RecordingState()
    @EnvironmentObject private var connectivityManager: PhoneConnectivityManager
    @State private var showingSettings = false
    @State private var animateSuccess = false
    
    enum AppScreen {
        case newNote
        case textNote
        case notesList
        case memoryDashboard
        case memorySessions
        case settings
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Dark background
                Color.black
                    .ignoresSafeArea()
                
                // Main content
                Group {
                    switch currentScreen {
                    case .newNote:
                        NewNoteScreen(
                            recordingState: recordingState,
                            onTextMode: { currentScreen = .textNote },
                            onSaveComplete: { showSuccessAndNavigate() },
                            onViewNotes: { currentScreen = .notesList }
                        )
                    case .textNote:
                        TextNoteScreen(
                            onSaveComplete: { showSuccessAndNavigate() },
                            onCancel: { currentScreen = .newNote }
                        )
                    case .notesList:
                        NotesListScreen(
                            notes: Array(notes),
                            onNewNote: { currentScreen = .newNote },
                            onSettings: { showingSettings = true },
                            onMemoryDashboard: { currentScreen = .memoryDashboard },
                            onMemorySessions: { currentScreen = .memorySessions }
                        )
                    case .memoryDashboard:
                        MemoryDashboard()
                            .navigationBarHidden(false)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Back") {
                                        currentScreen = .notesList
                                    }
                                }
                            }
                    case .memorySessions:
                        MemorySessionsView()
                            .navigationBarHidden(false)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Back") {
                                        currentScreen = .notesList
                                    }
                                }
                            }
                    case .settings:
                        SettingsView()
                            .navigationBarHidden(false)
                            .toolbar {
                                ToolbarItem(placement: .navigationBarLeading) {
                                    Button("Back") {
                                        currentScreen = .notesList
                                    }
                                }
                            }
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: currentScreen)
                
                // Success overlay
                if animateSuccess {
                    SuccessOverlay()
                        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: animateSuccess)
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(StackNavigationViewStyle())
        #endif
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingSettings) {
            SettingsSheet()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openNewNote"))) { notification in
            currentScreen = .newNote
            
            // Handle preferred mode from widget
            if let userInfo = notification.userInfo,
               let _ = userInfo["preferredMode"] as? String {
                // You can pass this to NewNoteScreen if needed
                // For now, the NewNoteScreen will handle it internally
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openNotesList"))) { _ in
            currentScreen = .notesList
        }
        .onAppear {
            setupNotifications()
        }
    }
    
    private func showSuccessAndNavigate() {
        animateSuccess = true
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            animateSuccess = false
            currentScreen = .notesList
        }
    }
    
    private func setupNotifications() {
        if notificationService.authorizationStatus == .notDetermined {
            notificationService.requestAuthorization()
        }
    }
}

// MARK: - New Note Screen (Voice-First)
struct NewNoteScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationService = LocationService.shared
    @StateObject private var aiService = AIService()
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdAt, ascending: false)])
    private var notes: FetchedResults<Note>
    
    @ObservedObject var recordingState: RecordingState
    let onTextMode: () -> Void
    let onSaveComplete: () -> Void
    let onViewNotes: () -> Void
    
    @State private var shouldAutoRecord = false
    @State private var autoSaveTimer: Timer?
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // App title
            Text("QuickDump")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .padding(.bottom, 60)
            
            // Recording area
            VStack(spacing: 40) {
                // Waveform or mic visualization
                if recordingState.isRecording {
                    RecordingWaveform()
                        .frame(height: 80)
                } else {
                    MicrophoneIcon()
                        .frame(width: 80, height: 80)
                }
                
                // Recording button
                Button(action: toggleRecording) {
                    Circle()
                        .fill(recordingState.isRecording ? Color.red : Color.blue)
                        .frame(width: 80, height: 80)
                        .shadow(color: recordingState.isRecording ? .red : .blue, radius: 20, x: 0, y: 0)
                        .overlay(
                            Image(systemName: recordingState.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 32, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .scaleEffect(recordingState.isRecording ? 1.1 : 1.0)
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: recordingState.isRecording)
                }
                .buttonStyle(PlainButtonStyle())
                
                // Status text
                Text(recordingState.isRecording ? "Recording..." : "Tap to record")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))
                    .scaleEffect(recordingState.isRecording ? 1.05 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: recordingState.isRecording)
            }
            
            Spacer()
            
            // Bottom actions
            VStack(spacing: 20) {
                // Type instead button
                Button(action: onTextMode) {
                    HStack {
                        Image(systemName: "keyboard")
                        Text("Type Instead")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(25)
                }
                .buttonStyle(PlainButtonStyle())
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
                .onTapGesture {
                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                        // Haptic feedback
                        #if os(iOS)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                        #endif
                        onTextMode()
                    }
                }
                
                // View notes button (only if notes exist)
                if !notes.isEmpty {
                    Button("View Notes") {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onViewNotes()
                        }
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .scaleEffect(1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            locationService.requestLocation()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("openNewNote"))) { notification in
            // Auto-start recording if launched from widget
            if let userInfo = notification.userInfo,
               let autoStart = userInfo["autoStartRecording"] as? Bool,
               autoStart {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if !recordingState.isRecording {
                        recordingState.startRecording()
                        shouldAutoRecord = true
                        startAutoSaveTimer()
                    }
                }
            }
        }
        .onReceive(recordingState.$transcribedText) { _ in
            // Reset auto-save timer when new text is transcribed
            resetAutoSaveTimer()
        }
    }
    
    private func toggleRecording() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            if recordingState.isRecording {
                recordingState.stopRecording()
                saveVoiceNote()
            } else {
                recordingState.startRecording()
            }
        }
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: recordingState.isRecording ? .heavy : .medium)
        impactFeedback.impactOccurred()
        #endif
    }
    
    private func startAutoSaveTimer() {
        // Cancel any existing timer
        autoSaveTimer?.invalidate()
        
        // Start a timer that will auto-save after 3 seconds of silence
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            print("🕐 Auto-save timer fired - shouldAutoRecord: \(shouldAutoRecord), isRecording: \(recordingState.isRecording), hasText: \(!recordingState.transcribedText.isEmpty)")
            if shouldAutoRecord && recordingState.isRecording && !recordingState.transcribedText.isEmpty {
                print("✅ Auto-save conditions met - stopping recording and saving")
                recordingState.stopRecording()
                saveVoiceNote()
            } else {
                print("❌ Auto-save conditions not met - skipping save")
            }
        }
    }
    
    private func resetAutoSaveTimer() {
        if shouldAutoRecord && recordingState.isRecording {
            startAutoSaveTimer()
        }
    }
    
    private func saveVoiceNote() {
        let transcription = recordingState.transcribedText.isEmpty ? "No transcription available" : recordingState.transcribedText
        
        let note = Note(context: viewContext)
        note.id = UUID()
        note.content = transcription
        note.createdAt = Date()
        note.isVoiceNote = true
        note.latitude = locationService.currentLocation?.coordinate.latitude ?? 0
        note.longitude = locationService.currentLocation?.coordinate.longitude ?? 0
        note.locationName = locationService.currentLocationName
        
        // Set language information from speech service
        let currentLanguage = recordingState.speechService.currentLanguage
        let detectedLanguage = recordingState.speechService.detectedLanguage
        let confidence = recordingState.speechService.languageConfidence
        
        // Use detected language if confidence is high enough, otherwise use current language
        let noteLanguage = (detectedLanguage != nil && confidence > 0.6) ? detectedLanguage! : currentLanguage
        
        print("💾 Saving voice note with language info:")
        print("   Current Language: \(currentLanguage.displayName) (\(currentLanguage.rawValue))")
        print("   Detected Language: \(detectedLanguage?.displayName ?? "None") (\(detectedLanguage?.rawValue ?? "None"))")
        print("   Confidence: \(String(format: "%.2f", confidence))")
        print("   Note Language (final): \(noteLanguage.displayName) (\(noteLanguage.rawValue))")
        
        note.setLanguage(noteLanguage)
        if let detected = detectedLanguage {
            note.setDetectedLanguage(detected, confidence: confidence)
        }
        
        // Mark note for AI processing
        note.needsAIProcessing = true
        
        do {
            try viewContext.save()
            
            // Update widget with last note preview
            updateWidgetWithLastNote(transcription)
            
            // Process AI analysis in background if enabled
            if UserDefaults.standard.bool(forKey: "aiTaggingEnabled") {
                Task {
                    let result = await aiService.analyzeNote(transcription)
                    await MainActor.run {
                        note.aiTags = result.tags.joined(separator: ", ")
                        note.aiSummary = result.summary
                        try? viewContext.save()
                    }
                }
            }
            
            // Reset auto-record state
            shouldAutoRecord = false
            autoSaveTimer?.invalidate()
            
            onSaveComplete()
        } catch {
            print("Error saving voice note: \(error)")
        }
    }
}

// MARK: - Text Note Screen
struct TextNoteScreen: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var locationService = LocationService.shared
    @StateObject private var aiService = AIService()
    
    @State private var noteText = ""
    @FocusState private var isTextFieldFocused: Bool
    let onSaveComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .scaleEffect(1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
                
                Spacer()
                
                Text("New Note")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: saveNote) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
                .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                .scaleEffect(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.9 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Text input area
            VStack(alignment: .leading, spacing: 12) {
                TextField("What's on your mind?", text: $noteText, axis: .vertical)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white)
                    .padding(20)
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(16)
                    .focused($isTextFieldFocused)
                    .lineLimit(8...12)
                
                // Character count (optional)
                if noteText.count > 0 {
                    Text("\(noteText.count) characters")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            isTextFieldFocused = true
        }
    }
    
    private func saveNote() {
        let content = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        
        let note = Note(context: viewContext)
        note.id = UUID()
        note.content = content
        note.createdAt = Date()
        note.isVoiceNote = false
        note.latitude = locationService.currentLocation?.coordinate.latitude ?? 0
        note.longitude = locationService.currentLocation?.coordinate.longitude ?? 0
        note.locationName = locationService.currentLocationName
        
        // Set language information (for text notes, use current language)
        let noteLanguage = LanguageService.shared.currentLanguage
        note.setLanguage(noteLanguage)
        
        // Mark note for AI processing
        note.needsAIProcessing = true
        
        print("💾 Saving text note with language: \(noteLanguage.displayName) (\(noteLanguage.rawValue))")
        
        do {
            try viewContext.save()
            
            // Update widget with last note preview
            updateWidgetWithLastNote(content)
            
            // Process AI analysis in background if enabled
            if UserDefaults.standard.bool(forKey: "aiTaggingEnabled") {
                Task {
                    let result = await aiService.analyzeNote(content)
                    await MainActor.run {
                        note.aiTags = result.tags.joined(separator: ", ")
                        note.aiSummary = result.summary
                        try? viewContext.save()
                    }
                }
            }
            
            onSaveComplete()
        } catch {
            print("Error saving note: \(error)")
        }
    }
}

// MARK: - Notes List Screen
struct NotesListScreen: View {
    let notes: [Note]
    let onNewNote: () -> Void
    let onSettings: () -> Void
    let onMemoryDashboard: () -> Void
    let onMemorySessions: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notes")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Memory buttons
                HStack(spacing: 12) {
                    Button(action: onMemorySessions) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.blue.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onMemoryDashboard) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.purple.opacity(0.2))
                            .clipShape(Circle())
                    }
                    
                    Button(action: onSettings) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Notes list
            if notes.isEmpty {
                EmptyNotesView(onNewNote: onNewNote)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(notes, id: \.id) { note in
                            NoteCard(note: note)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            
            Spacer()
            
            // Floating action button
            Button(action: onNewNote) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(color: .blue.opacity(0.5), radius: 20, x: 0, y: 10)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: UUID())
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
}

// MARK: - Supporting Views
struct RecordingWaveform: View {
    @State private var animationPhase: Double = 0
    @State private var waveformHeights: [CGFloat] = []
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<20, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.blue, Color.cyan]),
                        startPoint: .bottom,
                        endPoint: .top
                    ))
                    .frame(width: 4, height: waveformHeights.indices.contains(index) ? waveformHeights[index] : 20)
                    .animation(
                        .spring(response: 0.3, dampingFraction: 0.7)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.05),
                        value: animationPhase
                    )
            }
        }
        .onAppear {
            generateWaveformHeights()
            animationPhase = 1.0
            
            // Continuously update waveform heights
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    generateWaveformHeights()
                }
            }
        }
    }
    
    private func generateWaveformHeights() {
        waveformHeights = (0..<20).map { _ in
            CGFloat.random(in: 15...70)
        }
    }
}

struct MicrophoneIcon: View {
    @State private var isBreathing = false
    
    var body: some View {
        Image(systemName: "mic.fill")
            .font(.system(size: 40, weight: .medium))
            .foregroundColor(.white.opacity(0.8))
            .scaleEffect(isBreathing ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isBreathing)
            .onAppear {
                isBreathing = true
            }
    }
}

struct NoteCard: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showingAIEnhancements = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main card content
            NavigationLink(destination: NoteDetailView(note: note, startInEditMode: false)) {
                HStack(alignment: .top, spacing: 12) {
                    // Content
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.content ?? "")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                        
                        // Meta info
                        HStack(spacing: 8) {
                            if note.isVoiceNote {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)
                            }
                            
                            // Language flag
                            Text(note.languageFlag)
                                .font(.system(size: 12))
                            
                            Text(note.createdAt?.formatted(date: .abbreviated, time: .shortened) ?? "")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                            
                            if let location = note.locationName, !location.isEmpty {
                                Text("• \(location)")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.6))
                                    .lineLimit(1)
                            }
                            
                            Spacer()
                        }
                        
                        // AI Category (enhanced display)
                        if let category = note.localizedAICategory {
                            HStack {
                                Text(LocalizedCategory.getDisplayWithIcon(for: category, language: note.supportedLanguage ?? .english))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.2))
                                    .cornerRadius(12)
                                
                                // AI confidence indicator
                                if note.hasHighConfidenceAI {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 6, height: 6)
                                } else if note.hasAIProcessing {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 6, height: 6)
                                }
                                
                                Spacer()
                            }
                        }
                        
                        // Legacy AI Tags (fallback)
                        if note.localizedAICategory == nil, let tags = note.aiTags, !tags.isEmpty {
                            HStack {
                                ForEach(tags.components(separatedBy: ",").prefix(3), id: \.self) { tag in
                                    Text(tag.trimmingCharacters(in: .whitespaces))
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.2))
                                        .cornerRadius(12)
                                }
                                Spacer()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: 12) {
                        // AI Enhancement toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAIEnhancements.toggle()
                            }
                        }) {
                            Image(systemName: note.hasAIProcessing ? "brain.head.profile.fill" : "brain.head.profile")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(note.hasAIProcessing ? .blue : .white.opacity(0.6))
                        }
                        
                        NavigationLink(destination: NoteDetailView(note: note, startInEditMode: true)) {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        Button(action: deleteNote) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red.opacity(0.8))
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.05))
                .cornerRadius(16)
            }
            .buttonStyle(PlainButtonStyle())
            
            // AI Enhancement View
            if showingAIEnhancements {
                NoteEnhancementView(note: note)
                    .padding(.top, 8)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
            }
        }
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
        .onAppear {
            // Auto-process notes that need AI processing
            if note.needsAIProcessing && note.content != nil && !note.content!.isEmpty {
                Task {
                    await processNoteForAI()
                }
            }
        }
    }
    
    private func processNoteForAI() async {
        guard let content = note.content, !content.isEmpty else { return }
        
        let aiMemoryService = AIMemoryService()
        let categoryService = CategoryService.shared
        
        // Process with AI Memory Service
        let clarity = await aiMemoryService.clarifyNote(content, language: note.supportedLanguage)
        
        await MainActor.run {
            if let clarity = clarity {
                note.updateWithClarity(clarity)
            }
            
            // Also run categorization service
            Task {
                let categoryResult = await categoryService.categorizeNote(content, language: note.supportedLanguage)
                await MainActor.run {
                    if note.aiCategory == nil {  // Don't override if already set
                        note.aiCategory = categoryResult.category
                        note.aiConfidence = max(note.aiConfidence, categoryResult.confidence)
                    }
                }
            }
            
            // Save changes
            do {
                try viewContext.save()
            } catch {
                print("Error saving AI processing results: \(error)")
            }
        }
    }
    
    private func deleteNote() {
        withAnimation {
            viewContext.delete(note)
            do {
                try viewContext.save()
            } catch {
                print("Error deleting note: \(error)")
            }
        }
    }
}

struct EmptyNotesView: View {
    let onNewNote: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "mic.fill")
                .font(.system(size: 60, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No notes yet")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("Start capturing your thoughts\nwith voice or text")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .multilineTextAlignment(.center)
            
            Button(action: onNewNote) {
                Text("Create First Note")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(25)
            }
            .scaleEffect(1.0)
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: UUID())
            .padding(.horizontal, 60)
            .padding(.top, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuccessOverlay: View {
    var body: some View {
        VStack {
            Image(systemName: "checkmark")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 80, height: 80)
                .background(Color.green)
                .clipShape(Circle())
                .shadow(color: .green.opacity(0.5), radius: 20, x: 0, y: 10)
            
            Text("Note Saved!")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
                .padding(.top, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.8))
    }
}

// MARK: - Recording State
class RecordingState: ObservableObject {
    @Published var isRecording = false
    @Published var isEmpty = true
    @Published var transcribedText = ""
    
    let speechService = SpeechService()
    
    init() {
        // Observe speech service changes
        speechService.$isRecording
            .receive(on: DispatchQueue.main)
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        speechService.$transcribedText
            .receive(on: DispatchQueue.main)
            .assign(to: \.transcribedText, on: self)
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    func startRecording() {
        speechService.startRecording()
    }
    
    func stopRecording() {
        speechService.stopRecording()
        isEmpty = transcribedText.isEmpty
    }
}

// MARK: - Settings Screen
struct SettingsScreen: View {
    let onDismiss: () -> Void
    @State private var showingWidgetInstructions = false
    @EnvironmentObject private var connectivityManager: PhoneConnectivityManager
    @State private var faceIDEnabled = false
    @State private var aiTaggingEnabled = true
    @State private var showingReminderPicker = false
    @State private var reminderTime = Date()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text("Settings")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Invisible spacer for centering
                Color.clear
                    .frame(width: 44, height: 44)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            
            // Settings content
            VStack(spacing: 20) {
                // Face ID toggle
                SettingRow(
                    icon: "faceid",
                    title: "Face ID Protection",
                    subtitle: "Lock notes with Face ID",
                    isToggle: true,
                    isOn: $faceIDEnabled
                )
                
                // AI tagging toggle
                SettingRow(
                    icon: "brain.head.profile",
                    title: "AI Tagging",
                    subtitle: "Automatically tag notes with AI",
                    isToggle: true,
                    isOn: $aiTaggingEnabled
                )
                
                // Reminder time
                SettingRow(
                    icon: "bell",
                    title: "Evening Reminder",
                    subtitle: reminderTime.formatted(date: .omitted, time: .shortened),
                    isToggle: false,
                    action: {
                        showingReminderPicker = true
                    }
                )
                
                // Lock screen widget
                SettingRow(
                    icon: "square.on.square",
                    title: "Lock Screen Widget",
                    subtitle: "Add to Control Center",
                    isToggle: false,
                    action: {
                        showingWidgetInstructions = true
                    }
                )
                
                // Apple Watch connectivity
                SettingRow(
                    icon: "applewatch",
                    title: "Apple Watch",
                    subtitle: connectivityManager.isWatchReachable ? "Connected" : "Not connected",
                    isToggle: false,
                    action: {
                        connectivityManager.sendPingToWatch()
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.top, 30)
            
            Spacer()
            
            // Language Debug Section
            LanguageDebugSection()
            
            // About section
            VStack(spacing: 8) {
                Text("QuickDump")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                
                Text("Version 1.0.0")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .sheet(isPresented: $showingWidgetInstructions) {
            WidgetInstructionsView()
        }
        .sheet(isPresented: $showingReminderPicker) {
            NavigationView {
                VStack {
                    Text("Set Reminder Time")
                        .font(.headline)
                        .padding()
                    
                    DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                        #if os(iOS)
                        .datePickerStyle(WheelDatePickerStyle())
                        #else
                        .datePickerStyle(DefaultDatePickerStyle())
                        #endif
                        .labelsHidden()
                        .padding()
                    
                    Spacer()
                }
                .background(Color.black)
                .navigationTitle("Reminder")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showingReminderPicker = false
                            // Save reminder preference
                            UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "reminderTime")
                            // Schedule the reminder notification
                            scheduleReminderNotification()
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showingReminderPicker = false
                        }
                        .foregroundColor(.blue)
                    }
                    #else
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            showingReminderPicker = false
                            // Save reminder preference
                            UserDefaults.standard.set(reminderTime.timeIntervalSince1970, forKey: "reminderTime")
                            // Schedule the reminder notification
                            scheduleReminderNotification()
                        }
                        .foregroundColor(.blue)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            showingReminderPicker = false
                        }
                        .foregroundColor(.blue)
                    }
                    #endif
                }
            }
            .preferredColorScheme(.dark)
        }
        .onAppear {
            // Load saved preferences
            faceIDEnabled = UserDefaults.standard.bool(forKey: "faceIDEnabled")
            
            // AI tagging defaults to true if not set
            let aiTaggingKey = "aiTaggingEnabled"
            if UserDefaults.standard.object(forKey: aiTaggingKey) == nil {
                aiTaggingEnabled = true
                UserDefaults.standard.set(true, forKey: aiTaggingKey)
            } else {
                aiTaggingEnabled = UserDefaults.standard.bool(forKey: aiTaggingKey)
            }
            
            // Load reminder time
            let savedTime = UserDefaults.standard.double(forKey: "reminderTime")
            if savedTime > 0 {
                reminderTime = Date(timeIntervalSince1970: savedTime)
            } else {
                // Default to 9:00 PM
                let calendar = Calendar.current
                var components = DateComponents()
                components.hour = 21
                components.minute = 0
                if let defaultTime = calendar.date(from: components) {
                    reminderTime = defaultTime
                    UserDefaults.standard.set(defaultTime.timeIntervalSince1970, forKey: "reminderTime")
                }
            }
        }
        .onChange(of: faceIDEnabled) {
            UserDefaults.standard.set(faceIDEnabled, forKey: "faceIDEnabled")
        }
        .onChange(of: aiTaggingEnabled) {
            UserDefaults.standard.set(aiTaggingEnabled, forKey: "aiTaggingEnabled")
        }
    }
    
    private func scheduleReminderNotification() {
        let notificationService = NotificationService.shared
        
        // Cancel existing reminder notifications
        notificationService.cancelReminderNotifications()
        
        // Schedule new reminder notification
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: reminderTime)
        
        notificationService.scheduleReminderNotification(
            title: "QuickDump Reminder",
            body: "Don't forget to capture your thoughts for today!",
            hour: components.hour ?? 21,
            minute: components.minute ?? 0
        )
    }
}

struct SettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isToggle: Bool
    var isOn: Binding<Bool> = .constant(false)
    var action: (() -> Void)? = nil
    
    var body: some View {
        Button(action: {
            if !isToggle {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    action?()
                }
            }
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                if isToggle {
                    Toggle("", isOn: isOn)
                        .labelsHidden()
                        .tint(.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isToggle)
        .scaleEffect(1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: UUID())
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        SettingsView()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
    }
}

// MARK: - Helper Functions
func updateWidgetWithLastNote(_ content: String) {
    // Save to shared UserDefaults for widget access
    if let sharedDefaults = UserDefaults(suiteName: "group.Theory-of-Web.Rapid-Notes") {
        let preview = String(content.prefix(100)) // First 100 characters
        sharedDefaults.set(preview, forKey: "lastNotePreview")
        sharedDefaults.synchronize()
        
        // Refresh widget timeline
        WidgetCenter.shared.reloadTimelines(ofKind: "QuickDumpWidget")
    }
}

// MARK: - Widget Instructions View
struct WidgetInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lock Screen Widget Setup")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Add QuickDump to your lock screen for instant note access")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    // Instructions
                    VStack(alignment: .leading, spacing: 20) {
                        InstructionStep(
                            number: "1",
                            title: "Lock Your Device",
                            description: "Press the power button to lock your iPhone"
                        )
                        
                        InstructionStep(
                            number: "2",
                            title: "Add Widget",
                            description: "Touch and hold the lock screen, then tap 'Customize'"
                        )
                        
                        InstructionStep(
                            number: "3",
                            title: "Find QuickDump",
                            description: "Tap 'Add Widgets' and search for 'QuickDump'"
                        )
                        
                        InstructionStep(
                            number: "4",
                            title: "Choose Widget Style",
                            description: "Select from inline, rectangular, or circular widgets"
                        )
                        
                        InstructionStep(
                            number: "5",
                            title: "Start Recording",
                            description: "Tap the widget anytime to instantly start recording notes"
                        )
                    }
                    
                    // Widget Preview
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Widget Preview")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 16) {
                            // Inline widget preview
                            VStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    Image(systemName: "mic.fill")
                                        .font(.system(size: 12))
                                        .foregroundColor(.white)
                                    Text("Quick Note")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.3))
                                .cornerRadius(16)
                                
                                Text("Inline")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            // Rectangular widget preview
                            VStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(.white)
                                        Text("QuickDump")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    Text("Tap to record")
                                        .font(.system(size: 10))
                                        .foregroundColor(.white.opacity(0.8))
                                }
                                .padding(8)
                                .frame(width: 120, height: 60)
                                .background(Color.purple.opacity(0.3))
                                .cornerRadius(8)
                                
                                Text("Rectangular")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                        }
                    }
                    
                    // Note
                    VStack(alignment: .leading, spacing: 8) {
                        Text("💡 Pro Tip")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text("The widget will automatically start voice recording when tapped, making it perfect for capturing quick thoughts without unlocking your phone.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(16)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(20)
            }
            .background(Color.black)
            .navigationTitle("Widget Setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                #else
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                #endif
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Instruction Step View
struct InstructionStep: View {
    let number: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Step number
            Text(number)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.blue)
                .clipShape(Circle())
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
        }
    }
}

// MARK: - Language Debug Section
struct LanguageDebugSection: View {
    @StateObject private var languageService = LanguageService.shared
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                
                Text("Language Debug")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    showingDetails.toggle()
                }) {
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .onTapGesture {
                showingDetails.toggle()
            }
            
            if showingDetails {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current: \(languageService.currentLanguage.flag) \(languageService.currentLanguage.displayName)")
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack {
                        Text("Auto-detect:")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Spacer()
                        
                        Toggle("", isOn: $languageService.autoDetectLanguage)
                            .labelsHidden()
                            .scaleEffect(0.8)
                    }
                    
                    Text("Available Languages:")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.9))
                        .padding(.top, 8)
                    
                    ForEach(SupportedLanguage.allCases) { language in
                        HStack {
                            Text(language.flag)
                            Text(language.displayName)
                                .font(.system(size: 13))
                            Spacer()
                            Text(language.isSpeechRecognitionSupported ? "✓" : "✗")
                                .foregroundColor(language.isSpeechRecognitionSupported ? .green : .red)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    }
                    
                    VStack(spacing: 8) {
                        HStack(spacing: 12) {
                            Button("Debug General") {
                                languageService.debugLanguageSupport()
                            }
                            .foregroundColor(.blue)
                            .font(.system(size: 14, weight: .medium))
                            
                            Button("Debug Turkish") {
                                languageService.debugTurkishSupport()
                            }
                            .foregroundColor(.orange)
                            .font(.system(size: 14, weight: .medium))
                        }
                        
                        HStack(spacing: 12) {
                            Button("Debug Whisper") {
                                Config.debugWhisperConfiguration()
                            }
                            .foregroundColor(.purple)
                            .font(.system(size: 14, weight: .medium))
                            
                            Button(Config.enableDualEngineTranscription ? "Disable Dual-Engine" : "Enable Dual-Engine") {
                                Config.enableDualEngineTranscription.toggle()
                                print("🔄 Dual-Engine Transcription: \(Config.enableDualEngineTranscription ? "ENABLED" : "DISABLED")")
                            }
                            .foregroundColor(Config.enableDualEngineTranscription ? .red : .green)
                            .font(.system(size: 14, weight: .medium))
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
import SwiftUI
import AVFoundation

struct SettingsView: View {
    @StateObject private var languageService = LanguageService.shared
    @State private var showingLanguageSelection = false
    @State private var showingAdvancedSettings = false
    @State private var enableAITagging = Config.enableAITranscriptionImprovement
    @State private var enableDualEngine = Config.enableDualEngineTranscription
    @State private var autoDetectLanguage = Config.autoDetectLanguage
    
    var body: some View {
        NavigationView {
            Form {
                // Language Settings Section
                Section(header: Text("Language")) {
                    // Current Language
                    HStack {
                        Image(systemName: "globe")
                        Text("Language")
                        Spacer()
                        Button(action: { showingLanguageSelection = true }) {
                            HStack {
                                Text(languageService.currentLanguage.flag)
                                Text(languageService.currentLanguage.displayName)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .foregroundColor(.primary)
                    }
                    
                    // Auto-detect Language
                    HStack {
                        Image(systemName: "wand.and.rays")
                        Toggle("Auto-detect Language", isOn: $autoDetectLanguage)
                            .onChange(of: autoDetectLanguage) { newValue in
                                Config.autoDetectLanguage = newValue
                                languageService.autoDetectLanguage = newValue
                            }
                    }
                }
                
                // AI Features Section
                Section(header: Text("AI Features")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: enableAITagging ? "brain.head.profile.fill" : "brain.head.profile")
                                .foregroundColor(enableAITagging ? .purple : .secondary)
                            Toggle("AI Enhancement", isOn: $enableAITagging)
                                .onChange(of: enableAITagging) { newValue in
                                    Config.enableAITranscriptionImprovement = newValue
                                }
                        }
                        
                        Text("Improve transcripts with AI post-processing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Dual Engine Mode (Simplified)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: enableDualEngine ? "gearshape.2.fill" : "gearshape.2")
                                .foregroundColor(enableDualEngine ? .blue : .secondary)
                            Toggle("Enhanced Accuracy", isOn: $enableDualEngine)
                                .onChange(of: enableDualEngine) { newValue in
                                    Config.enableDualEngineTranscription = newValue
                                }
                        }
                        
                        Text("Uses multiple transcription engines for better accuracy")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // API Status Section
                Section(header: Text("Configuration")) {
                    HStack {
                        Image(systemName: Config.hasValidOpenAIKey ? "key.fill" : "key")
                            .foregroundColor(Config.hasValidOpenAIKey ? .green : .orange)
                        Text("OpenAI API Key")
                        Spacer()
                        Text(Config.hasValidOpenAIKey ? "✓ Configured" : "Not Set")
                            .foregroundColor(Config.hasValidOpenAIKey ? .green : .orange)
                            .font(.caption)
                    }
                }
                
                // Advanced Settings
                Section {
                    Button("Advanced Settings") {
                        showingAdvancedSettings = true
                    }
                    .foregroundColor(.secondary)
                }
                
                // Debug Section (only in debug builds)
                #if DEBUG
                Section(header: Text("Debug")) {
                    Button("Language Support") {
                        languageService.debugLanguageSupport()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Whisper Configuration") {
                        Config.debugWhisperConfiguration()
                    }
                    .foregroundColor(.purple)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .sheet(isPresented: $showingLanguageSelection) {
            SettingsLanguageSelectionView()
        }
        .sheet(isPresented: $showingAdvancedSettings) {
            AdvancedSettingsView()
        }
        .onAppear {
            // Sync settings with Config values
            enableAITagging = Config.enableAITranscriptionImprovement
            enableDualEngine = Config.enableDualEngineTranscription
            autoDetectLanguage = Config.autoDetectLanguage
        }
    }
}

// MARK: - Settings Language Selection View
struct SettingsLanguageSelectionView: View {
    @StateObject private var languageService = LanguageService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Available Languages")) {
                    ForEach(languageService.availableLanguages, id: \.id) { language in
                        Button(action: {
                            languageService.setLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                                Spacer()
                                if languageService.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                
                Section(header: Text("Whisper-Only Languages")) {
                    ForEach(SupportedLanguage.allCases.filter { !$0.isSpeechRecognitionSupported }, id: \.id) { language in
                        Button(action: {
                            languageService.setLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.flag)
                                Text(language.displayName)
                                Spacer()
                                Image(systemName: "cloud")
                                    .foregroundColor(.blue)
                                    .font(.caption)
                                if languageService.currentLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Select Language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var languageService = LanguageService.shared
    @State private var maxAudioSize = Config.maxWhisperAudioSizeMB
    @State private var audioQuality = Config.whisperAudioQuality
    @State private var alwaysUseWhisper = Config.alwaysUseWhisperVerification
    @State private var transcriptConfidenceThreshold = Config.transcriptConfidenceThreshold
    @State private var languageDetectionThreshold = Config.languageDetectionThreshold
    @State private var enableBackgroundProcessing = Config.enableBackgroundWhisperProcessing
    
    var body: some View {
        NavigationView {
            Form {
                // Transcription Engine Details
                Section(header: Text("Transcription Engine")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "checkmark.circle")
                            Toggle("Always Verify with Whisper", isOn: $alwaysUseWhisper)
                                .onChange(of: alwaysUseWhisper) { newValue in
                                    Config.alwaysUseWhisperVerification = newValue
                                }
                        }
                        
                        Text("Use Whisper even when Apple Speech is available")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "gauge")
                            Text("Confidence Threshold")
                            Spacer()
                            Text("\(Int(transcriptConfidenceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $transcriptConfidenceThreshold, in: 0.6...0.95, step: 0.05)
                            .onChange(of: transcriptConfidenceThreshold) { newValue in
                                Config.transcriptConfidenceThreshold = newValue
                            }
                        
                        Text("Minimum confidence to prefer one engine over another")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "square.stack.3d.down.right")
                            Toggle("Background Processing", isOn: $enableBackgroundProcessing)
                                .onChange(of: enableBackgroundProcessing) { newValue in
                                    Config.enableBackgroundWhisperProcessing = newValue
                                }
                        }
                        
                        Text("Continue transcription when app goes to background")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Language Detection Details
                Section(header: Text("Language Detection")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "slider.horizontal.3")
                            Text("Detection Sensitivity")
                            Spacer()
                            Text("\(Int(languageDetectionThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $languageDetectionThreshold, in: 0.5...0.9, step: 0.05)
                            .onChange(of: languageDetectionThreshold) { newValue in
                                Config.languageDetectionThreshold = newValue
                            }
                    }
                }
                
                // Audio Settings
                Section(header: Text("Audio Settings")) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Max Audio File Size")
                            Spacer()
                            Text("\(String(format: "%.1f", maxAudioSize)) MB")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $maxAudioSize, in: 5.0...25.0, step: 1.0)
                        
                        Text("Maximum file size for Whisper API uploads")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Picker("Audio Quality", selection: $audioQuality) {
                        Text("Low").tag(AVAudioQuality.low)
                        Text("Medium").tag(AVAudioQuality.medium)
                        Text("High").tag(AVAudioQuality.high)
                    }
                }
                
                // Supported Languages
                Section(header: Text("Supported Languages")) {
                    ForEach(SupportedLanguage.allCases, id: \.id) { language in
                        HStack {
                            Text(language.flag)
                            Text(language.displayName)
                            Spacer()
                            Group {
                                if language.isSpeechRecognitionSupported {
                                    Label("Apple Speech", systemImage: "checkmark.circle.fill")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.green)
                                } else {
                                    Label("Whisper Only", systemImage: "cloud")
                                        .labelStyle(.iconOnly)
                                        .foregroundColor(.blue)
                                }
                            }
                            .font(.caption)
                        }
                    }
                }
                
                // API Configuration
                Section(header: Text("API Configuration")) {
                    HStack {
                        Text("Whisper Endpoint")
                        Spacer()
                        Text("OpenAI")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key Status")
                        HStack {
                            Image(systemName: Config.hasValidOpenAIKey ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(Config.hasValidOpenAIKey ? .green : .red)
                            Text(Config.hasValidOpenAIKey ? "Valid API Key Configured" : "No Valid API Key")
                                .font(.caption)
                        }
                        
                        if Config.hasValidOpenAIKey {
                            Text("Key: \(Config.openAIAPIKey.prefix(10))...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                // Debug & Diagnostics
                Section(header: Text("Debug & Diagnostics")) {
                    Button("Debug Language Support") {
                        languageService.debugLanguageSupport()
                    }
                    .foregroundColor(.blue)
                    
                    Button("Debug Whisper Configuration") {
                        Config.debugWhisperConfiguration()
                    }
                    .foregroundColor(.purple)
                    
                    Button("Debug API Configuration") {
                        Config.debugConfiguration()
                    }
                    .foregroundColor(.orange)
                    
                    if languageService.currentLanguage == .turkish {
                        Button("Debug Turkish Support") {
                            languageService.debugTurkishSupport()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                // Reset Settings
                Section(header: Text("Reset Settings")) {
                    Button("Reset to Defaults") {
                        resetToDefaults()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Advanced Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            // Sync settings with Config values
            alwaysUseWhisper = Config.alwaysUseWhisperVerification
            transcriptConfidenceThreshold = Config.transcriptConfidenceThreshold
            languageDetectionThreshold = Config.languageDetectionThreshold
            enableBackgroundProcessing = Config.enableBackgroundWhisperProcessing
        }
    }
    
    private func resetToDefaults() {
        Config.enableDualEngineTranscription = true
        Config.alwaysUseWhisperVerification = false
        Config.transcriptConfidenceThreshold = 0.8
        Config.languageDetectionThreshold = 0.7
        Config.autoDetectLanguage = true
        Config.enableAITranscriptionImprovement = true
        Config.enableBackgroundWhisperProcessing = false
        
        // Update local state
        alwaysUseWhisper = false
        transcriptConfidenceThreshold = 0.8
        languageDetectionThreshold = 0.7
        enableBackgroundProcessing = false
        maxAudioSize = 25.0
        audioQuality = .medium
    }
}

#Preview {
    SettingsView()
}
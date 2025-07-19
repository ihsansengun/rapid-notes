import SwiftUI

/// Language selection view for settings and quick switching
struct LanguageSelectionView: View {
    @StateObject private var languageService = LanguageService.shared
    @Environment(\.dismiss) private var dismiss
    
    let onLanguageSelected: ((SupportedLanguage) -> Void)?
    
    init(onLanguageSelected: ((SupportedLanguage) -> Void)? = nil) {
        self.onLanguageSelected = onLanguageSelected
    }
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(languageService.availableLanguages) { language in
                        LanguageRow(
                            language: language,
                            isSelected: language == languageService.currentLanguage,
                            onSelect: {
                                selectLanguage(language)
                            }
                        )
                    }
                } header: {
                    Text("Available Languages")
                } footer: {
                    Text("Languages with speech recognition support on this device")
                }
                
                Section {
                    Toggle("Auto-detect Language", isOn: $languageService.autoDetectLanguage)
                } footer: {
                    Text("Automatically switch language based on detected speech patterns")
                }
            }
            .navigationTitle("Language Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                #endif
            }
        }
    }
    
    private func selectLanguage(_ language: SupportedLanguage) {
        languageService.setLanguage(language)
        onLanguageSelected?(language)
        
        // Haptic feedback
        #if os(iOS)
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        #endif
    }
}

/// Individual language row
struct LanguageRow: View {
    let language: SupportedLanguage
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Text(language.flag)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(language.displayName)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(language.rawValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundColor(.accentColor)
                        .font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Compact language picker for inline use
struct LanguagePicker: View {
    @ObservedObject private var languageService = LanguageService.shared
    @State private var showingLanguageSelection = false
    
    let title: String
    let showFlag: Bool
    
    init(title: String = "Language", showFlag: Bool = true) {
        self.title = title
        self.showFlag = showFlag
    }
    
    var body: some View {
        Button(action: {
            showingLanguageSelection = true
        }) {
            HStack {
                if showFlag {
                    Text(languageService.currentLanguage.flag)
                        .font(.title3)
                }
                
                Text(title)
                    .font(.body)
                
                Text(languageService.currentLanguage.displayName)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .sheet(isPresented: $showingLanguageSelection) {
            LanguageSelectionView()
        }
    }
}

/// Quick language switcher for recording interface
struct QuickLanguageSwitcher: View {
    @ObservedObject private var languageService = LanguageService.shared
    @State private var showingAllLanguages = false
    
    var body: some View {
        HStack {
            // Current language indicator
            Button(action: {
                showingAllLanguages = true
            }) {
                HStack(spacing: 4) {
                    Text(languageService.currentLanguage.flag)
                        .font(.title3)
                        .onAppear {
                            print("🎌 QuickLanguageSwitcher displaying: \(languageService.currentLanguage.displayName) (\(languageService.currentLanguage.flag))")
                        }
                        .onChange(of: languageService.currentLanguage) { newLanguage in
                            print("🔄 QuickLanguageSwitcher language changed to: \(newLanguage.displayName) (\(newLanguage.flag))")
                        }
                    
                    Text(languageService.currentLanguage.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Auto-detect indicator
            if languageService.autoDetectLanguage {
                HStack(spacing: 4) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundColor(.green)
                    
                    Text("Auto")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .sheet(isPresented: $showingAllLanguages) {
            LanguageSelectionView { selectedLanguage in
                // Add to preferred languages when manually selected
                Config.addPreferredLanguage(selectedLanguage)
            }
        }
    }
}

/// Language mismatch warning view
struct LanguageMismatchView: View {
    let detectedLanguage: SupportedLanguage
    let currentLanguage: SupportedLanguage
    let confidence: Double
    let onSwitch: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text("Language Mismatch Detected")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Current: \(currentLanguage.flag) \(currentLanguage.displayName)")
                    .font(.body)
                
                Text("Detected: \(detectedLanguage.flag) \(detectedLanguage.displayName)")
                    .font(.body)
                    .foregroundColor(.orange)
                
                Text("Confidence: \(Int(confidence * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Button("Keep Current") {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Switch to \(detectedLanguage.displayName)") {
                    onSwitch()
                }
                .foregroundColor(.accentColor)
                .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

#Preview {
    LanguageSelectionView()
}

#Preview("Language Picker") {
    NavigationView {
        List {
            LanguagePicker()
        }
        .navigationTitle("Settings")
    }
}

#Preview("Quick Switcher") {
    QuickLanguageSwitcher()
        .padding()
}

#Preview("Language Mismatch") {
    LanguageMismatchView(
        detectedLanguage: .spanish,
        currentLanguage: .english,
        confidence: 0.85,
        onSwitch: {},
        onDismiss: {}
    )
}
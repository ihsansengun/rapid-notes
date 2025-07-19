import Speech
import AVFoundation
import Foundation

class SpeechService: ObservableObject {
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var currentLanguage: SupportedLanguage = LanguageService.shared.currentLanguage
    @Published var detectedLanguage: SupportedLanguage?
    @Published var languageConfidence: Double = 0.0
    
    private let languageService = LanguageService.shared
    private let languageDetector = LanguageDetector.shared
    
    init() {
        setupSpeechRecognizer()
        requestSpeechAuthorization()
        
        // Listen for language changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(languageDidChange),
            name: NSNotification.Name("LanguageChanged"),
            object: nil
        )
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = languageService.speechRecognizer(for: currentLanguage)
    }
    
    @objc private func languageDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLanguage = self.languageService.currentLanguage
            self.setupSpeechRecognizer()
        }
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                self?.authorizationStatus = authStatus
            }
        }
    }
    
    func startRecording() {
        guard authorizationStatus == .authorized else {
            print("Speech recognition not authorized")
            return
        }
        
        if audioEngine.isRunning {
            stopRecording()
            return
        }
        
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            
            let inputNode = audioEngine.inputNode
            guard let recognitionRequest = recognitionRequest else {
                fatalError("Unable to create recognition request")
            }
            
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                DispatchQueue.main.async {
                    if let result = result {
                        self?.transcribedText = result.bestTranscription.formattedString
                        
                        // Perform language detection on partial results
                        if result.isFinal {
                            self?.performLanguageDetection(on: result.bestTranscription.formattedString)
                        }
                    }
                    
                    if error != nil || result?.isFinal == true {
                        self?.stopRecording()
                    }
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            transcribedText = ""
            
        } catch {
            print("Recording error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
    }
    
    /// Change the speech recognition language
    func changeLanguage(to language: SupportedLanguage) {
        currentLanguage = language
        languageService.setLanguage(language)
        setupSpeechRecognizer()
        
        NotificationCenter.default.post(name: NSNotification.Name("LanguageChanged"), object: nil)
    }
    
    /// Perform language detection on transcribed text
    private func performLanguageDetection(on text: String) {
        guard !text.isEmpty else { return }
        
        let (detected, confidence) = languageDetector.detectLanguageWithConfidence(from: text)
        
        if let detectedLang = detected {
            detectedLanguage = detectedLang
            languageConfidence = confidence
            
            // Auto-switch language if enabled and confidence is high
            if languageService.autoDetectLanguage &&
               confidence > 0.8 &&
               detectedLang != currentLanguage {
                
                print("🔄 Auto-switching language to \(detectedLang.displayName) (confidence: \(String(format: "%.2f", confidence)))")
                changeLanguage(to: detectedLang)
            }
        }
    }
    
    /// Get available languages for speech recognition
    var availableLanguages: [SupportedLanguage] {
        return languageService.availableLanguages
    }
    
    /// Check if current language supports speech recognition
    var isCurrentLanguageSupported: Bool {
        return currentLanguage.isSpeechRecognitionSupported
    }
    
    /// Get language suggestions based on transcribed text
    func getLanguageSuggestions(for text: String) -> [(language: SupportedLanguage, confidence: Double)] {
        return languageDetector.getLanguageHypotheses(from: text, maxCount: 3)
    }
    
    /// Check if language switch is recommended
    func shouldSuggestLanguageSwitch(for text: String) -> Bool {
        return languageDetector.shouldSuggestLanguageChange(for: text, currentLanguage: currentLanguage)
    }
    
    /// Transcribe with specific language (one-time use)
    func transcribeWithLanguage(_ language: SupportedLanguage, completion: @escaping (String?) -> Void) {
        guard languageService.speechRecognizer(for: language) != nil else {
            completion(nil)
            return
        }
        
        // This would be used for re-transcribing existing audio with different language
        // Implementation would depend on having stored audio data
        print("Transcribing with language: \(language.displayName)")
        completion(transcribedText) // Placeholder
    }
    
    /// Debug speech recognition status
    func debugSpeechRecognition() {
        print("=== Speech Recognition Debug ===")
        print("Current Language: \(currentLanguage.displayName)")
        print("Speech Recognizer Available: \(speechRecognizer != nil)")
        print("Authorization Status: \(authorizationStatus)")
        print("Is Recording: \(isRecording)")
        print("Transcribed Text Length: \(transcribedText.count)")
        
        if let detected = detectedLanguage {
            print("Detected Language: \(detected.displayName) (confidence: \(String(format: "%.2f", languageConfidence)))")
        }
        
        print("Available Languages:")
        for lang in availableLanguages {
            print("  - \(lang.flag) \(lang.displayName)")
        }
        print("================================")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
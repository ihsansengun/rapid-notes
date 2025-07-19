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
    
    // Dual-engine support
    @Published var whisperResult: WhisperResult?
    @Published var appleResult: AppleTranscriptResult?
    @Published var finalResult: TranscriptComparisonResult?
    @Published var isProcessingWhisper = false
    
    private let languageService = LanguageService.shared
    private let languageDetector = LanguageDetector.shared
    @MainActor
    private var whisperService: WhisperService {
        WhisperService.shared
    }
    private let transcriptComparator = TranscriptComparator.shared
    
    // Audio recording for Whisper
    private var audioRecorder: AVAudioRecorder?
    private var recordedAudioURL: URL?
    private var audioBuffers: [AVAudioPCMBuffer] = []
    
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
        
        // Auto-enable dual-engine mode if current language isn't supported by Apple Speech
        if speechRecognizer == nil && Config.hasValidOpenAIKey {
            if !Config.enableDualEngineTranscription {
                Config.enableDualEngineTranscription = true
                print("🔄 Auto-enabled dual-engine transcription for unsupported language: \(currentLanguage.displayName)")
            }
        }
    }
    
    @objc private func languageDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let oldLanguage = self.currentLanguage
            self.currentLanguage = self.languageService.currentLanguage
            print("🔄 SpeechService language changed: \(oldLanguage.displayName) → \(self.currentLanguage.displayName)")
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
        
        // Reset results
        whisperResult = nil
        appleResult = nil
        finalResult = nil
        audioBuffers.removeAll()
        
        do {
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            #endif
            
            // Setup audio file recording for Whisper
            if Config.enableDualEngineTranscription {
                setupAudioRecording()
            }
            
            let inputNode = audioEngine.inputNode
            
            // Check if we need Apple Speech recognition or Whisper-only mode
            if speechRecognizer == nil && Config.enableDualEngineTranscription {
                // Whisper-only mode for unsupported languages
                print("🎤 Starting Whisper-only recording (Apple Speech not available for \(currentLanguage.displayName))")
                transcribedText = "🎤 Recording for Whisper transcription..."
                recognitionRequest = nil
                recognitionTask = nil
            } else {
                // Dual-engine or Apple-only mode
                recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
                
                guard let recognitionRequest = recognitionRequest else {
                    fatalError("Unable to create recognition request")
                }
                
                recognitionRequest.shouldReportPartialResults = true
                
                recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                    DispatchQueue.main.async {
                        if let result = result {
                            self?.transcribedText = result.bestTranscription.formattedString
                            
                            // Create Apple result for comparison
                            if result.isFinal {
                                self?.processAppleResult(result)
                            }
                        }
                        
                        if error != nil || result?.isFinal == true {
                            self?.finishRecording()
                        }
                    }
                }
            }
            
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                // Only append to recognition request if Apple Speech is available and we have a request
                if self?.speechRecognizer != nil, let recognitionRequest = self?.recognitionRequest {
                    recognitionRequest.append(buffer)
                }
                
                // Store audio buffers for Whisper if dual-engine is enabled
                if Config.enableDualEngineTranscription {
                    self?.storeAudioBuffer(buffer)
                }
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            
            // Start audio recorder if dual-engine is enabled
            if Config.enableDualEngineTranscription {
                audioRecorder?.record()
            }
            
            isRecording = true
            transcribedText = ""
            
        } catch {
            print("Recording error: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        finishRecording()
    }
    
    private func finishRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Stop audio recorder
        audioRecorder?.stop()
        
        isRecording = false
        
        // For Whisper-only mode, create an empty Apple result
        if speechRecognizer == nil && Config.enableDualEngineTranscription {
            // Create empty Apple result for comparison
            appleResult = AppleTranscriptResult(
                text: "",
                confidence: 0.0,
                isFinal: true,
                detectedLanguage: nil
            )
        }
        
        // Process with Whisper if dual-engine is enabled
        if Config.enableDualEngineTranscription {
            processWithWhisper()
        }
    }
    
    // MARK: - Dual-Engine Support
    
    private func setupAudioRecording() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        recordedAudioURL = documentsPath.appendingPathComponent("temp_recording.wav")
        
        guard let url = recordedAudioURL else { return }
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 16000, // Whisper prefers 16kHz
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.prepareToRecord()
        } catch {
            print("Failed to setup audio recorder: \(error)")
        }
    }
    
    private func storeAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        // Store buffer for potential Whisper processing
        if audioBuffers.count < 1000 { // Limit memory usage
            audioBuffers.append(buffer)
        }
    }
    
    private func processAppleResult(_ result: SFSpeechRecognitionResult) {
        let text = result.bestTranscription.formattedString
        let confidence = Double(result.bestTranscription.segments.first?.confidence ?? 0.5)
        
        // Perform language detection
        performLanguageDetection(on: text)
        
        appleResult = AppleTranscriptResult(
            text: text,
            confidence: confidence,
            isFinal: result.isFinal,
            detectedLanguage: detectedLanguage
        )
        
        // If not using dual-engine, update transcribed text immediately
        if !Config.enableDualEngineTranscription {
            updateFinalTranscript()
        }
    }
    
    private func processWithWhisper() {
        guard Config.hasValidOpenAIKey else {
            print("No OpenAI API key - skipping Whisper processing")
            updateFinalTranscript()
            return
        }
        
        isProcessingWhisper = true
        
        Task {
            let localWhisperResult: WhisperResult?
            
            // Get whisper service reference on main actor
            let whisperServiceRef = await MainActor.run { self.whisperService }
            
            // Try using recorded audio file first
            if let audioURL = recordedAudioURL,
               FileManager.default.fileExists(atPath: audioURL.path) {
                localWhisperResult = await whisperServiceRef.transcribeAudioFile(
                    url: audioURL,
                    language: languageService.autoDetectLanguage ? nil : currentLanguage
                )
            }
            // Fallback to audio buffers
            else if !audioBuffers.isEmpty {
                // Combine buffers and process with Whisper
                if let combinedBuffer = combineAudioBuffers() {
                    localWhisperResult = await whisperServiceRef.transcribeAudioBuffer(
                        combinedBuffer,
                        language: languageService.autoDetectLanguage ? nil : currentLanguage
                    )
                } else {
                    localWhisperResult = nil
                }
            } else {
                localWhisperResult = nil
            }
            
            await MainActor.run {
                self.whisperResult = localWhisperResult
                self.isProcessingWhisper = false
                self.updateFinalTranscript()
                
                // Cleanup temporary files
                if let audioURL = self.recordedAudioURL {
                    try? FileManager.default.removeItem(at: audioURL)
                }
            }
        }
    }
    
    private func combineAudioBuffers() -> AVAudioPCMBuffer? {
        guard !audioBuffers.isEmpty else { return nil }
        
        let format = audioBuffers[0].format
        let totalFrames = audioBuffers.reduce(0) { $0 + AVAudioFrameCount($1.frameLength) }
        
        guard let combinedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: totalFrames) else {
            return nil
        }
        
        var currentFrame: AVAudioFrameCount = 0
        
        for buffer in audioBuffers {
            let framesToCopy = min(buffer.frameLength, totalFrames - currentFrame)
            
            for channel in 0..<Int(format.channelCount) {
                if let sourceData = buffer.floatChannelData?[channel],
                   let destData = combinedBuffer.floatChannelData?[channel] {
                    memcpy(destData + Int(currentFrame), sourceData, Int(framesToCopy) * MemoryLayout<Float>.size)
                }
            }
            
            currentFrame += framesToCopy
        }
        
        combinedBuffer.frameLength = currentFrame
        return combinedBuffer
    }
    
    private func updateFinalTranscript() {
        let comparison = transcriptComparator.chooseBestTranscript(
            appleResult: appleResult,
            whisperResult: whisperResult
        )
        
        finalResult = comparison
        
        // Update the main transcribed text with the chosen result
        if !comparison.chosenTranscript.isEmpty {
            transcribedText = comparison.chosenTranscript
        }
        
        // Update detected language from Whisper if available and confident
        if let whisperResult = whisperResult,
           let detectedLang = whisperResult.supportedLanguage,
           whisperResult.confidence > 0.7 {
            detectedLanguage = detectedLang
            languageConfidence = whisperResult.confidence
        }
        
        print("🔄 Transcript comparison: \(comparison.chosenEngine.displayName) chosen - \(comparison.reason)")
    }
    
    /// Get the best available transcript result
    var bestTranscriptResult: String {
        return finalResult?.chosenTranscript ?? transcribedText
    }
    
    /// Check if transcription needs review
    var needsReview: Bool {
        return finalResult?.needsReview ?? false
    }
    
    /// Get transcript quality score
    var transcriptQuality: Double {
        return finalResult?.confidence ?? (appleResult?.confidence ?? 0.0)
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
            
            // Auto-switch language if enabled and confidence is sufficient
            // Use lower threshold for Turkish and other non-English languages
            let confidenceThreshold: Double = (detectedLang == .turkish || detectedLang == .russian || detectedLang == .chinese) ? 0.6 : 0.8
            
            if languageService.autoDetectLanguage &&
               confidence > confidenceThreshold &&
               detectedLang != currentLanguage {
                
                print("🔄 Auto-switching language to \(detectedLang.displayName) (confidence: \(String(format: "%.2f", confidence)), threshold: \(confidenceThreshold))")
                changeLanguage(to: detectedLang)
            } else if confidence > 0.4 && detectedLang != currentLanguage {
                print("⚠️ Detected \(detectedLang.displayName) (confidence: \(String(format: "%.2f", confidence))) but threshold not met (need: \(confidenceThreshold))")
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
        
        // Dual-engine information
        print("Dual Engine Enabled: \(Config.enableDualEngineTranscription)")
        print("Whisper Processing: \(isProcessingWhisper)")
        print("Has Apple Result: \(appleResult != nil)")
        print("Has Whisper Result: \(whisperResult != nil)")
        
        if let finalResult = finalResult {
            print("Chosen Engine: \(finalResult.chosenEngine.displayName)")
            print("Final Confidence: \(String(format: "%.2f", finalResult.confidence))")
            print("Similarity Score: \(String(format: "%.2f", finalResult.similarityScore))")
            print("Needs Review: \(finalResult.needsReview)")
            print("Reason: \(finalResult.reason)")
        }
        
        if let detected = detectedLanguage {
            print("Detected Language: \(detected.displayName) (confidence: \(String(format: "%.2f", languageConfidence)))")
        }
        
        if let whisperResult = whisperResult {
            print("Whisper Language: \(whisperResult.detectedLanguage ?? "unknown")")
            print("Whisper Confidence: \(String(format: "%.2f", whisperResult.confidence))")
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
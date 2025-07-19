import Foundation
import AVFoundation

/// Service for handling OpenAI Whisper API transcription
@MainActor
class WhisperService: ObservableObject {
    static let shared = WhisperService()
    
    @Published var isProcessing = false
    @Published var lastError: String?
    
    private let urlSession = URLSession.shared
    
    init() {}
    
    /// Transcribe audio data using OpenAI Whisper API
    func transcribeAudio(data: Data, language: SupportedLanguage? = nil) async -> WhisperResult? {
        guard Config.hasValidOpenAIKey else {
            setError("OpenAI API key not configured")
            return nil
        }
        
        guard data.count > 0 else {
            setError("Empty audio data")
            return nil
        }
        
        // Check file size limit
        let sizeInMB = Double(data.count) / (1024 * 1024)
        if sizeInMB > Config.maxWhisperAudioSizeMB {
            setError("Audio file too large: \(String(format: "%.1f", sizeInMB))MB (max: \(Config.maxWhisperAudioSizeMB)MB)")
            return nil
        }
        
        await MainActor.run {
            isProcessing = true
            lastError = nil
        }
        
        do {
            let result = try await performWhisperRequest(audioData: data, language: language)
            await MainActor.run {
                isProcessing = false
            }
            return result
        } catch {
            setError("Whisper API error: \(error.localizedDescription)")
            await MainActor.run {
                isProcessing = false
            }
            return nil
        }
    }
    
    /// Transcribe audio file using OpenAI Whisper API
    func transcribeAudioFile(url: URL, language: SupportedLanguage? = nil) async -> WhisperResult? {
        do {
            let data = try Data(contentsOf: url)
            return await transcribeAudio(data: data, language: language)
        } catch {
            setError("Failed to read audio file: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Convert AVAudioPCMBuffer to audio data for Whisper API
    func transcribeAudioBuffer(_ buffer: AVAudioPCMBuffer, language: SupportedLanguage? = nil) async -> WhisperResult? {
        guard let audioData = convertBufferToWAVData(buffer) else {
            setError("Failed to convert audio buffer to data")
            return nil
        }
        
        return await transcribeAudio(data: audioData, language: language)
    }
    
    // MARK: - Private Methods
    
    private func performWhisperRequest(audioData: Data, language: SupportedLanguage?) async throws -> WhisperResult {
        guard let url = URL(string: Config.whisperAPIEndpoint) else {
            throw WhisperError.invalidURL
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(Config.openAIAPIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add audio file
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"audio.wav\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/wav\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add model parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
        body.append("whisper-1\r\n".data(using: .utf8)!)
        
        // Add language parameter if specified
        if let language = language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language.languageCode)\r\n".data(using: .utf8)!)
        }
        
        // Add response format
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"response_format\"\r\n\r\n".data(using: .utf8)!)
        body.append("verbose_json\r\n".data(using: .utf8)!)
        
        // Add temperature for consistency
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"temperature\"\r\n\r\n".data(using: .utf8)!)
        body.append("0.2\r\n".data(using: .utf8)!)
        
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorData["error"] as? [String: Any],
               let message = error["message"] as? String {
                throw WhisperError.apiError(message)
            }
            throw WhisperError.httpError(httpResponse.statusCode)
        }
        
        return try parseWhisperResponse(data)
    }
    
    private func parseWhisperResponse(_ data: Data) throws -> WhisperResult {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw WhisperError.invalidJSON
        }
        
        guard let text = json["text"] as? String else {
            throw WhisperError.missingText
        }
        
        // Extract language if detected
        let detectedLanguage = json["language"] as? String
        
        // Extract confidence and segments if available
        var totalConfidence: Double = 1.0
        var segments: [WhisperSegment] = []
        
        if let segmentsArray = json["segments"] as? [[String: Any]] {
            for segmentData in segmentsArray {
                if let segmentText = segmentData["text"] as? String,
                   let start = segmentData["start"] as? Double,
                   let end = segmentData["end"] as? Double {
                    
                    let confidence = segmentData["avg_logprob"] as? Double
                    let segment = WhisperSegment(
                        text: segmentText,
                        start: start,
                        end: end,
                        confidence: confidence
                    )
                    segments.append(segment)
                }
            }
            
            // Calculate average confidence from segments
            let confidences = segments.compactMap { $0.confidence }
            if !confidences.isEmpty {
                totalConfidence = confidences.reduce(0, +) / Double(confidences.count)
                // Convert log probability to confidence (approximate)
                totalConfidence = max(0, min(1, (totalConfidence + 5) / 5))
            }
        }
        
        return WhisperResult(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            detectedLanguage: detectedLanguage,
            confidence: totalConfidence,
            segments: segments
        )
    }
    
    private func convertBufferToWAVData(_ buffer: AVAudioPCMBuffer) -> Data? {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatInt16, 
                                       sampleRate: buffer.format.sampleRate, 
                                       channels: buffer.format.channelCount, 
                                       interleaved: false) else {
            return nil
        }
        
        guard let converter = AVAudioConverter(from: buffer.format, to: format) else {
            return nil
        }
        
        let frameLength = AVAudioFrameCount(buffer.frameLength)
        guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength) else {
            return nil
        }
        
        var error: NSError?
        let status = converter.convert(to: convertedBuffer, error: &error) { _, _ in
            return buffer
        }
        
        guard status == .haveData, error == nil else {
            return nil
        }
        
        return createWAVData(from: convertedBuffer)
    }
    
    private func createWAVData(from buffer: AVAudioPCMBuffer) -> Data? {
        guard let channelData = buffer.int16ChannelData else { return nil }
        
        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        let sampleRate = Int(buffer.format.sampleRate)
        let bytesPerFrame = channels * 2 // 16-bit = 2 bytes per sample
        let dataSize = frames * bytesPerFrame
        
        var data = Data()
        
        // WAV Header
        data.append("RIFF".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(36 + dataSize).littleEndian) { Data($0) })
        data.append("WAVE".data(using: .ascii)!)
        
        // Format chunk
        data.append("fmt ".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(16).littleEndian) { Data($0) }) // Chunk size
        data.append(withUnsafeBytes(of: UInt16(1).littleEndian) { Data($0) })  // PCM format
        data.append(withUnsafeBytes(of: UInt16(channels).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate).littleEndian) { Data($0) })
        data.append(withUnsafeBytes(of: UInt32(sampleRate * bytesPerFrame).littleEndian) { Data($0) }) // Byte rate
        data.append(withUnsafeBytes(of: UInt16(bytesPerFrame).littleEndian) { Data($0) }) // Block align
        data.append(withUnsafeBytes(of: UInt16(16).littleEndian) { Data($0) }) // Bits per sample
        
        // Data chunk
        data.append("data".data(using: .ascii)!)
        data.append(withUnsafeBytes(of: UInt32(dataSize).littleEndian) { Data($0) })
        
        // Audio data
        for frame in 0..<frames {
            for channel in 0..<channels {
                let sample = channelData[channel][frame]
                data.append(withUnsafeBytes(of: sample.littleEndian) { Data($0) })
            }
        }
        
        return data
    }
    
    @MainActor
    private func setError(_ message: String) {
        lastError = message
        print("WhisperService Error: \(message)")
    }
}

// MARK: - Data Models

struct WhisperResult {
    let text: String
    let detectedLanguage: String?
    let confidence: Double
    let segments: [WhisperSegment]
    
    /// Convert detected language string to SupportedLanguage
    var supportedLanguage: SupportedLanguage? {
        guard let detectedLanguage = detectedLanguage else { return nil }
        
        // Map Whisper language codes to SupportedLanguage
        switch detectedLanguage.lowercased() {
        case "en", "english": return .english
        case "es", "spanish": return .spanish
        case "fr", "french": return .french
        case "de", "german": return .german
        case "it", "italian": return .italian
        case "pt", "portuguese": return .portuguese
        case "ja", "japanese": return .japanese
        case "zh", "chinese": return .chinese
        case "ko", "korean": return .korean
        case "ru", "russian": return .russian
        case "tr", "turkish": return .turkish
        default: return nil
        }
    }
}

struct WhisperSegment {
    let text: String
    let start: Double
    let end: Double
    let confidence: Double?
}

enum WhisperError: LocalizedError {
    case invalidURL
    case invalidResponse
    case invalidJSON
    case missingText
    case apiError(String)
    case httpError(Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Whisper API URL"
        case .invalidResponse:
            return "Invalid response from Whisper API"
        case .invalidJSON:
            return "Invalid JSON response from Whisper API"
        case .missingText:
            return "No transcription text in Whisper response"
        case .apiError(let message):
            return "Whisper API error: \(message)"
        case .httpError(let code):
            return "HTTP error \(code) from Whisper API"
        }
    }
}
import SwiftUI

/// Self-healing UX for transcript review and correction
struct TranscriptReviewView: View {
    let transcriptResult: TranscriptComparisonResult
    let onAccept: () -> Void
    let onEdit: (String) -> Void
    let onReprocess: () -> Void
    let onDismiss: () -> Void
    
    @State private var showingEditSheet = false
    @State private var editedText = ""
    @State private var showingDetails = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: transcriptResult.needsReview ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundColor(transcriptResult.needsReview ? .orange : .green)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Transcription Review")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(transcriptResult.needsReview ? "Review Recommended" : "High Quality")
                        .font(.caption)
                        .foregroundColor(transcriptResult.needsReview ? .orange : .green)
                }
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            
            // Transcript content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Main transcript
                    Text(transcriptResult.chosenTranscript)
                        .font(.body)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    
                    // Quality indicators
                    qualityIndicators
                    
                    // Comparison details (if available)
                    if showingDetails {
                        comparisonDetails
                    }
                }
            }
            .frame(maxHeight: 200)
            
            // Action buttons
            actionButtons
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(16)
        .shadow(radius: 10)
        .padding(.horizontal)
        .sheet(isPresented: $showingEditSheet) {
            editTranscriptSheet
        }
        .onAppear {
            editedText = transcriptResult.chosenTranscript
        }
    }
    
    private var qualityIndicators: some View {
        HStack {
            // Confidence indicator
            HStack(spacing: 4) {
                Image(systemName: "gauge.medium")
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text("Confidence")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(Int(transcriptResult.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(confidenceColor)
            }
            
            Spacer()
            
            // Engine indicator
            HStack(spacing: 4) {
                Image(systemName: engineIcon)
                    .font(.caption)
                    .foregroundColor(.purple)
                
                Text(transcriptResult.chosenEngine.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Details toggle
            Button(action: { showingDetails.toggle() }) {
                HStack(spacing: 2) {
                    Text("Details")
                        .font(.caption)
                    
                    Image(systemName: showingDetails ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private var comparisonDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Analysis Details")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            if let appleText = transcriptResult.appleText,
               let whisperText = transcriptResult.whisperText {
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Apple Speech:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(appleText)
                        .font(.caption)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    Text("Whisper:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Text(whisperText)
                        .font(.caption)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            Text("Similarity: \(Int(transcriptResult.similarityScore * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("Reason: \(transcriptResult.reason)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Accept button
            Button(action: onAccept) {
                HStack {
                    Image(systemName: "checkmark")
                    Text("Accept")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.green)
                .cornerRadius(8)
            }
            
            // Edit button
            Button(action: { showingEditSheet = true }) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Reprocess button (if Whisper available)
            if Config.hasValidOpenAIKey && Config.enableDualEngineTranscription {
                Button(action: onReprocess) {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Reprocess")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    private var editTranscriptSheet: some View {
        NavigationView {
            VStack(spacing: 16) {
                Text("Edit Transcript")
                    .font(.headline)
                    .padding(.top)
                
                TextEditor(text: $editedText)
                    .font(.body)
                    .padding(8)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                    .frame(minHeight: 150)
                
                Spacer()
            }
            .padding()
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingEditSheet = false
                        editedText = transcriptResult.chosenTranscript
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onEdit(editedText)
                        showingEditSheet = false
                    }
                    .fontWeight(.semibold)
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEditSheet = false
                        editedText = transcriptResult.chosenTranscript
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onEdit(editedText)
                        showingEditSheet = false
                    }
                    .fontWeight(.semibold)
                    .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                #endif
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private var confidenceColor: Color {
        if transcriptResult.confidence >= 0.8 {
            return .green
        } else if transcriptResult.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var engineIcon: String {
        switch transcriptResult.chosenEngine {
        case .appleSpeech:
            return "applelogo"
        case .whisper:
            return "waveform.path.ecg"
        case .none:
            return "questionmark.circle"
        }
    }
}

/// Compact version for inline display
struct TranscriptQualityIndicator: View {
    let transcriptResult: TranscriptComparisonResult
    let showDetails: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            // Quality indicator
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            
            if showDetails {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(transcriptResult.chosenEngine.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                        
                        Text("\(Int(transcriptResult.confidence * 100))%")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    if transcriptResult.needsReview {
                        Text("Review recommended")
                            .font(.caption2)
                            .foregroundColor(.orange)
                    }
                }
            } else {
                Text("\(Int(transcriptResult.confidence * 100))%")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(qualityColor)
            }
        }
    }
    
    private var qualityColor: Color {
        if transcriptResult.confidence >= 0.8 {
            return .green
        } else if transcriptResult.confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

/// Floating review prompt that appears when transcript needs review
struct FloatingTranscriptReviewPrompt: View {
    let transcriptResult: TranscriptComparisonResult
    let onShowReview: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        
                        Text("Transcript Review")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    
                    Text("Low confidence transcription")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Review", action: onShowReview)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
            .shadow(radius: 8)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

#Preview {
    VStack {
        TranscriptReviewView(
            transcriptResult: TranscriptComparisonResult(
                chosenTranscript: "This is a sample transcript that needs review",
                chosenEngine: .whisper,
                confidence: 0.65,
                reason: "Low confidence Apple Speech result",
                appleText: "This is a sample transcript that needs review",
                whisperText: "This is a sample transcript that needs review",
                similarityScore: 0.85
            ),
            onAccept: {},
            onEdit: { _ in },
            onReprocess: {},
            onDismiss: {}
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Quality Indicator") {
    VStack(spacing: 20) {
        TranscriptQualityIndicator(
            transcriptResult: TranscriptComparisonResult(
                chosenTranscript: "High quality transcript",
                chosenEngine: .whisper,
                confidence: 0.95,
                reason: "High confidence",
                appleText: nil,
                whisperText: nil,
                similarityScore: 0.0
            ),
            showDetails: true
        )
        
        TranscriptQualityIndicator(
            transcriptResult: TranscriptComparisonResult(
                chosenTranscript: "Low quality transcript",
                chosenEngine: .appleSpeech,
                confidence: 0.45,
                reason: "Low confidence",
                appleText: nil,
                whisperText: nil,
                similarityScore: 0.0
            ),
            showDetails: false
        )
    }
    .padding()
}
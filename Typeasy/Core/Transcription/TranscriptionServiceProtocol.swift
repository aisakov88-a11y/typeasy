import Foundation

/// Protocol for speech-to-text transcription services
/// Allows switching between different STT engines (WhisperKit, GigaAM, etc.)
@MainActor
protocol TranscriptionServiceProtocol: ObservableObject {
    /// Whether the model is currently loaded and ready for transcription
    var isModelLoaded: Bool { get }

    /// Download progress (0.0 to 1.0)
    var downloadProgress: Double { get }

    /// Current download/loading status message
    var downloadStatus: String { get }

    /// Initialize the transcription service and load the model
    /// Downloads the model if necessary
    func initialize() async throws

    /// Transcribe audio samples to text
    /// - Parameters:
    ///   - audioSamples: Audio data as Float32 array (16kHz mono)
    ///   - language: Optional language code (e.g., "ru", "en", nil for auto-detect)
    ///   - contextPrompt: Optional context hint for better recognition (e.g., custom vocabulary)
    /// - Returns: Transcription result with text and metadata
    func transcribe(audioSamples: [Float], language: String?, contextPrompt: String?) async throws -> TranscriptionResultData
}

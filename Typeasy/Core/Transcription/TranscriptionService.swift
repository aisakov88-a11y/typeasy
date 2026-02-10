import Foundation
import WhisperKit
import AVFoundation

/// Service for speech-to-text transcription using WhisperKit
@MainActor
final class TranscriptionService: ObservableObject {
    // MARK: - Properties

    private var whisperKit: WhisperKit?
    @Published var isModelLoaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""

    private let modelName: String
    private let computeOptions: ModelComputeOptions

    // MARK: - Initialization

    init(modelName: String = "openai_whisper-base") {
        self.modelName = modelName

        // Configure compute options for best performance
        self.computeOptions = ModelComputeOptions(
            audioEncoderCompute: .cpuAndGPU, // Use both CPU and GPU for encoder
            textDecoderCompute: .cpuAndGPU   // Use both CPU and GPU for decoder
        )
    }

    /// Initialize WhisperKit with model download/loading
    func initialize(modelName: String? = nil) async throws {
        let model = modelName ?? self.modelName
        NSLog("🎤 TranscriptionService.initialize() called with model: \(model)")

        do {
            // Try to load from local cache first
            NSLog("📦 Attempting to load model from cache...")
            downloadStatus = "Loading model from cache..."

            // Check if model exists locally
            let modelPath = try await getLocalModelPath(model)

            if FileManager.default.fileExists(atPath: modelPath) {
                NSLog("✅ Found local model at: \(modelPath)")
                whisperKit = try await WhisperKit(
                    modelFolder: modelPath,
                    computeOptions: computeOptions,
                    verbose: true,
                    logLevel: .debug
                )
            } else {
                // Download model with progress tracking
                NSLog("📥 Model not found locally, downloading...")
                downloadStatus = "Downloading model..."

                // Use WhisperKit's built-in download with our cache directory
                whisperKit = try await WhisperKit(
                    model: model,
                    computeOptions: computeOptions,
                    verbose: true,
                    logLevel: .debug,
                    prewarm: true,
                    load: true,
                    download: true
                )
            }

            isModelLoaded = true
            downloadProgress = 1.0
            downloadStatus = "Model loaded successfully"
            NSLog("✅ WhisperKit initialized successfully with model: \(model)")

        } catch {
            NSLog("❌ WhisperKit initialization failed: \(error)")
            downloadStatus = "Failed to load model: \(error.localizedDescription)"
            throw PipelineError.modelNotLoaded
        }
    }

    /// Get local model path in Hugging Face cache
    private func getLocalModelPath(_ modelName: String) async throws -> String {
        // WhisperKit stores models in ~/Library/Caches/huggingface/hub/models--argmaxinc--whisperkit-coreml
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let hubPath = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("huggingface")
            .appendingPathComponent("hub")

        // Look for model directory
        let modelSearchPattern = "models--argmaxinc--whisperkit-coreml"

        if let enumerator = FileManager.default.enumerator(atPath: hubPath.path) {
            for case let path as String in enumerator {
                if path.contains(modelSearchPattern) && path.contains(modelName) {
                    return hubPath.appendingPathComponent(path).path
                }
            }
        }

        // Model not found locally
        return ""
    }

    /// Transcribe audio samples to text
    func transcribe(audioSamples: [Float], language: String? = nil) async throws -> TranscriptionResultData {
        guard let whisperKit = whisperKit else {
            NSLog("❌ WhisperKit not initialized")
            throw PipelineError.modelNotLoaded
        }

        guard !audioSamples.isEmpty else {
            return TranscriptionResultData(text: "", language: nil, segments: [])
        }

        NSLog("🎤 Starting transcription with \(audioSamples.count) samples")

        do {
            // Use specified language or default to Russian
            // Russian is primary language, but WhisperKit can auto-detect English
            let targetLanguage = language ?? "ru"
            NSLog("📝 Using language: \(targetLanguage)")

            // Configure transcription options
            let options = DecodingOptions(
                verbose: true,
                task: .transcribe,  // Use transcribe, not translate
                language: targetLanguage,  // Use specified language (ru or en)
                temperature: 0.0,   // Greedy decoding for better accuracy
                temperatureFallbackCount: 3,
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                clipTimestamps: [],
                chunkingStrategy: nil
            )

            // Transcribe
            let result = try await whisperKit.transcribe(
                audioArray: audioSamples,
                decodeOptions: options
            )

            guard let transcriptionResult = result.first else {
                NSLog("❌ No transcription result")
                return TranscriptionResultData(text: "", language: nil, segments: [])
            }

            let text = transcriptionResult.text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            NSLog("✅ Transcription completed: '\(text)'")
            NSLog("🌍 Detected language: \(transcriptionResult.language ?? "unknown")")

            // Convert segments
            let segments = transcriptionResult.segments.map { segment in
                TranscriptionSegmentData(
                    text: segment.text,
                    start: segment.start,
                    end: segment.end
                )
            }

            return TranscriptionResultData(
                text: text,
                language: transcriptionResult.language,
                segments: segments
            )

        } catch {
            NSLog("❌ Transcription failed: \(error)")
            throw PipelineError.transcriptionFailed(error.localizedDescription)
        }
    }
}

// MARK: - Data Models

struct TranscriptionResultData {
    let text: String
    let language: String?
    let segments: [TranscriptionSegmentData]
}

struct TranscriptionSegmentData {
    let text: String
    let start: Float
    let end: Float
}

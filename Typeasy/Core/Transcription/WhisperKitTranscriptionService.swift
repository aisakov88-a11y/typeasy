import Foundation
import WhisperKit
import AVFoundation

/// Service for speech-to-text transcription using WhisperKit
@MainActor
final class WhisperKitTranscriptionService: ObservableObject, TranscriptionServiceProtocol {
    // MARK: - Properties

    private var whisperKit: WhisperKit?
    @Published var isModelLoaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""

    private let modelName: String
    private let computeOptions: ModelComputeOptions

    // MARK: - Initialization

    init(modelName: String = "openai_whisper-large-v3_turbo") {
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
        NSLog("🎤 WhisperKitTranscriptionService.initialize() called with model: \(model)")

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

    // Protocol conformance: provide overload without modelName parameter
    func initialize() async throws {
        try await initialize(modelName: nil)
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
    /// - Parameters:
    ///   - audioSamples: Audio data as Float32 array
    ///   - language: Language code (optional)
    ///   - contextPrompt: Context hint for better recognition of specific terms (optional)
    func transcribe(audioSamples: [Float], language: String? = nil, contextPrompt: String? = nil) async throws -> TranscriptionResultData {
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

            // Tokenize context prompt if provided
            var promptTokens: [Int]? = nil
            if let context = contextPrompt, !context.isEmpty, let tokenizer = whisperKit.tokenizer {
                promptTokens = tokenizer.encode(text: context)
                NSLog("🔤 Using context prompt: '\(context.prefix(50))...' (\(promptTokens?.count ?? 0) tokens)")
            }

            // Configure transcription options for balanced quality and speed
            let options = DecodingOptions(
                verbose: true,
                task: .transcribe,  // Use transcribe, not translate
                language: targetLanguage,  // Use specified language (ru or en)
                temperature: 0.0,   // Greedy decoding for better accuracy
                temperatureFallbackCount: 1,  // Reduced from 3 for faster processing
                sampleLength: 224,
                topK: 5,
                usePrefillPrompt: true,
                usePrefillCache: true,
                skipSpecialTokens: true,
                withoutTimestamps: false,
                wordTimestamps: false,  // Disabled for 2-3x faster processing
                clipTimestamps: [],
                promptTokens: promptTokens,  // Context prompt for better recognition
                suppressBlank: true,  // Suppress blank tokens for cleaner output
                compressionRatioThreshold: 2.8,  // Increased from 2.4 to reduce hallucinations
                logProbThreshold: -0.8,  // Stricter threshold (was -1.0)
                firstTokenLogProbThreshold: -1.2,  // Stricter first token (was -1.5)
                noSpeechThreshold: 0.7,  // Higher threshold to filter silence better (was 0.6)
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

import Foundation
import SherpaOnnx

/// Service for speech-to-text transcription using GigaAM-v3 E2E RNN-T via sherpa-onnx
/// GigaAM-v3 RNN-T with automatic punctuation - optimized for Russian with 50% better accuracy than Whisper
/// Produces punctuated, normalized text directly without requiring LLM post-processing
@MainActor
final class GigaAMTranscriptionService: ObservableObject, TranscriptionServiceProtocol {
    // MARK: - Published Properties

    @Published var isModelLoaded = false
    @Published var downloadProgress: Double = 0.0
    @Published var downloadStatus: String = ""

    // MARK: - Private Properties

    private var recognizer: OpaquePointer? // sherpa-onnx C API pointer (will be implemented after framework builds)
    private let modelCacheDir: URL

    // MARK: - Model Configuration

    private let modelName = "sherpa-onnx-nemo-transducer-punct-giga-am-v3-russian-2025-12-16"
    private let huggingFaceRepo = "csukuangfj/sherpa-onnx-nemo-transducer-punct-giga-am-v3-russian-2025-12-16"

    // MARK: - Initialization

    init() {
        // Setup model cache directory
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        modelCacheDir = homeDir
            .appendingPathComponent("Library")
            .appendingPathComponent("Caches")
            .appendingPathComponent("typeasy")
            .appendingPathComponent("gigaam")

        NSLog("🎤 GigaAMTranscriptionService initialized with cache dir: \(modelCacheDir.path)")
    }

    // MARK: - TranscriptionServiceProtocol Implementation

    /// Initialize the GigaAM model
    /// Downloads the model if not already cached
    func initialize() async throws {
        print("🔄 GigaAMTranscriptionService.initialize() called")
        NSLog("🔄 GigaAMTranscriptionService.initialize() called")
        downloadStatus = "Checking for model..."

        // 1. Check if model exists locally
        let modelPath = modelCacheDir.appendingPathComponent(modelName)
        print("📂 Checking model path: \(modelPath.path)")
        NSLog("📂 Checking model path: \(modelPath.path)")

        let modelExists = FileManager.default.fileExists(atPath: modelPath.path)
        print("📂 Model exists: \(modelExists)")
        NSLog("📂 Model exists: \(modelExists)")

        if !modelExists {
            // 2. Download model automatically
            NSLog("📥 Model not found, starting download...")
            downloadStatus = "Downloading GigaAM-v3 RNN-T with punctuation..."
            try await downloadModel()
            NSLog("✅ Download completed!")
        } else {
            NSLog("✅ Model found in cache: \(modelPath.path)")
        }

        // 3. Load model using sherpa-onnx C API
        NSLog("📦 Loading model...")
        downloadStatus = "Loading model with punctuation..."
        try loadModel(from: modelPath)

        isModelLoaded = true
        downloadProgress = 1.0
        downloadStatus = "GigaAM-v3 with punctuation loaded successfully"
        NSLog("✅ GigaAM-v3 RNN-T with punctuation loaded successfully")
    }

    /// Download GigaAM-v3 model from HuggingFace
    private func downloadModel() async throws {
        NSLog("🚀 downloadModel() started")
        let repoURL = "https://huggingface.co/\(huggingFaceRepo)/resolve/main"
        NSLog("📍 Repo URL: \(repoURL)")

        let files = [
            "encoder.int8.onnx",    // Encoder (quantized) - 214MB
            "decoder.onnx",         // Decoder - 4.4MB
            "joiner.onnx",          // Joiner - 2.6MB
            "tokens.txt",           // Vocabulary tokens (1025 tokens) - 13KB
            "README.md"             // Documentation - 302B
        ]
        NSLog("📋 Files to download: \(files.count)")

        // Create model directory
        let modelPath = modelCacheDir.appendingPathComponent(modelName)
        NSLog("📂 Creating directory: \(modelPath.path)")
        try FileManager.default.createDirectory(
            at: modelPath,
            withIntermediateDirectories: true
        )

        NSLog("📂 Created model directory: \(modelPath.path)")

        // Configure URLSession with timeout and redirect handling
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300  // 5 minutes for large files
        config.timeoutIntervalForResource = 3600  // 1 hour total
        config.httpMaximumConnectionsPerHost = 1
        let session = URLSession(configuration: config)

        // Download each file with progress tracking
        for (index, file) in files.enumerated() {
            let fileURL = URL(string: "\(repoURL)/\(file)")!
            let destination = modelPath.appendingPathComponent(file)

            // Skip if file already exists
            if FileManager.default.fileExists(atPath: destination.path) {
                NSLog("⏭️ Skipping \(file) (already exists)")
                continue
            }

            NSLog("📥 Downloading \(file) from \(fileURL)...")
            downloadStatus = "Downloading \(file)..."

            do {
                // Create request with proper headers
                var request = URLRequest(url: fileURL)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")
                request.setValue("*/*", forHTTPHeaderField: "Accept")
                request.httpMethod = "GET"

                // Use data(for:) instead of bytes(for:) - much faster for large files
                let (data, response) = try await session.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw PipelineError.modelNotLoaded
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    NSLog("❌ HTTP \(httpResponse.statusCode) for \(file)")
                    throw PipelineError.modelNotLoaded
                }

                // Write to destination
                try data.write(to: destination)
                NSLog("✅ Downloaded \(file) (\(data.count) bytes)")

                // Update progress
                let overallProgress = Double(index + 1) / Double(files.count)
                await MainActor.run {
                    self.downloadProgress = overallProgress
                    self.downloadStatus = "Downloaded \(file) (\(data.count / 1_000_000)MB)"
                }

            } catch {
                NSLog("❌ Failed to download \(file): \(error)")
                throw PipelineError.modelNotLoaded
            }
        }

        session.invalidateAndCancel()
        NSLog("✅ All model files downloaded successfully")
    }

    /// Load GigaAM-v3 RNN-T model with punctuation using sherpa-onnx C API
    private func loadModel(from path: URL) throws {
        NSLog("🔄 Loading GigaAM-v3 RNN-T model with punctuation from: \(path.path)")

        // Prepare file paths for transducer model (encoder, decoder, joiner)
        let encoderPath = path.appendingPathComponent("encoder.int8.onnx").path
        let decoderPath = path.appendingPathComponent("decoder.onnx").path
        let joinerPath = path.appendingPathComponent("joiner.onnx").path
        let tokensPath = path.appendingPathComponent("tokens.txt").path

        // Verify all files exist
        guard FileManager.default.fileExists(atPath: encoderPath) else {
            NSLog("❌ Encoder file not found: \(encoderPath)")
            throw PipelineError.modelNotLoaded
        }
        guard FileManager.default.fileExists(atPath: decoderPath) else {
            NSLog("❌ Decoder file not found: \(decoderPath)")
            throw PipelineError.modelNotLoaded
        }
        guard FileManager.default.fileExists(atPath: joinerPath) else {
            NSLog("❌ Joiner file not found: \(joinerPath)")
            throw PipelineError.modelNotLoaded
        }
        guard FileManager.default.fileExists(atPath: tokensPath) else {
            NSLog("❌ Tokens file not found: \(tokensPath)")
            throw PipelineError.modelNotLoaded
        }

        NSLog("📂 Encoder: \(encoderPath)")
        NSLog("📂 Decoder: \(decoderPath)")
        NSLog("📂 Joiner: \(joinerPath)")
        NSLog("📂 Tokens: \(tokensPath)")

        // Create recognizer configuration
        var config = SherpaOnnxOfflineRecognizerConfig()

        // Configure feature extraction
        config.feat_config.sample_rate = 16000  // Must match AudioCaptureManager
        config.feat_config.feature_dim = 80     // Standard for speech models

        // Configure NeMo Transducer model (GigaAM-v3 RNN-T with punctuation)
        // Use strdup and convert to UnsafePointer (immutable)
        let encoderPathCStr = strdup(encoderPath)
        let decoderPathCStr = strdup(decoderPath)
        let joinerPathCStr = strdup(joinerPath)
        let tokensPathCStr = strdup(tokensPath)
        let providerCStr = strdup("cpu")
        let modelTypeCStr = strdup("")
        let decodingMethodCStr = strdup("greedy_search")

        config.model_config.transducer.encoder = UnsafePointer(encoderPathCStr)
        config.model_config.transducer.decoder = UnsafePointer(decoderPathCStr)
        config.model_config.transducer.joiner = UnsafePointer(joinerPathCStr)
        config.model_config.tokens = UnsafePointer(tokensPathCStr)
        config.model_config.num_threads = 4     // Use multiple CPU cores
        config.model_config.debug = 0           // Disable debug output
        config.model_config.provider = UnsafePointer(providerCStr)
        config.model_config.model_type = UnsafePointer(modelTypeCStr)

        // Configure decoding for RNN-T
        config.decoding_method = UnsafePointer(decodingMethodCStr)
        config.max_active_paths = 4

        // Create recognizer
        NSLog("🔧 Creating sherpa-onnx offline transducer recognizer with punctuation...")
        recognizer = SherpaOnnxCreateOfflineRecognizer(&config)

        // Free string duplicates (config is copied internally by sherpa-onnx)
        free(encoderPathCStr)
        free(decoderPathCStr)
        free(joinerPathCStr)
        free(tokensPathCStr)
        free(providerCStr)
        free(modelTypeCStr)
        free(decodingMethodCStr)

        guard recognizer != nil else {
            NSLog("❌ Failed to create transducer recognizer - SherpaOnnxCreateOfflineRecognizer returned nil")
            throw PipelineError.modelNotLoaded
        }

        NSLog("✅ GigaAM-v3 RNN-T recognizer with punctuation created successfully")
    }

    /// Transcribe audio samples to Russian text
    /// - Parameters:
    ///   - audioSamples: Audio data as Float32 array (16kHz mono)
    ///   - language: Ignored - GigaAM only supports Russian
    ///   - contextPrompt: Ignored - GigaAM doesn't support context prompts
    /// - Returns: Transcription result
    func transcribe(audioSamples: [Float], language: String?, contextPrompt: String?) async throws -> TranscriptionResultData {
        guard let recognizer = recognizer else {
            NSLog("❌ GigaAM recognizer not initialized")
            throw PipelineError.modelNotLoaded
        }

        guard !audioSamples.isEmpty else {
            NSLog("⚠️ Empty audio samples")
            return TranscriptionResultData(text: "", language: "ru", segments: [])
        }

        // Process in 30-second chunks to avoid crashes on long recordings
        let chunkSize = 30 * 16000  // 30 seconds at 16kHz
        let totalChunks = (audioSamples.count + chunkSize - 1) / chunkSize
        NSLog("🎤 Starting GigaAM transcription: \(audioSamples.count) samples, \(totalChunks) chunk(s)")

        // Run transcription on background thread to avoid blocking main thread
        return try await Task.detached {
            var texts: [String] = []

            for i in 0..<totalChunks {
                let start = i * chunkSize
                let end = min(start + chunkSize, audioSamples.count)
                let chunk = Array(audioSamples[start..<end])

                NSLog("🔍 Processing chunk \(i + 1)/\(totalChunks)...")

                guard let stream = SherpaOnnxCreateOfflineStream(recognizer) else {
                    NSLog("❌ Failed to create offline stream for chunk \(i + 1)")
                    throw PipelineError.transcriptionFailed("Failed to create stream")
                }

                chunk.withUnsafeBufferPointer { buffer in
                    guard let baseAddress = buffer.baseAddress else { return }
                    SherpaOnnxAcceptWaveformOffline(stream, 16000, baseAddress, Int32(buffer.count))
                }

                SherpaOnnxDecodeOfflineStream(recognizer, stream)

                if let result = SherpaOnnxGetOfflineStreamResult(stream) {
                    if let textPtr = result.pointee.text {
                        let text = String(cString: textPtr).trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            texts.append(text)
                        }
                    }
                    SherpaOnnxDestroyOfflineRecognizerResult(result)
                }

                SherpaOnnxDestroyOfflineStream(stream)
            }

            let fullText = texts.joined(separator: " ")
            NSLog("✅ GigaAM transcription completed (\(totalChunks) chunks): '\(fullText)'")

            return TranscriptionResultData(
                text: fullText,
                language: "ru",
                segments: []
            )
        }.value
    }

    // MARK: - Cleanup

    deinit {
        // Cleanup sherpa-onnx resources
        if let recognizer = recognizer {
            SherpaOnnxDestroyOfflineRecognizer(recognizer)
            NSLog("🧹 GigaAM recognizer destroyed")
        }
    }
}

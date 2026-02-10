import SwiftUI
import Combine
import HotKey

/// Main orchestrator for the dictation flow
@MainActor
final class DictationPipeline: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: PipelineState = .idle
    @Published private(set) var lastTranscription: String = ""
    @Published private(set) var lastProcessedText: String = ""
    @Published private(set) var whisperModelLoaded: Bool = false
    @Published private(set) var llmModelLoaded: Bool = false

    // MARK: - Services

    private let audioCaptureManager = AudioCaptureManager()

    // Dual transcription services
    private let gigaAMService = GigaAMTranscriptionService()
    private let whisperKitService = WhisperKitTranscriptionService()

    private let llmService = LLMService()
    private let textInsertionService = TextInsertionService()

    // Current active service
    private var activeTranscriptionService: any TranscriptionServiceProtocol
    private var selectedSTTEngine: STTEngine = .gigaAM

    // MARK: - Hotkey

    private var hotKey: HotKey?

    // MARK: - Settings

    private var enableLLMProcessing: Bool = false
    private var llmPrompt: String = DefaultPrompts.cleanup
    private var selectedLanguage: Language = .russian
    private var textReplacements: [TextReplacement] = []
    private var whisperContextPrompt: String = DefaultPrompts.whisperContext

    // MARK: - Initialization

    init() {
        // Default to GigaAM service with punctuation
        activeTranscriptionService = gigaAMService

        NSLog("🚀 DictationPipeline init() called")
        writeLog("🚀 DictationPipeline init() called")

        state = .initializing
        setupHotkey()

        // Auto-initialize models on creation
        Task { @MainActor in
            NSLog("📦 Starting model initialization task...")
            writeLog("📦 Starting model initialization task...")
            do {
                try await self.initializeModels()
            } catch {
                NSLog("❌ Failed to initialize models in init: \(error)")
                writeLog("❌ Failed to initialize models in init: \(error)")
            }
        }
    }

    private func writeLog(_ message: String) {
        let logFile = "/tmp/typeasy_debug.log"
        let timestamp = Date().formatted()
        let logMessage = "[\(timestamp)] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let fileHandle = FileHandle(forWritingAtPath: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }

    private func setupHotkey() {
        // Cmd+Shift+D
        hotKey = HotKey(key: .d, modifiers: [.command, .shift])
        hotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
    }

    // MARK: - Public Methods

    /// Toggle recording state
    func toggleRecording() async {
        switch state {
        case .idle:
            await startRecording()
        case .recording:
            await stopAndProcess()
        default:
            // Ignore during processing
            break
        }
    }

    /// Initialize all models
    func initializeModels() async throws {
        NSLog("🔄 Starting model initialization...")
        writeLog("🔄 Starting model initialization...")
        state = .initializing
        whisperModelLoaded = false
        llmModelLoaded = false

        do {
            NSLog("📝 Initializing Speech Recognition (\(selectedSTTEngine.displayName))...")
            writeLog("📝 Initializing Speech Recognition (\(selectedSTTEngine.displayName))...")

            // Initialize active STT engine
            NSLog("🔀 Switching on STT engine: \(selectedSTTEngine.rawValue)")
            writeLog("🔀 Switching on STT engine: \(selectedSTTEngine.rawValue)")
            switch selectedSTTEngine {
            case .gigaAM:
                NSLog("📥 Calling gigaAMService.initialize()...")
                writeLog("📥 Calling gigaAMService.initialize()...")
                try await gigaAMService.initialize()
                NSLog("📥 gigaAMService.initialize() completed")
                writeLog("📥 gigaAMService.initialize() completed")
                whisperModelLoaded = gigaAMService.isModelLoaded
            case .whisperKit:
                NSLog("📥 Calling whisperKitService.initialize()...")
                writeLog("📥 Calling whisperKitService.initialize()...")
                try await whisperKitService.initialize()
                NSLog("📥 whisperKitService.initialize() completed")
                writeLog("📥 whisperKitService.initialize() completed")
                whisperModelLoaded = whisperKitService.isModelLoaded
            }

            NSLog("✅ Speech Recognition initialized, loaded: \(whisperModelLoaded)")
            writeLog("✅ Speech Recognition initialized, loaded: \(whisperModelLoaded)")

            NSLog("🤖 Initializing LLM service...")
            writeLog("🤖 Initializing LLM service...")
            try await llmService.initialize()
            llmModelLoaded = llmService.isModelLoaded
            NSLog("✅ LLM service initialized, loaded: \(llmModelLoaded)")
            writeLog("✅ LLM service initialized, loaded: \(llmModelLoaded)")

            state = .idle
            NSLog("✅ All models initialized successfully")
            writeLog("✅ All models initialized successfully")
        } catch {
            NSLog("❌ Model initialization failed: \(error.localizedDescription)")
            writeLog("❌ Model initialization failed: \(error.localizedDescription)")
            state = .error(.modelNotLoaded)
            throw error
        }
    }

    /// Update settings from AppState
    func updateSettings(
        enableLLM: Bool,
        prompt: String,
        language: Language? = nil,
        replacements: [TextReplacement]? = nil,
        whisperModel: WhisperModel? = nil,
        sttEngine: STTEngine? = nil
    ) {
        NSLog("⚙️ Updating settings: enableLLM=\(enableLLM), language=\(language?.rawValue ?? "unchanged")")
        writeLog("⚙️ Updating settings: enableLLM=\(enableLLM), prompt length=\(prompt.count)")
        self.enableLLMProcessing = enableLLM
        self.llmPrompt = prompt
        if let language = language {
            self.selectedLanguage = language
        }
        if let replacements = replacements {
            self.textReplacements = replacements
            NSLog("⚙️ Updated text replacements: \(replacements.count) rules")
            writeLog("⚙️ Updated text replacements: \(replacements.count) rules")
        }

        // Handle STT engine switch
        if let engine = sttEngine, engine != selectedSTTEngine {
            NSLog("⚙️ STT engine change requested: \(engine.displayName)")
            writeLog("⚙️ STT engine change requested: \(engine.displayName)")
            Task {
                await switchSTTEngine(engine)
            }
        }

        // Handle WhisperKit model change (only if WhisperKit is active)
        if let model = whisperModel, selectedSTTEngine == .whisperKit {
            NSLog("⚙️ Model change requested: \(model.displayName)")
            writeLog("⚙️ Model change requested: \(model.displayName)")
            Task {
                await changeWhisperModel(model)
            }
        }
    }

    /// Change Whisper model
    func changeWhisperModel(_ model: WhisperModel) async {
        NSLog("🔄 Changing Whisper model to: \(model.fullModelName)")
        writeLog("🔄 Changing Whisper model to: \(model.fullModelName)")
        state = .initializing
        whisperModelLoaded = false

        do {
            try await whisperKitService.initialize(modelName: model.fullModelName)
            whisperModelLoaded = whisperKitService.isModelLoaded
            state = .idle
            NSLog("✅ Model changed successfully to \(model.displayName)")
            writeLog("✅ Model changed successfully to \(model.displayName)")
        } catch {
            NSLog("❌ Failed to change model: \(error)")
            writeLog("❌ Failed to change model: \(error)")
            state = .error(.modelNotLoaded)
        }
    }

    /// Switch STT engine (GigaAM ↔ WhisperKit)
    private func switchSTTEngine(_ engine: STTEngine) async {
        NSLog("🔄 Switching STT engine to: \(engine.displayName)")
        writeLog("🔄 Switching STT engine to: \(engine.displayName)")
        state = .initializing
        selectedSTTEngine = engine
        whisperModelLoaded = false

        do {
            switch engine {
            case .gigaAM:
                activeTranscriptionService = gigaAMService
                try await gigaAMService.initialize()
                whisperModelLoaded = gigaAMService.isModelLoaded
            case .whisperKit:
                activeTranscriptionService = whisperKitService
                try await whisperKitService.initialize()
                whisperModelLoaded = whisperKitService.isModelLoaded
            }

            state = .idle
            NSLog("✅ STT engine switched successfully to \(engine.displayName)")
            writeLog("✅ STT engine switched successfully")
        } catch {
            NSLog("❌ Failed to switch STT engine: \(error)")
            writeLog("❌ Failed to switch STT engine: \(error)")
            state = .error(.modelNotLoaded)
        }
    }

    /// Update hotkey
    func updateHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            Task { @MainActor in
                await self?.toggleRecording()
            }
        }
    }

    // MARK: - Private Methods

    private func startRecording() async {
        NSLog("🎤 Starting recording...")
        writeLog("🎤 Starting recording...")
        do {
            state = .recording
            try await audioCaptureManager.startCapture()
            NSLog("✅ Recording started successfully")
            writeLog("✅ Recording started successfully")
        } catch {
            NSLog("❌ Recording failed: \(error)")
            writeLog("❌ Recording failed: \(error)")
            state = .error(.audioCaptureFailed(error.localizedDescription))
        }
    }

    private func stopAndProcess() async {
        NSLog("⏹️ Stopping recording and processing...")
        writeLog("⏹️ Stopping recording and processing...")

        // Stop recording and get audio samples
        let audioSamples = audioCaptureManager.stopCapture()
        NSLog("📊 Captured \(audioSamples.count) audio samples")
        writeLog("📊 Captured \(audioSamples.count) audio samples")

        guard !audioSamples.isEmpty else {
            NSLog("⚠️ No audio samples captured")
            writeLog("⚠️ No audio samples captured")
            state = .idle
            return
        }

        // Transcribe
        state = .transcribing
        NSLog("📝 Starting transcription with language: \(selectedLanguage.rawValue) using \(selectedSTTEngine.displayName)")
        writeLog("📝 Starting transcription with language: \(selectedLanguage.rawValue)")
        do {
            // Convert Language enum to language code (ru/en/nil for auto)
            let languageCode = selectedLanguage == .auto ? nil : selectedLanguage.rawValue
            // Pass context prompt for WhisperKit (GigaAM ignores it)
            let transcription = try await activeTranscriptionService.transcribe(
                audioSamples: audioSamples,
                language: languageCode,
                contextPrompt: whisperContextPrompt
            )
            lastTranscription = transcription.text
            NSLog("✅ Transcription: '\(transcription.text)'")
            writeLog("✅ Transcription: '\(transcription.text)'")

            guard !transcription.text.isEmpty else {
                NSLog("⚠️ Empty transcription")
                writeLog("⚠️ Empty transcription")
                state = .idle
                return
            }

            var finalText = transcription.text

            // LLM processing (if enabled)
            NSLog("🤖 LLM processing enabled: \(enableLLMProcessing)")
            writeLog("🤖 LLM processing enabled: \(enableLLMProcessing)")
            if enableLLMProcessing {
                state = .processing
                NSLog("🧹 Starting LLM cleanup...")
                writeLog("🧹 Starting LLM cleanup with prompt length: \(llmPrompt.count)")
                do {
                    let processedText = try await llmService.cleanupText(
                        transcription.text,
                        prompt: llmPrompt
                    )
                    finalText = processedText
                    lastProcessedText = processedText
                    NSLog("✅ LLM processed text: '\(processedText)'")
                    writeLog("✅ LLM processed text: '\(processedText)'")
                } catch {
                    // Fall back to raw transcription if LLM fails
                    NSLog("❌ LLM processing failed: \(error), using raw transcription")
                    writeLog("❌ LLM processing failed: \(error), using raw transcription")
                    finalText = transcription.text
                    lastProcessedText = transcription.text
                }
            } else {
                NSLog("⏭️ Skipping LLM processing (disabled)")
                writeLog("⏭️ Skipping LLM processing (disabled)")
                finalText = transcription.text
                lastProcessedText = transcription.text
            }

            // Apply custom text replacements AFTER LLM processing
            if !textReplacements.isEmpty {
                NSLog("🔄 Applying \(textReplacements.count) text replacements...")
                writeLog("🔄 Text before replacements: '\(finalText)'")
                let beforeReplacements = finalText
                var replacementsApplied = 0

                for replacement in textReplacements {
                    let result = replacement.apply(to: finalText)
                    if result != finalText {
                        replacementsApplied += 1
                        NSLog("  ✓ Replaced '\(replacement.trigger)' → '\(replacement.replacement)'")
                    }
                    finalText = result
                }

                if replacementsApplied > 0 {
                    NSLog("✅ Applied \(replacementsApplied)/\(textReplacements.count) replacements")
                    writeLog("✅ Text after replacements: '\(finalText)'")
                } else {
                    NSLog("ℹ️ No replacement triggers found in text")
                }
            }

            // Insert text
            state = .inserting
            NSLog("📋 Inserting text: '\(finalText)'")
            writeLog("📋 Inserting text: '\(finalText)'")
            try textInsertionService.insertText(finalText)
            NSLog("✅ Text inserted successfully")
            writeLog("✅ Text inserted successfully")

            state = .idle

        } catch let error as PipelineError {
            NSLog("❌ Pipeline error: \(error)")
            writeLog("❌ Pipeline error: \(error)")
            state = .error(error)
        } catch {
            NSLog("❌ Transcription error: \(error)")
            writeLog("❌ Transcription error: \(error)")
            state = .error(.transcriptionFailed(error.localizedDescription))
        }
    }
}

import AVFoundation
import Accelerate

/// Manages audio capture from the microphone
final class AudioCaptureManager {
    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private var audioSamples: [Float] = []
    private let sampleRate: Double = 16000 // WhisperKit requirement
    private var isCapturing = false

    private let lock = NSLock() // For audio samples array
    private let captureLock = NSLock() // For capture state management

    // MARK: - Public Methods

    /// Start capturing audio from the microphone
    func startCapture() async throws {
        // Permission check MUST happen before locking — await suspends the task
        // and NSLock requires unlock on the same OS thread that called lock(),
        // so holding it across an await causes SIGABRT when the task resumes
        // on a different thread.
        let permission = await requestMicrophonePermission()
        guard permission else {
            throw PipelineError.microphonePermissionDenied
        }

        // Guard + state update in a short synchronous critical section (no await inside)
        captureLock.lock()
        guard !isCapturing else {
            captureLock.unlock()
            NSLog("⚠️ AudioCaptureManager: Already capturing, ignoring duplicate call")
            return
        }
        isCapturing = true
        captureLock.unlock()

        // Ensure flag is reset on early exit
        var engineStarted = false
        defer {
            if !engineStarted { isCapturing = false }
        }

        // Safety: stop engine and remove any existing tap before installing new one
        let inputNode = audioEngine.inputNode
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        inputNode.removeTap(onBus: 0) // Safe to call even if no tap exists

        lock.lock()
        audioSamples.removeAll()
        lock.unlock()

        let inputFormat = inputNode.outputFormat(forBus: 0)

        // Create format for WhisperKit (16kHz mono Float32)
        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw PipelineError.audioCaptureFailed("Failed to create audio format")
        }

        // Create converter for resampling
        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            throw PipelineError.audioCaptureFailed("Failed to create audio converter")
        }

        // Install tap with error handling
        do {
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                self?.processAudioBuffer(buffer, converter: converter, outputFormat: whisperFormat)
            }
        } catch {
            // If tap installation fails, log and rethrow
            NSLog("❌ Failed to install tap: \(error)")
            isCapturing = false
            throw PipelineError.audioCaptureFailed("Failed to install audio tap: \(error.localizedDescription)")
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            engineStarted = true
            NSLog("✅ Audio engine started successfully")
        } catch {
            // If start fails, cleanup and rethrow
            NSLog("❌ Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            throw PipelineError.audioCaptureFailed("Failed to start audio engine: \(error.localizedDescription)")
        }
    }

    /// Stop capturing and return collected audio samples
    func stopCapture() -> [Float] {
        captureLock.lock()
        defer { captureLock.unlock() }

        guard isCapturing else {
            NSLog("⚠️ stopCapture called but not capturing")
            return []
        }

        // Remove tap first, then stop engine
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false

        lock.lock()
        let samples = audioSamples
        audioSamples.removeAll()
        lock.unlock()

        NSLog("✅ Audio capture stopped, collected \(samples.count) samples")
        return samples
    }

    // MARK: - Private Methods

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        // Calculate output frame count based on sample rate ratio
        let ratio = outputFormat.sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        guard error == nil,
              let channelData = outputBuffer.floatChannelData else { return }

        let samples = Array(UnsafeBufferPointer(
            start: channelData[0],
            count: Int(outputBuffer.frameLength)
        ))

        lock.lock()
        audioSamples.append(contentsOf: samples)
        lock.unlock()
    }
}

import AVFoundation
import Accelerate

/// Manages audio capture from the microphone
final class AudioCaptureManager {
    // MARK: - Properties

    private var audioEngine = AVAudioEngine()
    private var audioSamples: [Float] = []
    private let sampleRate: Double = 16000 // WhisperKit requirement
    private var isCapturing = false

    private let lock = NSLock() // For audio samples array
    private let captureLock = NSLock() // For capture state management

    // MARK: - Public Methods

    /// Start capturing audio from the microphone
    func startCapture() async throws {
        // Permission check MUST happen before locking — this is the only async
        // point in this function; NSLock must not be held across await.
        let permission = await requestMicrophonePermission()
        guard permission else {
            throw PipelineError.microphonePermissionDenied
        }

        // Hold captureLock for the ENTIRE audio-engine setup (no await below).
        //
        // Race we're fixing: startCapture() runs on a thread-pool thread after
        // the await, while stopCapture() runs on the main thread. Without the
        // lock covering installTap, stopCapture() can run between
        // "isCapturing = true" and "installTap", leaving isCapturing=false but
        // a tap still installed. The next startCapture() then tries to install
        // a second tap → NSInternalInconsistencyException crash.
        captureLock.lock()
        defer { captureLock.unlock() }

        guard !isCapturing else {
            NSLog("⚠️ AudioCaptureManager: Already capturing, ignoring duplicate call")
            return
        }
        isCapturing = true

        // Recreate the engine on every session — this guarantees a clean slate
        // with no stale tap, regardless of how the previous session ended.
        // removeTap alone is not sufficient when AVAudioEngine retains internal
        // tap state after an unexpected stop.
        audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode

        lock.lock()
        audioSamples.removeAll()
        lock.unlock()

        let inputFormat = inputNode.outputFormat(forBus: 0)

        guard let whisperFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            isCapturing = false
            throw PipelineError.audioCaptureFailed("Failed to create audio format")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: whisperFormat) else {
            isCapturing = false
            throw PipelineError.audioCaptureFailed("Failed to create audio converter")
        }

        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: whisperFormat)
        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            NSLog("✅ Audio engine started successfully")
        } catch {
            NSLog("❌ Failed to start audio engine: \(error)")
            inputNode.removeTap(onBus: 0)
            isCapturing = false
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

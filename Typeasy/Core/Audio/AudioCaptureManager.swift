import AVFoundation
import Accelerate

/// Manages audio capture from the microphone.
///
/// @MainActor isolation guarantees that all AVAudioEngine operations
/// (installTap, removeTap, start, stop) run on the main thread, eliminating
/// the threading races that caused NSInternalInconsistencyException crashes.
@MainActor
final class AudioCaptureManager {
    // MARK: - Properties

    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 16000
    private var isCapturing = false

    // Written from the audio thread (tap callback), read from main thread.
    // Protected by samplesLock; marked nonisolated(unsafe) so the
    // nonisolated processAudioBuffer can access it directly.
    private nonisolated let samplesLock = NSLock()
    private nonisolated(unsafe) var audioSamples: [Float] = []

    // MARK: - Public Methods

    /// Start capturing audio from the microphone.
    func startCapture() async throws {
        guard !isCapturing else {
            NSLog("⚠️ AudioCaptureManager: Already capturing, ignoring duplicate call")
            return
        }
        // Set BEFORE the permission await so any concurrent stopCapture()
        // (which can run on main actor during the suspension) sees it.
        isCapturing = true

        let permission = await requestMicrophonePermission()
        guard permission else {
            isCapturing = false
            throw PipelineError.microphonePermissionDenied
        }

        // Back on main actor — safe to configure AVAudioEngine.
        let inputNode = audioEngine.inputNode

        // Always remove any lingering tap before installing a new one.
        inputNode.removeTap(onBus: 0)

        samplesLock.lock()
        audioSamples.removeAll()
        samplesLock.unlock()

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

        if audioEngine.isRunning {
            audioEngine.stop()
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

    /// Stop capturing and return collected audio samples.
    func stopCapture() -> [Float] {
        guard isCapturing else {
            NSLog("⚠️ stopCapture called but not capturing")
            return []
        }

        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isCapturing = false

        samplesLock.lock()
        let samples = audioSamples
        audioSamples.removeAll()
        samplesLock.unlock()

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

    /// Called from the AVAudioEngine tap — runs on a private audio thread.
    /// nonisolated so it can be called without hopping to the main actor.
    private nonisolated func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
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

        samplesLock.lock()
        audioSamples.append(contentsOf: samples)
        samplesLock.unlock()
    }
}

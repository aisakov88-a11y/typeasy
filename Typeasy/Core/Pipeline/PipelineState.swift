import Foundation

/// Represents the current state of the dictation pipeline
enum PipelineState: Equatable {
    case initializing
    case idle
    case recording
    case transcribing
    case processing
    case inserting
    case error(PipelineError)

    var isActive: Bool {
        switch self {
        case .idle, .error:
            return false
        case .initializing:
            return true
        default:
            return true
        }
    }

    var statusText: String {
        switch self {
        case .initializing:
            return "Loading models..."
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .processing:
            return "Processing..."
        case .inserting:
            return "Inserting..."
        case .error(let error):
            return "Error: \(error.localizedDescription)"
        }
    }

    var iconName: String {
        switch self {
        case .initializing:
            return "arrow.down.circle"
        case .idle:
            return "mic"
        case .recording:
            return "mic.fill"
        case .transcribing:
            return "waveform"
        case .processing:
            return "brain"
        case .inserting:
            return "doc.on.clipboard"
        case .error:
            return "exclamationmark.triangle"
        }
    }

    static func == (lhs: PipelineState, rhs: PipelineState) -> Bool {
        switch (lhs, rhs) {
        case (.initializing, .initializing),
             (.idle, .idle),
             (.recording, .recording),
             (.transcribing, .transcribing),
             (.processing, .processing),
             (.inserting, .inserting):
            return true
        case (.error(let lhsError), .error(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Errors that can occur in the dictation pipeline
enum PipelineError: LocalizedError {
    case microphonePermissionDenied
    case accessibilityPermissionDenied
    case audioCaptureFailed(String)
    case transcriptionFailed(String)
    case llmProcessingFailed(String)
    case textInsertionFailed(String)
    case modelNotLoaded
    case cancelled

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access required"
        case .accessibilityPermissionDenied:
            return "Accessibility access required"
        case .audioCaptureFailed(let reason):
            return "Audio capture failed: \(reason)"
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .llmProcessingFailed(let reason):
            return "Text processing failed: \(reason)"
        case .textInsertionFailed(let reason):
            return "Text insertion failed: \(reason)"
        case .modelNotLoaded:
            return "Model not loaded"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}

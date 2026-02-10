import Foundation

/// Collection of prompt templates for LLM text processing
enum PromptTemplates {
    /// Default cleanup prompt for speech-to-text output
    static let defaultCleanup = """
        Fix the following transcribed text:
        - Correct punctuation and capitalization
        - Remove filler words (um, uh, like / эм, ну, типа, короче)
        - Fix obvious transcription errors
        - Keep the original meaning and tone
        - Output ONLY the corrected text, no explanations

        Text: [transcription]
        """

    /// Minimal cleanup - just punctuation
    static let minimalCleanup = """
        Add proper punctuation and capitalization to this text.
        Output ONLY the corrected text:

        [transcription]
        """

    /// Professional/formal style
    static let professionalStyle = """
        Clean up this transcribed text for professional use:
        - Correct all punctuation and grammar
        - Remove filler words and verbal hesitations
        - Make the language more formal and polished
        - Keep the original meaning intact
        - Output ONLY the corrected text

        Text: [transcription]
        """

    /// Casual/informal style
    static let casualStyle = """
        Clean up this transcribed text while keeping it casual:
        - Add basic punctuation
        - Remove obvious filler words (um, uh)
        - Keep contractions and informal language
        - Output ONLY the corrected text

        Text: [transcription]
        """

    /// Available preset templates
    static let presets: [(name: String, prompt: String)] = [
        ("Default", defaultCleanup),
        ("Minimal", minimalCleanup),
        ("Professional", professionalStyle),
        ("Casual", casualStyle)
    ]
}

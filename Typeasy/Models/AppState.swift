import SwiftUI
import Combine

/// Global application state
@MainActor
final class AppState: ObservableObject {
    // MARK: - User Preferences

    @AppStorage("sttEngine") var sttEngine: STTEngine = .gigaAM
    @AppStorage("selectedLanguage") var selectedLanguage: Language = .russian
    @AppStorage("llmPrompt") var llmPrompt: String = DefaultPrompts.cleanup
    @AppStorage("enableLLMProcessing") var enableLLMProcessing: Bool = false
    @AppStorage("whisperModelRaw") private var whisperModelRaw: String = "large-v3_turbo"
    @AppStorage("whisperContextPrompt") var whisperContextPrompt: String = DefaultPrompts.whisperContext

    var whisperModel: WhisperModel {
        get { WhisperModel(rawValue: whisperModelRaw) ?? .largev3turbo }
        set { whisperModelRaw = newValue.rawValue }
    }

    // Text replacements (stored as JSON)
    @Published var textReplacements: [TextReplacement] = []
    private let replacementsKey = "textReplacements"

    // MARK: - Model Status

    @Published var isWhisperModelLoaded: Bool = false
    @Published var isLLMModelLoaded: Bool = false
    @Published var modelDownloadProgress: Double = 0.0
    @Published var modelDownloadStatus: String = ""

    // MARK: - Permissions

    @Published var hasMicrophonePermission: Bool = false
    @Published var hasAccessibilityPermission: Bool = false

    // MARK: - Initialization

    init() {
        checkPermissions()
        loadReplacements()
    }

    func checkPermissions() {
        // Will be implemented in PermissionService
    }

    func resetPromptToDefault() {
        llmPrompt = DefaultPrompts.cleanup
    }

    // MARK: - Text Replacements

    func loadReplacements() {
        if let data = UserDefaults.standard.data(forKey: replacementsKey),
           let decoded = try? JSONDecoder().decode([TextReplacement].self, from: data) {
            textReplacements = decoded
        } else {
            // Set default replacements
            textReplacements = []
        }
    }

    func saveReplacements() {
        if let encoded = try? JSONEncoder().encode(textReplacements) {
            UserDefaults.standard.set(encoded, forKey: replacementsKey)
        }
    }

    func addReplacement(_ replacement: TextReplacement) {
        textReplacements.append(replacement)
        saveReplacements()
    }

    func removeReplacement(at index: Int) {
        textReplacements.remove(at: index)
        saveReplacements()
    }

    func updateReplacement(at index: Int, with replacement: TextReplacement) {
        textReplacements[index] = replacement
        saveReplacements()
    }
}

// MARK: - STT Engine Enum

enum STTEngine: String, CaseIterable, Identifiable {
    case gigaAM = "gigaam"
    case whisperKit = "whisperkit"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .gigaAM: return "GigaAM-v3 E2E (Russian + Punctuation)"
        case .whisperKit: return "WhisperKit (Multilingual)"
        }
    }

    var description: String {
        switch self {
        case .gigaAM: return "50% better accuracy, automatic punctuation, no LLM needed"
        case .whisperKit: return "Supports 90+ languages, larger models"
        }
    }

    var supportedLanguages: [Language] {
        switch self {
        case .gigaAM: return [.russian]
        case .whisperKit: return Language.allCases
        }
    }
}

// MARK: - Language Enum

enum Language: String, CaseIterable, Identifiable {
    case auto = "auto"
    case russian = "ru"
    case english = "en"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "Auto-detect"
        case .russian: return "Русский"
        case .english: return "English"
        }
    }
}

// MARK: - Whisper Model Enum

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny = "tiny"
    case base = "base"
    case small = "small"
    case largev3 = "large-v3"
    case largev3turbo = "large-v3_turbo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (fast, less accurate)"
        case .base: return "Base (balanced)"
        case .small: return "Small (accurate)"
        case .largev3: return "Large V3 (best quality, slowest)"
        case .largev3turbo: return "Large V3 Turbo (fast, very accurate)"
        }
    }

    var fullModelName: String {
        return "openai_whisper-\(rawValue)"
    }

    var modelSize: String {
        switch self {
        case .tiny: return "~40 MB"
        case .base: return "~140 MB"
        case .small: return "~466 MB"
        case .largev3: return "~1.5 GB"
        case .largev3turbo: return "~954 MB"
        }
    }

    var speed: String {
        switch self {
        case .tiny: return "Very fast (~1-2s)"
        case .base: return "Fast (~2-3s)"
        case .small: return "Medium (~3-5s)"
        case .largev3: return "Very slow (~10-20s)"
        case .largev3turbo: return "Slow (~5-10s)"
        }
    }
}

// MARK: - Default Prompts

enum DefaultPrompts {
    static let cleanup = """
        You are fixing transcription errors from Whisper speech recognition. The input often contains NONSENSICAL PHRASES that are mishearings of technical terms.

        CRITICAL RULES:
        1. If you see nonsensical/meaningless Russian words in technical context → they are ALWAYS misheard technical terms
        2. Look at the overall meaning of the sentence to infer the correct technical term
        3. Replace nonsense with the most likely technical term that fits the context

        EXAMPLES OF NONSENSICAL PHRASES (must fix):
        - "даже Борт" / "оба борта" / "деш борд" → "дашборд" or "dashboard"
        - "Фреджа" / "ущерба" / "редаш" → "Redash" (BI tool)
        - "табло" / "таблоу" → "Tableau"
        - "мета база" / "метабейс" → "Metabase"

        Common Whisper transcription errors for technical terms:

          Products & Tools:
          * "кодекс" / "код экс" → "Codex"
          * "копайлот" / "ко пилот" → "CoPilot"
          * "клод код" / "клод code" → "Claude Code"
          * "гитхаб" / "гит хаб" → "GitHub"
          * "гит лаб" → "GitLab"
          * "ущерба" / "редаш" → "Redash"
          * "табло" / "таблоу" → "Tableau"
          * "метабейс" → "Metabase"
          * "постман" → "Postman"
          * "слак" → "Slack"
          * "джира" → "Jira"
          * "конфлюенс" → "Confluence"
          * "нотион" / "ноушен" → "Notion"
          * "фигма" → "Figma"

          Programming Languages:
          * "джава скрипт" / "ява скрипт" → "JavaScript"
          * "тайпскрипт" / "тип скрипт" → "TypeScript"
          * "пайтон" → "Python"
          * "джава" → "Java"
          * "котлин" → "Kotlin"
          * "свифт" → "Swift"
          * "го" / "голанг" → "Go"
          * "раст" → "Rust"

          Technologies & Frameworks:
          * "докер" → "Docker"
          * "кубернетес" / "куб ернетес" → "Kubernetes"
          * "реакт" → "React"
          * "вью" → "Vue"
          * "ангуляр" → "Angular"
          * "нод" / "нода" → "Node"
          * "нест" → "Nest"
          * "экспресс" → "Express"
          * "фласк" → "Flask"
          * "джанго" → "Django"
          * "спринг" → "Spring"

          UI/UX Terms:
          * "оба борта" / "деш борд" / "дэшборд" → "дашборд" (or "dashboard" in English context)
          * "кастомный" → "кастомный" (already correct, but watch for "custom")
          * "модал" / "модалка" → "модал" (or "modal")
          * "дропдаун" → "дропдаун" (or "dropdown")
          * "попап" → "попап" (or "popup")

          API & Data:
          * "апи" / "АПИ" → "API"
          * "рест апи" → "REST API"
          * "граф кьюэл" / "граф кюэл" → "GraphQL"
          * "джейсон" / "жейсон" → "JSON"
          * "эн пи эм" → "npm"
          * "ярн" → "Yarn"
          * "эс кью эл" → "SQL"
          * "ноэс кью эл" → "NoSQL"
          * "постгрес" → "PostgreSQL"
          * "монго" → "MongoDB"
          * "редис" → "Redis"

        - If you see a nonsensical phrase in a technical context (like "оба борта ущерба"), it's likely a mishearing of technical terms
        - Use the overall context of the sentence to infer the correct technical term
        - If a Russian word sounds like a technical term, infer the correct English term from context

        TEXT CLEANUP:
        - Correct punctuation and capitalization
        - Remove filler words (um, uh, like / эм, ну, типа, короче)
        - Keep the original meaning and tone
        - IMPORTANT: Preserve the original form of address (ты/вы) - do NOT change informal "ты" to formal "вы" or vice versa!

        LANGUAGE RULES:
        - IMPORTANT: Keep the same language as the input text (if input is Russian, output must be Russian; if English, output must be English)
        - IMPORTANT: Technical terms, product names, and proper nouns should be in their original language (usually English) with correct capitalization
        - When Russian text contains English technical terms, keep them in English with proper capitalization

        OUTPUT:
        - Output ONLY the corrected text, no explanations or notes

        Text: [transcription]
        """

    static let whisperContext = """
        Notion, Trello, GrowthBook, Redash, Claude Code, ChatGPT, Gemini, GitHub, Jira, Figma, Docker, Kubernetes, TypeScript, JavaScript, API, дашборд, ивенты, фичи, айдишник, юзер, таск, баг, вайбкодить
        """
}

// MARK: - Text Replacement

struct TextReplacement: Identifiable, Codable, Equatable {
    let id: UUID
    var trigger: String      // What to look for (e.g., "рабочая почта")
    var replacement: String  // What to replace with (e.g., "aisakov@artworkout.app")
    var caseSensitive: Bool  // Whether to match case exactly

    init(id: UUID = UUID(), trigger: String, replacement: String, caseSensitive: Bool = false) {
        self.id = id
        self.trigger = trigger
        self.replacement = replacement
        self.caseSensitive = caseSensitive
    }

    /// Apply this replacement to the given text
    func apply(to text: String) -> String {
        if caseSensitive {
            return text.replacingOccurrences(of: trigger, with: replacement)
        } else {
            return text.replacingOccurrences(of: trigger, with: replacement, options: .caseInsensitive)
        }
    }
}

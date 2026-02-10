import SwiftUI
import HotKey

@main
struct TypeasyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var pipeline = DictationPipeline()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(pipeline)
                .task {
                    // Initialize pipeline with current settings
                    pipeline.updateSettings(
                        enableLLM: appState.enableLLMProcessing,
                        prompt: appState.llmPrompt,
                        language: appState.selectedLanguage,
                        replacements: appState.textReplacements,
                        whisperModel: appState.whisperModel,
                        sttEngine: appState.sttEngine
                    )
                }
        } label: {
            Label {
                Text("Typeasy")
            } icon: {
                Image(systemName: pipeline.state == .recording ? "mic.fill" : "mic")
            }
        }
        .onChange(of: appState.enableLLMProcessing) { _, newValue in
            pipeline.updateSettings(enableLLM: newValue, prompt: appState.llmPrompt, language: appState.selectedLanguage, replacements: appState.textReplacements)
        }
        .onChange(of: appState.llmPrompt) { _, newValue in
            pipeline.updateSettings(enableLLM: appState.enableLLMProcessing, prompt: newValue, language: appState.selectedLanguage, replacements: appState.textReplacements)
        }
        .onChange(of: appState.selectedLanguage) { _, newValue in
            pipeline.updateSettings(enableLLM: appState.enableLLMProcessing, prompt: appState.llmPrompt, language: newValue, replacements: appState.textReplacements)
        }
        .onChange(of: appState.whisperModel) { _, newValue in
            pipeline.updateSettings(enableLLM: appState.enableLLMProcessing, prompt: appState.llmPrompt, language: appState.selectedLanguage, replacements: appState.textReplacements, whisperModel: newValue)
        }
        .onChange(of: appState.sttEngine) { _, newValue in
            pipeline.updateSettings(enableLLM: appState.enableLLMProcessing, prompt: appState.llmPrompt, language: appState.selectedLanguage, replacements: appState.textReplacements, sttEngine: newValue)
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .environmentObject(pipeline)
        }
    }
}

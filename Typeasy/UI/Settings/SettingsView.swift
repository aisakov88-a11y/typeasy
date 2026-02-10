import SwiftUI

/// Main settings window
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            PromptSettingsView()
                .tabItem {
                    Label("Prompt", systemImage: "text.bubble")
                }

            ReplacementsSettingsView()
                .tabItem {
                    Label("Replacements", systemImage: "arrow.left.arrow.right")
                }

            ModelsSettingsView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }

            PermissionsSettingsView()
                .tabItem {
                    Label("Permissions", systemImage: "lock.shield")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section {
                Picker("Language", selection: $appState.selectedLanguage) {
                    ForEach(Language.allCases) { language in
                        // Disable non-Russian languages when GigaAM is selected
                        if appState.sttEngine == .gigaAM && language != .russian {
                            Text("\(language.displayName) (Not supported by GigaAM)")
                                .tag(language)
                                .disabled(true)
                        } else {
                            Text(language.displayName).tag(language)
                        }
                    }
                }
                .pickerStyle(.menu)
                // Auto-force Russian when GigaAM is selected
                .onChange(of: appState.sttEngine) { _, newEngine in
                    if newEngine == .gigaAM && appState.selectedLanguage != .russian {
                        appState.selectedLanguage = .russian
                    }
                }

                Toggle("Enable LLM text processing", isOn: $appState.enableLLMProcessing)

                HStack {
                    Text("Hotkey")
                    Spacer()
                    Text("Cmd+Shift+D")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Dictation")
            }

            Section {
                Toggle("Launch at login", isOn: .constant(false))
                    .disabled(true) // TODO: Implement
            } header: {
                Text("Startup")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Prompt Settings

struct PromptSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingResetAlert = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("LLM Prompt")
                .font(.headline)

            Text("Customize the prompt used to clean up transcribed text. Use [transcription] as a placeholder for the transcribed text.")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $appState.llmPrompt)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 200)
                .border(Color.gray.opacity(0.3), width: 1)

            HStack {
                Spacer()

                Button("Reset to Default") {
                    showingResetAlert = true
                }
                .alert("Reset Prompt?", isPresented: $showingResetAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Reset", role: .destructive) {
                        appState.resetPromptToDefault()
                    }
                } message: {
                    Text("This will replace your custom prompt with the default one.")
                }
            }
        }
        .padding()
    }
}

// MARK: - Models Settings

struct ModelsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        Form {
            // STT Engine Selector
            Section {
                Picker("Speech Recognition Engine", selection: $appState.sttEngine) {
                    ForEach(STTEngine.allCases) { engine in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(engine.displayName)
                            Text(engine.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }.tag(engine)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Status")
                    Spacer()
                    if pipeline.whisperModelLoaded {
                        Label("Loaded", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not loaded", systemImage: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("STT Engine")
            } footer: {
                Text(appState.sttEngine == .gigaAM ?
                     "GigaAM-v3 is optimized for Russian with 50% better accuracy than Whisper. Runs locally on your Mac." :
                     "WhisperKit supports 90+ languages but has lower accuracy on Russian.")
            }

            // WhisperKit model selector (only show if WhisperKit is selected)
            if appState.sttEngine == .whisperKit {
                Section {
                    Picker("Model", selection: $appState.whisperModel) {
                        ForEach(WhisperModel.allCases) { model in
                            Text("\(model.displayName) - \(model.modelSize)").tag(model)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("WhisperKit Model")
                } footer: {
                    Text("WhisperKit runs locally on Apple Silicon. Smaller models are faster but less accurate. Base model is recommended for best balance.")
                }
            }

            // GigaAM details (only show if GigaAM is selected)
            if appState.sttEngine == .gigaAM {
                Section {
                    HStack {
                        Text("Model")
                        Spacer()
                        Text("GigaAM-v3 (226MB)")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Language")
                        Spacer()
                        Text("Russian only")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Accuracy")
                        Spacer()
                        Text("5-7% WER (vs 11-13% Whisper)")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    HStack {
                        Text("Training Data")
                        Spacer()
                        Text("700,000 hours Russian")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("GigaAM-v3 Details")
                }
            }

            Section {
                HStack {
                    Text("Backend")
                    Spacer()
                    Text("LM Studio (OpenAI Compatible)")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Endpoint")
                    Spacer()
                    Text("http://localhost:1234/v1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Status")
                    Spacer()
                    if pipeline.llmModelLoaded {
                        Label("Connected", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Label("Not connected", systemImage: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Text Processing")
            } footer: {
                Text("LM Studio provides local LLM inference with OpenAI-compatible API. Recommended models: Qwen 2.5 7B, Llama 3.2 3B, or similar. Start the server in LM Studio before using.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Replacements Settings

struct ReplacementsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pipeline: DictationPipeline
    @State private var showingAddSheet = false
    @State private var editingReplacement: TextReplacement?

    var body: some View {
        VStack(spacing: 0) {
            // Header with add button
            HStack {
                Text("Custom Text Replacements")
                    .font(.headline)
                Spacer()
                Button(action: { showingAddSheet = true }) {
                    Label("Add", systemImage: "plus")
                }
            }
            .padding()

            Divider()

            // List of replacements
            if appState.textReplacements.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "arrow.left.arrow.right.circle")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("No replacements yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Add custom text replacements for frequently used phrases")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                List {
                    ForEach(Array(appState.textReplacements.enumerated()), id: \.element.id) { index, replacement in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(replacement.trigger)
                                    .font(.body)
                                Text(replacement.replacement)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: {
                                editingReplacement = replacement
                            }) {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            Button(action: {
                                appState.removeReplacement(at: index)
                                updatePipeline()
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Divider()

            // Footer
            Text("Replacements are applied after transcription and LLM processing")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(8)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddReplacementSheet(onSave: { replacement in
                appState.addReplacement(replacement)
                updatePipeline()
                showingAddSheet = false
            }, onCancel: {
                showingAddSheet = false
            })
        }
        .sheet(item: $editingReplacement) { replacement in
            if let index = appState.textReplacements.firstIndex(where: { $0.id == replacement.id }) {
                EditReplacementSheet(
                    replacement: replacement,
                    onSave: { updated in
                        appState.updateReplacement(at: index, with: updated)
                        updatePipeline()
                        editingReplacement = nil
                    },
                    onCancel: {
                        editingReplacement = nil
                    }
                )
            }
        }
    }

    private func updatePipeline() {
        pipeline.updateSettings(
            enableLLM: appState.enableLLMProcessing,
            prompt: appState.llmPrompt,
            language: appState.selectedLanguage,
            replacements: appState.textReplacements
        )
    }
}

// MARK: - Add Replacement Sheet

struct AddReplacementSheet: View {
    @State private var trigger = ""
    @State private var replacement = ""
    @State private var caseSensitive = false

    let onSave: (TextReplacement) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Add Text Replacement")
                .font(.headline)

            Form {
                TextField("Trigger phrase", text: $trigger)
                    .textFieldStyle(.roundedBorder)

                TextField("Replacement text", text: $replacement)
                    .textFieldStyle(.roundedBorder)

                Toggle("Case sensitive", isOn: $caseSensitive)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let newReplacement = TextReplacement(
                        trigger: trigger,
                        replacement: replacement,
                        caseSensitive: caseSensitive
                    )
                    onSave(newReplacement)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trigger.isEmpty || replacement.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}

// MARK: - Edit Replacement Sheet

struct EditReplacementSheet: View {
    @State private var trigger: String
    @State private var replacement: String
    @State private var caseSensitive: Bool

    let onSave: (TextReplacement) -> Void
    let onCancel: () -> Void

    init(replacement: TextReplacement, onSave: @escaping (TextReplacement) -> Void, onCancel: @escaping () -> Void) {
        _trigger = State(initialValue: replacement.trigger)
        _replacement = State(initialValue: replacement.replacement)
        _caseSensitive = State(initialValue: replacement.caseSensitive)
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Edit Text Replacement")
                .font(.headline)

            Form {
                TextField("Trigger phrase", text: $trigger)
                    .textFieldStyle(.roundedBorder)

                TextField("Replacement text", text: $replacement)
                    .textFieldStyle(.roundedBorder)

                Toggle("Case sensitive", isOn: $caseSensitive)
            }
            .formStyle(.grouped)

            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    let updated = TextReplacement(
                        trigger: trigger,
                        replacement: replacement,
                        caseSensitive: caseSensitive
                    )
                    onSave(updated)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(trigger.isEmpty || replacement.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 250)
    }
}

// MARK: - Permissions Settings

struct PermissionsSettingsView: View {
    @EnvironmentObject var appState: AppState
    private let textInsertionService = TextInsertionService()

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Microphone")
                    Spacer()
                    if appState.hasMicrophonePermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Request") {
                            // Will trigger permission dialog on first recording
                        }
                    }
                }

                HStack {
                    Text("Accessibility")
                    Spacer()
                    if appState.hasAccessibilityPermission {
                        Label("Granted", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                    } else {
                        Button("Open Settings") {
                            textInsertionService.requestAccessibilityPermission()
                        }
                    }
                }
            } header: {
                Text("Required Permissions")
            } footer: {
                Text("Microphone permission is required for voice recording. Accessibility permission is required for typing text into other applications.")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

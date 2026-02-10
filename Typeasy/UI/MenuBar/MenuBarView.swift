import SwiftUI

/// Main menu bar dropdown view
struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var pipeline: DictationPipeline

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Status indicator
            HStack {
                Image(systemName: pipeline.state.iconName)
                    .foregroundColor(statusColor)
                Text(pipeline.state.statusText)
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            // Model status (shows during initialization or error)
            if pipeline.state == .initializing || pipeline.state == .error(.modelNotLoaded) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: pipeline.whisperModelLoaded ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(pipeline.whisperModelLoaded ? .green : .gray)
                        Text("WhisperKit")
                            .font(.caption)
                    }
                    HStack {
                        Image(systemName: pipeline.llmModelLoaded ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(pipeline.llmModelLoaded ? .green : .gray)
                        Text("LLM (LM Studio)")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            // Record button
            Button {
                Task {
                    await pipeline.toggleRecording()
                }
            } label: {
                HStack {
                    Image(systemName: pipeline.state == .recording ? "stop.fill" : "mic.fill")
                    Text(pipeline.state == .recording ? "Stop Recording" : "Start Recording")
                    Spacer()
                    Text("Cmd+Shift+D")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .disabled(pipeline.state.isActive && pipeline.state != .recording)
            .padding(.horizontal)

            Divider()

            // Last transcription preview
            if !pipeline.lastProcessedText.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last output:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(pipeline.lastProcessedText)
                        .font(.body)
                        .lineLimit(3)
                        .truncationMode(.tail)
                }
                .padding(.horizontal)

                Divider()
            }

            // Settings
            Button {
                openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings...")
                }
            }
            .padding(.horizontal)

            Divider()

            // Quit
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Typeasy")
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
    }

    private var statusColor: Color {
        switch pipeline.state {
        case .initializing:
            return .orange
        case .idle:
            return .green
        case .recording:
            return .red
        case .transcribing, .processing, .inserting:
            return .orange
        case .error:
            return .red
        }
    }

    private func openSettings() {
        // For menu bar apps (LSUIElement=true), we need to activate the app first
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Try different methods to open settings
        if #available(macOS 14.0, *) {
            // Try the modern approach first
            if let settingsURL = URL(string: "x-apple.systempreferences:com.typeasy.app") {
                // This doesn't work for our app settings, try direct window approach
            }

            // Use the standard settings action
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else if #available(macOS 13.0, *) {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }

        // Also try the keyboard shortcut approach
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let event = NSEvent.keyEvent(
                with: .keyDown,
                location: NSPoint.zero,
                modifierFlags: .command,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                characters: ",",
                charactersIgnoringModifiers: ",",
                isARepeat: false,
                keyCode: 43
            )
            if let event = event {
                NSApp.sendEvent(event)
            }
        }
    }
}

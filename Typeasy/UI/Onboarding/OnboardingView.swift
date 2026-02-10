import SwiftUI

/// First-run onboarding view
struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var permissionService = PermissionService()
    @State private var currentStep = 0

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "mic.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                Text("Welcome to Typeasy")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Voice-to-text with AI-powered cleanup")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Divider()

            // Steps
            TabView(selection: $currentStep) {
                // Step 1: Microphone permission
                PermissionStepView(
                    icon: "mic.fill",
                    title: "Microphone Access",
                    description: "Typeasy needs microphone access to record your voice.",
                    isGranted: permissionService.hasMicrophonePermission,
                    requestAction: {
                        Task {
                            await permissionService.requestMicrophonePermission()
                        }
                    }
                )
                .tag(0)

                // Step 2: Accessibility permission
                PermissionStepView(
                    icon: "hand.raised.fill",
                    title: "Accessibility Access",
                    description: "Typeasy needs accessibility access to type text into other applications.",
                    isGranted: permissionService.hasAccessibilityPermission,
                    requestAction: {
                        permissionService.requestAccessibilityPermission()
                    }
                )
                .tag(1)

                // Step 3: Model download
                ModelDownloadStepView()
                    .tag(2)

                // Step 4: Ready
                ReadyStepView()
                    .tag(3)
            }
            .tabViewStyle(.automatic)

            // Navigation
            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation {
                            currentStep -= 1
                        }
                    }
                }

                Spacer()

                if currentStep < 3 {
                    Button("Next") {
                        withAnimation {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        // Close onboarding
                        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(32)
        .frame(width: 500, height: 450)
    }
}

// MARK: - Permission Step View

struct PermissionStepView: View {
    let icon: String
    let title: String
    let description: String
    let isGranted: Bool
    let requestAction: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(isGranted ? .green : .orange)

            Text(title)
                .font(.title2)
                .fontWeight(.semibold)

            Text(description)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if isGranted {
                Label("Permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Grant Permission") {
                    requestAction()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }
}

// MARK: - Model Download Step View

struct ModelDownloadStepView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundColor(.blue)

            Text("Download Models")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Typeasy will download the speech recognition and text processing models. This may take a few minutes.")
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)

            if appState.modelDownloadProgress > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: appState.modelDownloadProgress)
                    Text(appState.modelDownloadStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if appState.isWhisperModelLoaded && appState.isLLMModelLoaded {
                Label("Models ready", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
    }
}

// MARK: - Ready Step View

struct ReadyStepView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)

            Text("You're all set!")
                .font(.title2)
                .fontWeight(.semibold)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "keyboard")
                        .frame(width: 24)
                    Text("Press **Cmd+Shift+D** to start recording")
                }

                HStack {
                    Image(systemName: "mic.fill")
                        .frame(width: 24)
                    Text("Speak your text naturally")
                }

                HStack {
                    Image(systemName: "sparkles")
                        .frame(width: 24)
                    Text("AI will clean up and insert text")
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .padding()
    }
}

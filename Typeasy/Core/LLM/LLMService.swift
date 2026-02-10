import Foundation

/// Service for LLM-based text post-processing using LM Studio
@MainActor
final class LLMService: ObservableObject {
    // MARK: - Properties

    private let baseURL = "http://localhost:1234/v1"
    private let defaultModel = "local-model" // LM Studio uses "local-model" as default

    @Published var isAvailable = false
    @Published var isProcessing = false
    @Published var currentModel: String = "local-model"

    // MARK: - Initialization

    /// Check if LM Studio is running
    func initialize(modelName: String? = nil) async throws {
        let model = modelName ?? defaultModel
        currentModel = model
        NSLog("🤖 LLMService.initialize() called with model: \(model)")

        // Check if LM Studio is running
        NSLog("🔍 Checking if LM Studio is running...")
        guard await checkLMStudioRunning() else {
            NSLog("❌ LM Studio is not running")
            throw PipelineError.llmProcessingFailed("LM Studio is not running. Please start LM Studio and enable the local server.")
        }
        NSLog("✅ LM Studio is running")

        isAvailable = true
        NSLog("✅ LLMService initialized successfully")
    }

    /// Clean up transcribed text using the LLM
    func cleanupText(_ text: String, prompt: String) async throws -> String {
        guard isAvailable else {
            throw PipelineError.modelNotLoaded
        }

        isProcessing = true
        defer { isProcessing = false }

        // Replace placeholder with actual transcription
        let userPrompt = prompt.replacingOccurrences(of: "[transcription]", with: text)

        do {
            let response = try await generateCompletion(
                model: currentModel,
                userPrompt: userPrompt,
                systemPrompt: "You are a text editor. CRITICAL RULE: NEVER change 'ты' to 'вы' or vice versa - preserve the original form of address exactly as spoken. Follow instructions precisely and output only the corrected text."
            )

            let cleanedText = response.trimmingCharacters(in: .whitespacesAndNewlines)
            return cleanedText.isEmpty ? text : cleanedText

        } catch {
            throw PipelineError.llmProcessingFailed(error.localizedDescription)
        }
    }

    /// Check if the model is loaded
    var isModelLoaded: Bool {
        isAvailable
    }

    // MARK: - Private Methods

    private func checkLMStudioRunning() async -> Bool {
        guard let url = URL(string: "\(baseURL)/models") else { return false }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    private func generateCompletion(model: String, userPrompt: String, systemPrompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/chat/completions") else {
            NSLog("❌ LLM: Invalid URL")
            throw PipelineError.llmProcessingFailed("Invalid URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60 // 60 seconds timeout

        // OpenAI-compatible format
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "temperature": 0.0,
            "max_tokens": 2048,
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        NSLog("🤖 LLM: Sending request to LM Studio...")
        NSLog("🤖 LLM: Prompt length: \(userPrompt.count) chars")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                NSLog("❌ LLM: Not an HTTP response")
                throw PipelineError.llmProcessingFailed("Not an HTTP response")
            }

            NSLog("🤖 LLM: HTTP status code: \(httpResponse.statusCode)")

            if httpResponse.statusCode != 200 {
                let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
                NSLog("❌ LLM: HTTP error \(httpResponse.statusCode): \(errorText)")
                throw PipelineError.llmProcessingFailed("HTTP \(httpResponse.statusCode): \(errorText)")
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

            // Check for error in response
            if let error = json?["error"] as? [String: Any],
               let message = error["message"] as? String {
                NSLog("❌ LLM: LM Studio error: \(message)")
                throw PipelineError.llmProcessingFailed("LM Studio error: \(message)")
            }

            // Extract response from OpenAI format
            guard let choices = json?["choices"] as? [[String: Any]],
                  let firstChoice = choices.first,
                  let message = firstChoice["message"] as? [String: Any],
                  let responseText = message["content"] as? String else {
                NSLog("❌ LLM: Invalid response format, keys: \(json?.keys.joined(separator: ", ") ?? "none")")
                throw PipelineError.llmProcessingFailed("Invalid response format")
            }

            NSLog("✅ LLM: Got response, length: \(responseText.count) chars")
            return responseText

        } catch let error as PipelineError {
            throw error
        } catch {
            NSLog("❌ LLM: Network error: \(error.localizedDescription)")
            throw PipelineError.llmProcessingFailed("Network error: \(error.localizedDescription)")
        }
    }
}

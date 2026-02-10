import AppKit
import Carbon.HIToolbox

/// Service for inserting text into the active application
final class TextInsertionService {
    // MARK: - Properties

    private let pasteboard = NSPasteboard.general

    // Shared logging function
    private func writeLog(_ message: String) {
        let logFile = "/tmp/typeasy_debug.log"
        let timestamp = Date().formatted()
        let logMessage = "[\(timestamp)] \(message)\n"
        if let data = logMessage.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: logFile) {
                if let fileHandle = FileHandle(forWritingAtPath: logFile) {
                    fileHandle.seekToEndOfFile()
                    fileHandle.write(data)
                    fileHandle.closeFile()
                }
            } else {
                try? data.write(to: URL(fileURLWithPath: logFile))
            }
        }
    }

    // MARK: - Public Methods

    /// Insert text into the currently active application
    func insertText(_ text: String) throws {
        guard !text.isEmpty else {
            writeLog("⚠️ TextInsertion: Empty text, skipping")
            return
        }

        writeLog("🔍 TextInsertion: Starting insertion for text: '\(text.prefix(50))...'")

        // Check accessibility permission
        let hasPermission = checkAccessibilityPermission()
        NSLog("🔐 Accessibility permission check: \(hasPermission)")
        writeLog("🔐 Accessibility permission check: \(hasPermission)")

        guard hasPermission else {
            NSLog("❌ Accessibility permission DENIED")
            writeLog("❌ Accessibility permission DENIED")
            throw PipelineError.accessibilityPermissionDenied
        }
        NSLog("✅ Accessibility permission OK, proceeding with paste")
        writeLog("✅ Accessibility permission OK, proceeding with paste")

        // Save original clipboard contents
        let originalContents = pasteboard.string(forType: .string)
        writeLog("💾 Original clipboard saved: \(originalContents?.count ?? 0) chars")

        // Copy new text to clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Verify clipboard was set
        let clipboardVerify = pasteboard.string(forType: .string)
        writeLog("📋 Text copied to clipboard: '\(text.prefix(50))...'")
        writeLog("✓ Clipboard verification: \(clipboardVerify == text ? "SUCCESS" : "FAILED")")

        NSLog("📋 Text copied to clipboard: '\(text.prefix(50))...'")

        // Longer delay to ensure clipboard is ready and app has focus
        usleep(100000) // 100ms
        writeLog("⏱️ Waited 100ms for clipboard readiness")

        // Simulate Cmd+V
        NSLog("⌨️ Simulating Cmd+V paste...")
        writeLog("⌨️ Simulating Cmd+V paste...")
        simulatePaste()
        writeLog("✅ simulatePaste() completed")

        // Restore original clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            if let original = originalContents {
                self?.pasteboard.clearContents()
                self?.pasteboard.setString(original, forType: .string)
                self?.writeLog("♻️ Original clipboard restored")
            }
        }
    }

    /// Check if accessibility permission is granted
    func checkAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Request accessibility permission (shows system dialog)
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Private Methods

    private func simulatePaste() {
        writeLog("🔧 simulatePaste: Creating CGEventSource...")

        // Use CGEvent API directly (AppleScript doesn't work from CLI apps)
        let source = CGEventSource(stateID: .hidSystemState)
        writeLog("✓ CGEventSource created")

        // Small delay to ensure clipboard is ready
        usleep(10000) // 10ms
        writeLog("⏱️ Waited 10ms before creating key events")

        // Create key down event for 'V'
        guard let keyDown = CGEvent(keyboardEventSource: source,
                                    virtualKey: CGKeyCode(kVK_ANSI_V),
                                    keyDown: true) else {
            NSLog("❌ Failed to create keyDown event")
            writeLog("❌ Failed to create keyDown event")
            return
        }
        writeLog("✓ keyDown event created")

        // Add Command modifier
        keyDown.flags = .maskCommand
        writeLog("✓ Command modifier added to keyDown")

        // Create key up event for 'V'
        guard let keyUp = CGEvent(keyboardEventSource: source,
                                  virtualKey: CGKeyCode(kVK_ANSI_V),
                                  keyDown: false) else {
            NSLog("❌ Failed to create keyUp event")
            writeLog("❌ Failed to create keyUp event")
            return
        }
        writeLog("✓ keyUp event created")

        keyUp.flags = .maskCommand
        writeLog("✓ Command modifier added to keyUp")

        // Get frontmost app for debugging
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            writeLog("🎯 Frontmost app: \(frontApp.localizedName ?? "unknown") (\(frontApp.bundleIdentifier ?? "no bundle ID"))")
        } else {
            writeLog("⚠️ Could not determine frontmost app")
        }

        // Post events with small delay between them
        writeLog("📤 Posting keyDown event...")
        keyDown.post(tap: .cghidEventTap)
        writeLog("✓ keyDown posted")

        usleep(5000) // 5ms between key down and up
        writeLog("⏱️ Waited 5ms between keyDown and keyUp")

        writeLog("📤 Posting keyUp event...")
        keyUp.post(tap: .cghidEventTap)
        writeLog("✓ keyUp posted")

        NSLog("✅ CGEvent paste posted")
        writeLog("✅ CGEvent paste posted successfully")
    }
}

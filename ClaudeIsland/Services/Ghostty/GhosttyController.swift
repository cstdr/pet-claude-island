//
//  GhosttyController.swift
//  ClaudeIsland
//
//  Controls Ghostty terminal via AppleScript
//

import Foundation
import os.log

/// Controller for Ghostty terminal operations via AppleScript
actor GhosttyController {
    static let shared = GhosttyController()

    /// Logger
    nonisolated static let logger = Logger(subsystem: "com.claudeisland", category: "Ghostty")

    private init() {}

    // MARK: - Public API

    /// Focus the frontmost Ghostty window (where Claude is likely running)
    func focusWindow(forClaudePid claudePid: Int) async -> Bool {
        // Use activate to bring Ghostty to front (safer than set frontmost)
        let script = """
        tell application "Ghostty"
            if (count of windows) > 0 then
                activate
                return "OK"
            end if
            return "NO_WINDOW"
        end tell
        """

        do {
            let output = try await runAppleScript(script)
            return output.contains("OK")
        } catch {
            Self.logger.error("Failed to focus Ghostty: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Send text input to a specific Ghostty terminal based on working directory
    func sendText(_ text: String, to claudePid: Int) async -> Bool {
        // Get working directory for this PID
        guard let cwd = ProcessTreeBuilder.shared.getWorkingDirectory(forPid: claudePid) else {
            print("DEBUG Ghostty: Could not get working directory for pid \(claudePid)")
            return false
        }
        print("DEBUG Ghostty: PID \(claudePid) cwd = \(cwd)")

        // Escape special characters in the text for AppleScript
        let escapedText = text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        print("DEBUG Ghostty: Sending text: \(text)")

        // Find the terminal with matching working directory, activate, then send text and enter
        let script = """
        tell application "Ghostty"
            set targetTerminal to null
            repeat with w in windows
                repeat with t in terminals of w
                    if (working directory of t) = "\(cwd)" then
                        set targetTerminal to t
                        exit repeat
                    end if
                end repeat
                if targetTerminal is not null then exit repeat
            end repeat

            if targetTerminal is null then return "NO_TERMINAL"
            activate
            delay 0.2
            input text "\(escapedText)" to targetTerminal
            delay 0.15
            send key "enter" to targetTerminal
            return "SENT"
        end tell
        """

        do {
            let output = try await runAppleScript(script)
            print("DEBUG Ghostty: AppleScript output: \(output)")
            if output.contains("NO_TERMINAL") {
                Self.logger.debug("No Ghostty terminal found with cwd: \(cwd, privacy: .public)")
                return false
            }
            return output.contains("SENT")
        } catch {
            Self.logger.error("Failed to send text to Ghostty: \(error.localizedDescription, privacy: .public)")
            print("DEBUG Ghostty: Error: \(error)")
            return false
        }
    }

    /// Send a key press to the frontmost Ghostty terminal
    func sendKey(_ key: String, modifiers: [String] = [], to claudePid: Int) async -> Bool {
        let modStr = modifiers.isEmpty ? "" : " with modifiers {\(modifiers.joined(separator: ","))}"

        let script = """
        tell application "Ghostty"
            if (count of windows) = 0 then return "NO_WINDOW"

            set frontmost of front window to true
            delay 0.1

            send key "\(key)"\(modStr) to front terminal
        end tell
        """

        do {
            let output = try await runAppleScript(script)
            return !output.contains("NO_WINDOW")
        } catch {
            Self.logger.error("Failed to send key to Ghostty: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    // MARK: - Private Methods

    /// Escape string for use in AppleScript
    private func escapeForAppleScript(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    /// Run an AppleScript command and return output
    private func runAppleScript(_ script: String) async throws -> String {
        let result = try await ProcessExecutor.shared.run(
            "/usr/bin/osascript",
            arguments: ["-e", script]
        )
        return result
    }
}

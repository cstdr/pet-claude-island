//
//  CustomSoundRow.swift
//  ClaudeIsland
//
//  Custom notification sound recorder row with waveform visualization
//

import SwiftUI
import AVFoundation

struct CustomSoundRow: View {
    let type: NotificationType
    @ObservedObject var soundManager: CustomSoundManager
    @State private var isHovered: Bool = false
    @State private var isRecordingHovered: Bool = false
    @State private var hasPermission: Bool = false
    @State private var soundSource: SoundSource = .system
    @State private var selectedSystemSound: NotificationSound = .pop
    /// Prevents tap gesture from firing when buttons inside expanded panel are clicked
    @State private var isButtonPressed: Bool = false

    private var isExpanded: Bool {
        soundManager.expandedType == type
    }

    private var isCurrentlyRecording: Bool {
        soundManager.isRecording == type
    }

    private var isOtherRecording: Bool {
        soundManager.isRecording != nil && soundManager.isRecording != type
    }

    private var isCurrentlyPlaying: Bool {
        soundManager.isPlaying == type
    }

    var body: some View {
        VStack(spacing: 0) {
            // Row header
            rowHeader

            // Expanded recording panel
            if isExpanded {
                recordingPanel
            }
        }
        .onAppear {
            checkPermission()
            loadSettings()
        }
    }

    // MARK: - Row Header

    private var rowHeader: some View {
        HStack(spacing: 0) {
            // Label (clickable to expand/collapse when has custom sound)
            Text(type.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(textColor)

            Spacer()

            // Sound selector dropdown
            soundSelector

            // Recording button
            recordButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            // Only toggle if no button was recently pressed (prevents event bubbling)
            if self.hasCustomSound && !self.isButtonPressed {
                self.toggleExpanded()
            }
        }
        .onHover { isHovered = $0 }
    }

    private var soundSelector: some View {
        Menu {
            // System sounds section
            Section("System Sounds".localized) {
                ForEach(NotificationSound.allCases, id: \.self) { sound in
                    Button {
                        selectedSystemSound = sound
                        soundSource = .system
                        saveSettings()
                        // Play preview of selected system sound
                        if let soundName = sound.soundName {
                            NSSound(named: soundName)?.play()
                        }
                    } label: {
                        HStack {
                            Text(sound.rawValue)
                            Spacer()
                            if soundSource == .system && selectedSystemSound == sound {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            // Custom sound section
            if soundManager.hasCustomSound(for: type) {
                Section("Custom".localized) {
                    Button {
                        soundSource = .custom
                        saveSettings()
                        // Delay playback slightly to allow menu to close first
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self.soundManager.playSound(for: self.type)
                        }
                    } label: {
                        HStack {
                            Text(LanguageManager.shared.localized("Custom Sound"))
                            Spacer()
                            if soundSource == .custom {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedSoundLabel)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .frame(width: 90)
    }

    private var selectedSoundLabel: String {
        if soundSource == .custom {
            return "Custom".localized
        }
        return selectedSystemSound.rawValue
    }

    private var hasCustomSound: Bool {
        soundManager.hasCustomSound(for: type)
    }

    private var recordButton: some View {
        Button {
            handleRecordTap()
        } label: {
            ZStack {
                Circle()
                    .strokeBorder(
                        isOtherRecording ? Color.white.opacity(0.2) :
                        isCurrentlyRecording ? Color(red: 1.0, green: 0.3, blue: 0.3) :
                        isRecordingHovered ? Color(red: 0.4, green: 0.6, blue: 1.0) :
                        Color.white.opacity(0.3),
                        lineWidth: 1.5
                    )
                    .frame(width: 28, height: 28)

                if isCurrentlyRecording {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(red: 1.0, green: 0.3, blue: 0.3))
                        .frame(width: 10, height: 10)
                } else {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 11))
                        .foregroundColor(isOtherRecording ? Color.white.opacity(0.3) : Color(red: 0.4, green: 0.6, blue: 1.0))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(isOtherRecording)
        .onHover { isRecordingHovered = $0 }
    }

    // MARK: - Recording Panel

    private var recordingPanel: some View {
        VStack(spacing: 12) {
            // Waveform and timer
            HStack(spacing: 10) {
                // Recording/Playing indicator
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 8, height: 8)
                    .opacity(isCurrentlyRecording ? 1 : 0.7)

                // Waveform (centered)
                WaveformView(
                    levels: isCurrentlyPlaying ? soundManager.playbackLevels : (isCurrentlyRecording ? soundManager.audioLevels : []),
                    isAnimating: isCurrentlyRecording || isCurrentlyPlaying
                )
                .frame(height: 24)


                // Timer
                Text(formatDuration(soundManager.recordingDuration))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(timerColor)
                    .frame(width: 38, alignment: .trailing)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            // Action buttons
            HStack(spacing: 8) {
                // Preview button
                Button {
                    markButtonPressed()
                    if isCurrentlyPlaying {
                        soundManager.stopPlayback()
                    } else {
                        soundManager.playSound(for: type)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCurrentlyPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 10))
                        Text(isCurrentlyPlaying ? LanguageManager.shared.localized("Stop") : LanguageManager.shared.localized("Preview"))
                            .font(.system(size: 11, weight: .medium))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, 7)
                    .foregroundColor(TerminalColors.green)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(TerminalColors.green.opacity(0.4), lineWidth: 1)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(soundManager.isRecording != nil || !soundManager.hasCustomSound(for: type))

                // Delete button
                Button {
                    markButtonPressed()
                    soundManager.deleteSound(for: type)
                    soundSource = .system
                    saveSettings()
                    soundManager.expandedType = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle()) // Make entire button area clickable
                .disabled(soundManager.isRecording != nil || !soundManager.hasCustomSound(for: type))
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.03))
        )
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private var indicatorColor: Color {
        if isCurrentlyRecording {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        } else if isCurrentlyPlaying {
            return TerminalColors.green
        }
        return TerminalColors.green
    }

    private var timerColor: Color {
        if isCurrentlyRecording {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
        return .white.opacity(0.5)
    }

    private var iconName: String {
        switch type {
        case .processing: return "waveform"
        case .waiting: return "clock"
        case .permission: return "lock.shield"
        }
    }

    private var iconColor: Color {
        isHovered ? .white : .white.opacity(0.7)
    }

    private var textColor: Color {
        isHovered ? .white : .white.opacity(0.7)
    }

    private func toggleExpanded() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if soundManager.expandedType == type {
                soundManager.expandedType = nil
            } else {
                soundManager.expandedType = type
            }
        }
    }

    /// Marks a button as pressed to prevent tap gesture event bubbling
    private func markButtonPressed() {
        isButtonPressed = true
        // Reset after a short delay to allow normal tapping to resume
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.isButtonPressed = false
        }
    }

    private func handleRecordTap() {
        if isCurrentlyRecording {
            soundManager.stopRecording()
        } else if !isOtherRecording {
            soundManager.requestRecordPermission { [self] granted in
                if granted {
                    soundManager.expandedType = type
                    soundManager.startRecording(for: type)
                } else {
                    openMicrophoneSettings()
                }
            }
        }
    }

    private func checkPermission() {
        hasPermission = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let seconds = Int(duration)
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func loadSettings() {
        let settings = AppSettings.soundSettings(for: type)
        soundSource = settings.source
        selectedSystemSound = settings.systemSound
    }

    private func saveSettings() {
        var settings = AppSettings.soundSettings(for: type)
        settings.source = soundSource
        settings.systemSound = selectedSystemSound
    }
}

// MARK: - Waveform View

struct WaveformView: View {
    let levels: [Float]
    var isAnimating: Bool = false

    private let barCount = 24
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barColor(for: index))
                        .frame(height: barHeight(at: index), alignment: .center)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }

    private func barColor(for index: Int) -> Color {
        if isAnimating && levels.indices.contains(index) {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        } else if levels.indices.contains(index) {
            return Color.white.opacity(0.5)
        }
        return Color.white.opacity(0.15)
    }

    private func barHeight(at index: Int) -> CGFloat {
        if isAnimating && levels.indices.contains(index) {
            let level = CGFloat(levels[index])
            return minHeight + (maxHeight - minHeight) * level
        } else if levels.indices.contains(index) && levels.count > 0 {
            let level = CGFloat(levels[index])
            return minHeight + (maxHeight - minHeight) * level
        }
        return minHeight
    }
}

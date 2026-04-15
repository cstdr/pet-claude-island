//
//  CustomSoundManager.swift
//  ClaudeIsland
//
//  Manages custom notification sound recording and playback
//

import AVFoundation
import AppKit
import Combine
import Foundation

enum NotificationType: String, CaseIterable {
    case processing = "processing"
    case waiting = "waiting"
    case permission = "permission"

    var displayName: String {
        switch self {
        case .processing: return "Processing"
        case .waiting: return "Waiting"
        case .permission: return "Permission"
        }
    }

    var fileName: String {
        return "\(rawValue).m4a"
    }
}

@MainActor
class CustomSoundManager: NSObject, ObservableObject {
    static let shared = CustomSoundManager()

    // MARK: - Published State

    @Published var isRecording: NotificationType? = nil
    @Published var recordingDuration: TimeInterval = 0
    @Published var audioLevels: [Float] = []
    @Published var hasCustomSound: [NotificationType: Bool] = [:]
    @Published var expandedType: NotificationType? = nil
    @Published var isPlaying: NotificationType? = nil
    @Published var playbackLevels: [Float] = []

    // MARK: - Private Properties

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var meteringTimer: Timer?
    private var recordingStartTime: Date?
    private let maxRecordingDuration: TimeInterval = 5.0

    private var soundsDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let soundsDir = appSupport.appendingPathComponent("ClaudeIsland/CustomSounds", isDirectory: true)

        if !FileManager.default.fileExists(atPath: soundsDir.path) {
            try? FileManager.default.createDirectory(at: soundsDir, withIntermediateDirectories: true)
        }

        return soundsDir
    }

    // MARK: - Initialization

    private override init() {
        super.init()
        refreshCustomSoundState()
        setupInterruptionObserver()
    }

    // MARK: - Public API

    func hasCustomSound(for type: NotificationType) -> Bool {
        hasCustomSound[type] ?? false
    }

    func customSoundURL(for type: NotificationType) -> URL? {
        guard hasCustomSound(for: type) else { return nil }
        let url = soundsDirectory.appendingPathComponent(type.fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func refreshCustomSoundState() {
        for type in NotificationType.allCases {
            let url = soundsDirectory.appendingPathComponent(type.fileName)
            hasCustomSound[type] = FileManager.default.fileExists(atPath: url.path)
        }
    }

    // MARK: - Recording

    func requestRecordPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    func startRecording(for type: NotificationType) {
        print("DEBUG startRecording: BEGIN, type=\(type)")
        // Stop any existing recording
        if isRecording != nil {
            print("DEBUG startRecording: stopping existing recording")
            stopRecording()
        }

        // Stop any playing sound
        audioPlayer?.stop()

        let url = soundsDirectory.appendingPathComponent(type.fileName)
        print("DEBUG startRecording: url=\(url)")

        // Remove existing file if present
        try? FileManager.default.removeItem(at: url)

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            print("DEBUG startRecording: creating AVAudioRecorder")
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.delegate = self

            print("DEBUG startRecording: calling record()")
            if audioRecorder?.record() == true {
                print("DEBUG startRecording: SUCCESS, recording started")
                isRecording = type
                recordingDuration = 0
                audioLevels = []
                recordingStartTime = Date()
                startMeteringTimer()
            } else {
                print("DEBUG startRecording: record() returned false")
            }
        } catch {
            print("DEBUG startRecording: FAILED - \(error)")
        }
        print("DEBUG startRecording: END")
    }

    func stopRecording() {
        guard isRecording != nil else { return }

        meteringTimer?.invalidate()
        meteringTimer = nil
        audioRecorder?.stop()
        isRecording = nil
        recordingDuration = 0
        audioLevels = []

        // Refresh state to confirm file exists
        refreshCustomSoundState()
    }

    // MARK: - Playback

    /// Play the notification sound for a given type, respecting user settings
    func playNotificationSound(for type: NotificationType) {
        let settings = AppSettings.soundSettings(for: type)

        if settings.source == .custom, let url = customSoundURL(for: type) {
            playCustomSound(from: url, as: type)
        } else {
            playSystemSound(settings.systemSound)
        }
    }

    /// Play a custom recording for preview (with animation)
    func playSound(for type: NotificationType) {
        guard let url = customSoundURL(for: type) else { return }
        playCustomSound(from: url, as: type)
    }

    private func playCustomSound(from url: URL, as type: NotificationType) {
        // Stop any existing playback
        audioPlayer?.stop()
        isPlaying = nil
        playbackLevels = []
        playbackTimer?.invalidate()
        playbackTimer = nil

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            isPlaying = type
            audioPlayer?.play()
            startPlaybackAnimation()

            // Safety timeout: reset isPlaying after sound duration + 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                if self?.isPlaying == type {
                    self?.isPlaying = nil
                    self?.playbackLevels = []
                }
            }
        } catch {
            print("Failed to play custom sound: \(error)")
            isPlaying = nil
        }
    }

    private func playSystemSound(_ sound: NotificationSound) {
        if let soundName = sound.soundName {
            NSSound(named: soundName)?.play()
        }
    }

    func stopPlayback() {
        audioPlayer?.stop()
        isPlaying = nil
        playbackLevels = []
    }

    // MARK: - Delete

    func deleteSound(for type: NotificationType) {
        let url = soundsDirectory.appendingPathComponent(type.fileName)
        try? FileManager.default.removeItem(at: url)
        hasCustomSound[type] = false
    }

    // MARK: - Private Methods

    private var playbackTimer: Timer?

    private func startPlaybackAnimation() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackAnimation()
            }
        }
    }

    private func updatePlaybackAnimation() {
        guard isPlaying != nil else {
            playbackTimer?.invalidate()
            playbackTimer = nil
            return
        }

        // Generate fake waveform data for playback visualization
        // Use sine wave variations for smooth animation
        let time = Date().timeIntervalSince1970
        var newLevels: [Float] = []
        for i in 0..<24 {
            let phase = Double(i) * 0.3 + time * 5.0
            let value = Float((sin(phase) + 1.0) / 2.0 * 0.6 + 0.2) // 0.2 to 0.8 range
            newLevels.append(value)
        }
        playbackLevels = newLevels
    }

    private func startMeteringTimer() {
        meteringTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateMetering()
            }
        }
    }

    private func updateMetering() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }

        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0)

        // Normalize from -160dB...0dB to 0.0...1.0
        // Typical voice is around -30dB to -10dB, map that to 0.3...1.0 range for good visuals
        let normalizedPower: Float
        if power < -50 {
            normalizedPower = 0
        } else if power > -10 {
            normalizedPower = 1
        } else {
            normalizedPower = (power + 50) / 40
        }
        audioLevels.append(normalizedPower)

        // Update duration
        if let startTime = recordingStartTime {
            recordingDuration = Date().timeIntervalSince(startTime)
        }

        // Auto-stop at max duration
        if recordingDuration >= maxRecordingDuration {
            stopRecording()
        }
    }

    private func setupInterruptionObserver() {
        // macOS uses different interruption notification
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )
    }

    @objc private func handleInterruption(notification: Notification) {
        Task { @MainActor in
            // Stop recording when app loses focus
            if isRecording != nil {
                stopRecording()
            }
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension CustomSoundManager: AVAudioRecorderDelegate {
    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        Task { @MainActor in
            if !flag {
                print("Recording did not finish successfully")
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            if let error = error {
                print("Recording encode error: \(error)")
            }
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension CustomSoundManager: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = nil
        }
    }
}

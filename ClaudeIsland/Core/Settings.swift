//
//  Settings.swift
//  ClaudeIsland
//
//  App settings manager using UserDefaults
//

import Foundation

/// Available notification sounds
enum NotificationSound: String, CaseIterable {
    case none = "None"
    case pop = "Pop"
    case ping = "Ping"
    case tink = "Tink"
    case glass = "Glass"
    case blow = "Blow"
    case bottle = "Bottle"
    case frog = "Frog"
    case funk = "Funk"
    case hero = "Hero"
    case morse = "Morse"
    case purr = "Purr"
    case sosumi = "Sosumi"
    case submarine = "Submarine"
    case basso = "Basso"

    /// The system sound name to use with NSSound, or nil for no sound
    var soundName: String? {
        self == .none ? nil : rawValue
    }
}

/// Whether to use system sound or custom recording for a notification type
enum SoundSource: String {
    case system = "system"
    case custom = "custom"
}

/// Settings for a specific notification type's sound
struct NotificationTypeSoundSettings {
    let type: NotificationType

    private var sourceKey: String { "\(type.rawValue)SoundSource" }
    private var systemSoundKey: String { "\(type.rawValue)SystemSound" }

    var source: SoundSource {
        get {
            guard let raw = UserDefaults.standard.string(forKey: sourceKey),
                  let source = SoundSource(rawValue: raw) else {
                return .system
            }
            return source
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: sourceKey)
        }
    }

    var systemSound: NotificationSound {
        get {
            guard let raw = UserDefaults.standard.string(forKey: systemSoundKey),
                  let sound = NotificationSound(rawValue: raw) else {
                return .pop
            }
            return sound
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: systemSoundKey)
        }
    }
}

enum AppSettings {
    private static let defaults = UserDefaults.standard

    // MARK: - Keys

    private enum Keys {
        static let notificationSound = "notificationSound"
        static let waitingDisplayDuration = "waitingDisplayDuration"
        static let keepNotchVisible = "keepNotchVisible"
        static let language = "language"
    }

    // MARK: - Notification Sound

    /// The sound to play when Claude finishes and is ready for input
    static var notificationSound: NotificationSound {
        get {
            guard let rawValue = defaults.string(forKey: Keys.notificationSound),
                  let sound = NotificationSound(rawValue: rawValue) else {
                return .pop // Default to Pop
            }
            return sound
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.notificationSound)
        }
    }

    /// Settings for each notification type's sound
    static func soundSettings(for type: NotificationType) -> NotificationTypeSoundSettings {
        return NotificationTypeSoundSettings(type: type)
    }

    // MARK: - Display Duration

    /// How long to show the waiting-for-input indicator (in seconds)
    static var waitingDisplayDuration: Int {
        get {
            let value = defaults.integer(forKey: Keys.waitingDisplayDuration)
            return value > 0 ? value : 30 // Default 30 seconds
        }
        set {
            defaults.set(newValue, forKey: Keys.waitingDisplayDuration)
        }
    }

    // MARK: - Keep Notch Visible

    /// Whether to keep the notch visible when sessions exist (even if idle)
    static var keepNotchVisible: Bool {
        get {
            defaults.bool(forKey: Keys.keepNotchVisible)
        }
        set {
            defaults.set(newValue, forKey: Keys.keepNotchVisible)
        }
    }

    // MARK: - Language

    /// App language preference (nil = system default)
    static var language: String? {
        get {
            defaults.string(forKey: Keys.language)
        }
        set {
            defaults.set(newValue, forKey: Keys.language)
        }
    }
}

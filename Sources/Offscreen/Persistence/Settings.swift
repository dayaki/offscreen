import Foundation

/// Timing for the recurring work → break cycle. All values are "virtual"
/// seconds — the engine scales real elapsed time by OFFSCREEN_TIME_SCALE.
struct TimingConfig: Codable, Equatable, Sendable {
    var workSeconds: Int = 20 * 60
    var shortBreakSeconds: Int = 20
    var longBreakEvery: Int = 3 // every Nth break is a long one; 0 = never
    var longBreakSeconds: Int = 5 * 60
    var leadTimeSeconds: Int = 60 // heads-up notice before a break
    var snoozeLimitPerCycle: Int = 3

    static let balanced = TimingConfig()
    static let deepFocus = TimingConfig(
        workSeconds: 45 * 60,
        shortBreakSeconds: 30,
        longBreakEvery: 2,
        longBreakSeconds: 8 * 60
    )
    static let twentyTwentyTwenty = TimingConfig(
        workSeconds: 20 * 60,
        shortBreakSeconds: 20,
        longBreakEvery: 0
    )

    static let presets: [(name: String, config: TimingConfig)] = [
        ("Balanced", .balanced),
        ("Deep Focus", .deepFocus),
        ("20-20-20", .twentyTwentyTwenty),
    ]

    var presetName: String {
        Self.presets.first { $0.config == self }?.name ?? "Custom"
    }
}

/// Break-experience behavior separate from timing.
struct BehaviorConfig: Codable, Equatable, Sendable {
    var difficulty: DifficultyMode = .balanced
    var skipEnableDelaySeconds: Int = 5 // Balanced mode: skip unlocks after this
    var endEarlyMinimumSeconds: Int? // nil = no "End Break" button
    var cursorPillSeconds: Int = 10 // countdown pill in the last N seconds
    var autoLockOnBreakStart: Bool = false
}

/// How hard it is to get out of a break.
enum DifficultyMode: String, Codable, CaseIterable, Sendable {
    case casual // skip any time
    case balanced // skip button enables after a delay
    case hardcore // no skipping

    var label: String {
        switch self {
        case .casual: "Casual"
        case .balanced: "Balanced"
        case .hardcore: "Hardcore"
        }
    }
}

/// Which Smart Pause signals defer breaks.
struct SmartPauseConfig: Codable, Equatable, Sendable {
    var pauseOnCamera: Bool = true
    var pauseOnMic: Bool = true
    var pauseOnMedia: Bool = true
    var pauseOnScreenShare: Bool = true
    var pauseOnFullscreen: Bool = true
    /// Keep taking breaks while a music player (Spotify, Apple Music, …) is the
    /// only thing making sound. Meetings still pause via the microphone.
    var ignoreMusicPlayers: Bool = true
    var focusAppBundleIDs: [String] = []
    var idlePauseSeconds: Int = 120 // stop counting work after this much idle
    var deferWhileTypingSeconds: Int = 2 // due break waits for a typing lull
    var maxTypingDeferSeconds: Int = 60

    init() {}

    // Field-lenient decode so adding a field never resets sibling fields.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SmartPauseConfig()
        pauseOnCamera = (try? c.decodeIfPresent(Bool.self, forKey: .pauseOnCamera)) ?? d.pauseOnCamera
        pauseOnMic = (try? c.decodeIfPresent(Bool.self, forKey: .pauseOnMic)) ?? d.pauseOnMic
        pauseOnMedia = (try? c.decodeIfPresent(Bool.self, forKey: .pauseOnMedia)) ?? d.pauseOnMedia
        pauseOnScreenShare = (try? c.decodeIfPresent(Bool.self, forKey: .pauseOnScreenShare)) ?? d.pauseOnScreenShare
        pauseOnFullscreen = (try? c.decodeIfPresent(Bool.self, forKey: .pauseOnFullscreen)) ?? d.pauseOnFullscreen
        ignoreMusicPlayers = (try? c.decodeIfPresent(Bool.self, forKey: .ignoreMusicPlayers)) ?? d.ignoreMusicPlayers
        focusAppBundleIDs = (try? c.decodeIfPresent([String].self, forKey: .focusAppBundleIDs)) ?? d.focusAppBundleIDs
        idlePauseSeconds = (try? c.decodeIfPresent(Int.self, forKey: .idlePauseSeconds)) ?? d.idlePauseSeconds
        deferWhileTypingSeconds = (try? c.decodeIfPresent(Int.self, forKey: .deferWhileTypingSeconds)) ?? d.deferWhileTypingSeconds
        maxTypingDeferSeconds = (try? c.decodeIfPresent(Int.self, forKey: .maxTypingDeferSeconds)) ?? d.maxTypingDeferSeconds
    }
}

/// Only remind within these hours (wall clock).
struct OfficeHoursConfig: Codable, Equatable, Sendable {
    var enabled: Bool = false
    var startMinute: Int = 9 * 60 // minutes from midnight
    var endMinute: Int = 18 * 60
    var weekdays: Set<Int> = [2, 3, 4, 5, 6] // Calendar weekday: 1 = Sunday
}

/// A named break at a fixed clock time (lunch, walk, …).
struct PlannedBreak: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var name: String = "Lunch"
    var hour: Int = 12
    var minute: Int = 30
    var durationSeconds: Int = 30 * 60
    var enabled: Bool = true
    var weekdays: Set<Int> = [2, 3, 4, 5, 6]
}

enum OverlayStyleKind: String, Codable, CaseIterable, Sendable {
    case gradient, blur, image

    var label: String {
        switch self {
        case .gradient: "Aurora"
        case .blur: "Blur"
        case .image: "Custom Image"
        }
    }
}

struct OverlayStyle: Codable, Equatable, Sendable {
    var kind: OverlayStyleKind = .gradient
    var imagePath: String?
}

struct SoundConfig: Codable, Equatable, Sendable {
    /// Whether an ambient track plays for the duration of each break.
    var enabled: Bool = true
    /// The chosen ambient track: a SoundCatalog identifier
    /// ("none", "bundled:rain.m4a", "custom:file.mp3"). It loops until the
    /// break ends.
    var ambient: String = "bundled:rain.m4a"
    var volume: Double = 0.6

    init() {}

    // Field-lenient decode. Also migrates the pre-ambient-catalog schema: if
    // there's no `ambient` key, this is an older settings.json, so adopt the
    // new defaults (ambient on) and carry over any legacy custom track path.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = SoundConfig()
        volume = (try? c.decodeIfPresent(Double.self, forKey: .volume)) ?? d.volume

        if let ambientID = try? c.decodeIfPresent(String.self, forKey: .ambient) {
            ambient = ambientID
            enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? d.enabled
        } else if let legacyPath = try? c.decodeIfPresent(String.self, forKey: .customPath),
                  !legacyPath.isEmpty {
            ambient = legacyPath // absolute path; SoundCatalog.url tolerates it
            enabled = true
        } else {
            ambient = d.ambient
            enabled = d.enabled
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(enabled, forKey: .enabled)
        try c.encode(ambient, forKey: .ambient)
        try c.encode(volume, forKey: .volume)
    }

    private enum CodingKeys: String, CodingKey {
        case enabled, ambient, volume, customPath
    }
}

/// The whole persisted settings tree. Decoding is field-lenient: any missing
/// key falls back to its default, so adding fields never nukes the file.
struct AppSettings: Codable, Equatable, Sendable {
    var timing: TimingConfig = .balanced
    var behavior: BehaviorConfig = BehaviorConfig()
    var smartPause: SmartPauseConfig = SmartPauseConfig()
    var officeHours: OfficeHoursConfig = OfficeHoursConfig()
    var plannedBreaks: [PlannedBreak] = []
    var overlayStyle: OverlayStyle = OverlayStyle()
    var sound: SoundConfig = SoundConfig()
    var customShortMessages: [String] = []
    var customLongMessages: [String] = []
    var showCountdownInMenuBar: Bool = true
    var statsEnabled: Bool = true

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AppSettings()
        timing = (try? c.decodeIfPresent(TimingConfig.self, forKey: .timing)) ?? d.timing
        behavior = (try? c.decodeIfPresent(BehaviorConfig.self, forKey: .behavior)) ?? d.behavior
        smartPause = (try? c.decodeIfPresent(SmartPauseConfig.self, forKey: .smartPause)) ?? d.smartPause
        officeHours = (try? c.decodeIfPresent(OfficeHoursConfig.self, forKey: .officeHours)) ?? d.officeHours
        plannedBreaks = (try? c.decodeIfPresent([PlannedBreak].self, forKey: .plannedBreaks)) ?? d.plannedBreaks
        overlayStyle = (try? c.decodeIfPresent(OverlayStyle.self, forKey: .overlayStyle)) ?? d.overlayStyle
        sound = (try? c.decodeIfPresent(SoundConfig.self, forKey: .sound)) ?? d.sound
        customShortMessages = (try? c.decodeIfPresent([String].self, forKey: .customShortMessages)) ?? d.customShortMessages
        customLongMessages = (try? c.decodeIfPresent([String].self, forKey: .customLongMessages)) ?? d.customLongMessages
        showCountdownInMenuBar = (try? c.decodeIfPresent(Bool.self, forKey: .showCountdownInMenuBar)) ?? d.showCountdownInMenuBar
        statsEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .statsEnabled)) ?? d.statsEnabled
    }
}

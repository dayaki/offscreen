import Foundation

/// Aggregates raw monitor signals into engine hold reasons, gated by the
/// user's Smart Pause settings, and owns the idle/sleep-gap rules.
final class SmartPauseController {
    private let engine: BreakEngine
    private var config: SmartPauseConfig

    private var camera: CameraMonitor?
    private var audio: ProcessAudioMonitor?
    private var fullscreen: FullscreenAppMonitor?
    private var screenShare: ScreenShareMonitor?
    private var focusApps: FocusAppMonitor?
    private var idle: IdleMonitor?
    private var sleepWake: SleepWakeMonitor?
    private var inputBurst: InputBurstDetector?

    /// Latest raw signal per reason, before config gating — kept so toggling
    /// a setting re-applies immediately.
    private var raw: [HoldReason: Bool] = [:]
    private var lastIdleSeconds: Double = 0
    private var suspendedBySleep = false
    /// Latest raw audio reading, re-applied when the music setting changes.
    private var lastAudio = ProcessAudioMonitor.State()

    init(engine: BreakEngine, config: SmartPauseConfig) {
        self.engine = engine
        self.config = config

        camera = CameraMonitor { [weak self] on in self?.set(.camera, on) }
        audio = ProcessAudioMonitor { [weak self] state in self?.applyAudio(state) }
        fullscreen = FullscreenAppMonitor { [weak self] on in self?.set(.fullscreenApp, on) }
        screenShare = ScreenShareMonitor { [weak self] on in self?.set(.screenShared, on) }
        focusApps = FocusAppMonitor(bundleIDs: Set(config.focusAppBundleIDs)) { [weak self] on in
            self?.set(.focusApp, on)
        }
        idle = IdleMonitor { [weak self] seconds in self?.idleTick(seconds) }
        sleepWake = SleepWakeMonitor(
            onSuspend: { [weak self] in
                guard let self else { return }
                self.suspendedBySleep = true
                self.engine.enterIdlePause()
            },
            onResume: { [weak self] gap in
                guard let self, self.suspendedBySleep else { return }
                self.suspendedBySleep = false
                self.engine.exitIdlePause(afterRealSecondsAway: gap)
            }
        )
        inputBurst = InputBurstDetector(engine: engine) { [weak self] in
            self?.config ?? SmartPauseConfig()
        }
    }

    func configChanged(_ newConfig: SmartPauseConfig) {
        config = newConfig
        focusApps?.bundleIDs = Set(newConfig.focusAppBundleIDs)
        for (reason, value) in raw {
            engine.setHold(reason, active: value && enabled(reason))
        }
        applyAudio(lastAudio) // re-evaluate mic/media with the new music setting
    }

    /// Maps an audio reading to holds. A meeting is the microphone; music
    /// players are exempt from the media hold unless the user opts back in, so
    /// background music doesn't defer breaks while working.
    private func applyAudio(_ state: ProcessAudioMonitor.State) {
        lastAudio = state
        set(.microphone, state.micInUse)
        set(.mediaPlayback, Self.shouldHoldForMedia(state, config: config))
    }

    /// Pure audio→media-hold decision (unit-tested). A dedicated music player
    /// alone never holds when `ignoreMusicPlayers` is set; the mic (meetings)
    /// is handled separately.
    static func shouldHoldForMedia(_ state: ProcessAudioMonitor.State, config: SmartPauseConfig) -> Bool {
        state.mediaPlaying || (state.musicPlaying && !config.ignoreMusicPlayers)
    }

    private func set(_ reason: HoldReason, _ active: Bool) {
        raw[reason] = active
        engine.setHold(reason, active: active && enabled(reason))
    }

    private func enabled(_ reason: HoldReason) -> Bool {
        switch reason {
        case .camera: config.pauseOnCamera
        case .microphone: config.pauseOnMic
        case .mediaPlayback: config.pauseOnMedia
        case .screenShared: config.pauseOnScreenShare
        case .fullscreenApp: config.pauseOnFullscreen
        case .focusApp: true // presence in the list is the opt-in
        case .typing, .snoozed: true
        }
    }

    // MARK: Idle handling (thresholds are REAL seconds — human behavior)

    private func idleTick(_ seconds: Double) {
        if suspendedBySleep { return } // sleep/lock owns the pause right now
        if engine.phase == .idlePaused {
            if seconds < 2 {
                engine.exitIdlePause(afterRealSecondsAway: lastIdleSeconds)
            }
        } else if seconds >= Double(config.idlePauseSeconds), config.idlePauseSeconds > 0 {
            engine.enterIdlePause()
        }
        lastIdleSeconds = seconds
    }
}

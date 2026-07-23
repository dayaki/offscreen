import AppKit
import AVFoundation

/// Plays the chosen sound when a break ends, to signal that it's over and call
/// the user back to their desk. It's silent during the break itself.
///
/// The track loops so an away-from-desk user still hears it whenever they get
/// back, and it stops on its own the moment the user touches the keyboard or
/// mouse (they've returned). A hard time cap prevents endless playback on an
/// unattended machine.
final class BreakEndSoundPlayer {
    private var config: SoundConfig
    private var player: AVAudioPlayer?
    private var watchdog: Timer?
    private var ticks = 0

    private static let tick = 0.5              // seconds between activity checks
    private static let graceTicks = 4          // ~2 s before activity can stop it
    private static let activeIdleThreshold = 1.0 // idle < this ⇒ user is back
    private static let maxTicks = Int(30 * 60 / 0.5) // 30-minute safety cap

    init(engine: BreakEngine, config: SoundConfig) {
        self.config = config
        engine.addListener { [weak self] event in
            switch event {
            case .breakEnded(_, let reason, _):
                // Only when the break actually ran its course. A manual skip
                // means the user is present; no need to call them back.
                if reason == .completed || reason == .endedEarly { self?.playAlert() }
            case .breakStarted:
                self?.stop() // a new break began; drop any lingering alert
            default:
                break
            }
        }
    }

    func configChanged(_ newConfig: SoundConfig) {
        config = newConfig
        if !config.enabled { stop() }
    }

    private func playAlert() {
        stop()
        guard config.enabled, let url = SoundCatalog.url(for: config.ambient) else { return }
        guard let player = try? AVAudioPlayer(contentsOf: url) else {
            Log.app.error("could not load break-end sound: \(self.config.ambient, privacy: .public)")
            return
        }
        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        player.play()
        player.setVolume(Float(config.volume), fadeDuration: 0.8)
        self.player = player
        ticks = 0
        watchdog = Poll.every(Self.tick) { [weak self] in self?.checkForReturn() }
        Log.app.info("break-end sound started: \(self.config.ambient, privacy: .public)")
    }

    /// Stops once the user is active again (returned to their desk), after a
    /// short grace so a brief cue always plays, or when the time cap is hit.
    private func checkForReturn() {
        ticks += 1
        let userIsBack = ticks >= Self.graceTicks
            && IdleMonitor.idleSeconds() < Self.activeIdleThreshold
        if userIsBack || ticks >= Self.maxTicks { stop() }
    }

    private func stop() {
        watchdog?.invalidate()
        watchdog = nil
        guard let player else { return }
        self.player = nil
        player.setVolume(0, fadeDuration: 0.5)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { player.stop() }
    }
}

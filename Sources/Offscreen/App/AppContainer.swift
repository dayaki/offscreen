import AppKit
import Carbon.HIToolbox

/// Composition root: constructs and wires every service. No singletons —
/// everything hangs off this object, which the AppDelegate keeps alive.
final class AppContainer {
    let clock: EngineClock
    let settingsStore: SettingsStore
    let engine: BreakEngine
    let overlay: OverlayWindowController
    let preBreakPanel: PreBreakPanelController
    let cursorPill: CursorPillController
    let login: LoginItemManager
    let settingsWindow: SettingsWindowController
    let statsStore: StatsStore
    let activityTracker: ActivityTracker
    let statsWindow: StatsWindowController
    let statusItem: StatusItemController
    let hotkeys: HotkeyCenter
    let debugCommands: DebugCommands
    let sounds: BreakEndSoundPlayer
    let screenLocker: ScreenLocker
    var smartPause: SmartPauseController?
    var officeHours: OfficeHoursScheduler?
    var plannedBreaks: PlannedBreakScheduler?

    /// OFFSCREEN_DEBUG_TIMING=1 pins a real-time but compressed cycle for
    /// hands-on testing (panel up 60 s, pill last 10 s, 15 s break),
    /// ignoring the persisted timing settings.
    private let debugTimingActive: Bool

    init() {
        clock = EngineClock()
        settingsStore = SettingsStore()

        debugTimingActive = ProcessInfo.processInfo.environment["OFFSCREEN_DEBUG_TIMING"] != nil
        let timing: TimingConfig = debugTimingActive
            ? TimingConfig(
                workSeconds: 90, shortBreakSeconds: 15, longBreakEvery: 3,
                longBreakSeconds: 30, leadTimeSeconds: 60, snoozeLimitPerCycle: 3
            )
            : settingsStore.settings.timing

        engine = BreakEngine(timing: timing, clock: clock)
        engine.behavior = settingsStore.settings.behavior

        overlay = OverlayWindowController(engine: engine)
        preBreakPanel = PreBreakPanelController(engine: engine)
        cursorPill = CursorPillController(engine: engine)
        login = LoginItemManager()
        settingsWindow = SettingsWindowController(store: settingsStore, login: login)
        statsStore = StatsStore()
        activityTracker = ActivityTracker(stats: statsStore, enabled: settingsStore.settings.statsEnabled)
        statsWindow = StatsWindowController(stats: statsStore)
        statusItem = StatusItemController(engine: engine, settingsStore: settingsStore)
        hotkeys = HotkeyCenter()
        debugCommands = DebugCommands(engine: engine)
        SoundCatalog.ensureCustomDirectory()
        sounds = BreakEndSoundPlayer(engine: engine, config: settingsStore.settings.sound)
        screenLocker = ScreenLocker(engine: engine) { [weak settingsStore] in
            settingsStore?.settings.behavior.autoLockOnBreakStart ?? false
        }

        engine.customShortMessages = settingsStore.settings.customShortMessages
        engine.customLongMessages = settingsStore.settings.customLongMessages
        overlay.styleProvider = { [weak self] in
            self?.settingsStore.settings.overlayStyle ?? OverlayStyle()
        }

        statusItem.openSettings = { [weak self] in self?.settingsWindow.show() }
        statusItem.openStats = { [weak self] in self?.statsWindow.show() }

        engine.addListener { [weak self] event in
            guard let self, self.settingsStore.settings.statsEnabled else { return }
            switch event {
            case .breakEnded(let kind, let reason, let elapsed):
                let action = switch reason {
                case .completed: "completed"
                case .skipped: "skipped"
                case .endedEarly: "endedEarly"
                case .autoIdle: "autoIdle"
                }
                self.statsStore.recordBreak(
                    kind: kind, action: action,
                    scheduledSecs: BreakScheduleMath.duration(of: kind, timing: self.engine.timing),
                    actualSecs: Int(elapsed)
                )
            case .snoozed(let seconds, _, _):
                self.statsStore.recordBreak(
                    kind: self.engine.nextBreakKind, action: "snoozed",
                    scheduledSecs: seconds, actualSecs: 0
                )
            default:
                break
            }
        }

        settingsStore.addListener { [weak self] settings in
            guard let self else { return }
            if !self.debugTimingActive { self.engine.timing = settings.timing }
            self.engine.behavior = settings.behavior
            self.smartPause?.configChanged(self.effectiveSmartPause(settings.smartPause))
            self.officeHours?.configChanged(settings.officeHours)
            self.plannedBreaks?.configChanged(settings.plannedBreaks)
            self.activityTracker.enabled = settings.statsEnabled
            self.sounds.configChanged(settings.sound)
            self.engine.customShortMessages = settings.customShortMessages
            self.engine.customLongMessages = settings.customLongMessages
        }

        registerHotkeys()
    }

    func start() {
        // Monitors start polling immediately, so create them at start(), not init.
        smartPause = SmartPauseController(
            engine: engine,
            config: effectiveSmartPause(settingsStore.settings.smartPause)
        )
        officeHours = OfficeHoursScheduler(engine: engine, config: settingsStore.settings.officeHours)
        plannedBreaks = PlannedBreakScheduler(engine: engine, breaks: settingsStore.settings.plannedBreaks)
        engine.start()
    }

    /// Debug-timing runs disable idle pause so an untouched machine still cycles.
    private func effectiveSmartPause(_ config: SmartPauseConfig) -> SmartPauseConfig {
        var config = config
        if debugTimingActive { config.idlePauseSeconds = 0 }
        return config
    }

    private func registerHotkeys() {
        // ⌥⇧B — start break now
        hotkeys.register(id: 1, keyCode: kVK_ANSI_B, modifiers: optionKey | shiftKey) { [weak self] in
            self?.engine.startBreakNow()
        }
        // ⌥⇧P — toggle pause
        hotkeys.register(id: 2, keyCode: kVK_ANSI_P, modifiers: optionKey | shiftKey) { [weak self] in
            guard let engine = self?.engine else { return }
            engine.phase.isInactive ? engine.resume() : engine.pause(until: nil)
        }
    }
}

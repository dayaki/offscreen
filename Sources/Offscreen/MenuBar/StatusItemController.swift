import AppKit

/// Owns the NSStatusItem: live countdown title, icon state, and the menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let engine: BreakEngine
    private let settingsStore: SettingsStore
    private let item: NSStatusItem
    private var lastTitle = ""

    /// Set by the container to open the Settings/Stats windows.
    var openSettings: (() -> Void)?
    var openStats: (() -> Void)?

    init(engine: BreakEngine, settingsStore: SettingsStore) {
        self.engine = engine
        self.settingsStore = settingsStore
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = item.button {
            button.image = Self.menuBarIcon()
            button.imagePosition = .imageLeading
        }
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu

        engine.addListener { [weak self] event in
            if case .tick = event { self?.updateTitle() }
        }
        updateTitle()
    }

    /// The Offscreen mark for the menu bar: the eye-closed glyph inside a white
    /// circle badge so it stands out. It's a full-color image (white + dark), so
    /// isTemplate is false — otherwise macOS would flatten it to a single tint.
    /// Falls back to an SF Symbol if the asset is missing.
    private static func menuBarIcon() -> NSImage {
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = false
            return image
        }
        return NSImage(systemSymbolName: "eye", accessibilityDescription: "Offscreen") ?? NSImage()
    }

    // MARK: Title

    private func updateTitle() {
        let title: String
        switch engine.phase {
        case .inactive(.paused): title = " ⏸"
        case .inactive(.outsideOfficeHours): title = ""
        case .inBreak: title = " \(Format.clock(engine.breakRemaining))"
        case .holding: title = " ⏳"
        case _ where engine.isPausedByHold:
            title = " ⏳" // busy (meeting, media, screen share…) — countdown frozen
        default:
            title = settingsStore.settings.showCountdownInMenuBar
                ? " \(Format.clock(max(0, engine.timeUntilBreak)))"
                : ""
        }
        guard title != lastTitle, let button = item.button else { return }
        lastTitle = title
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)]
        )
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(title: headerText(), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())

        menu.addItem(makeItem("Start Break Now", #selector(startBreakNow)))
        menu.addItem(makeItem("Skip to Next Break", #selector(skipBreak)))
        menu.addItem(.separator())

        if engine.phase.isInactive {
            menu.addItem(makeItem("Resume", #selector(resume)))
        } else {
            let pauseMenu = NSMenu()
            pauseMenu.addItem(makeItem("For 1 Hour", #selector(pause1h)))
            pauseMenu.addItem(makeItem("Until Tomorrow", #selector(pauseUntilTomorrow)))
            pauseMenu.addItem(makeItem("Until I Resume", #selector(pauseIndefinitely)))
            let pauseItem = NSMenuItem(title: "Pause Breaks", action: nil, keyEquivalent: "")
            pauseItem.submenu = pauseMenu
            menu.addItem(pauseItem)
        }
        menu.addItem(.separator())

        menu.addItem(makeItem("Stats…", #selector(showStats)))
        let settingsItem = makeItem("Settings…", #selector(showSettings))
        settingsItem.keyEquivalent = ","
        settingsItem.keyEquivalentModifierMask = [.command]
        menu.addItem(settingsItem)
        menu.addItem(.separator())

        if ProcessInfo.processInfo.environment["OFFSCREEN_TIME_SCALE"] != nil
            || ProcessInfo.processInfo.environment["OFFSCREEN_DEBUG"] != nil {
            let debugMenu = NSMenu()
            debugMenu.addItem(makeItem("Break in 5 Seconds", #selector(debugBreakSoon)))
            debugMenu.addItem(makeItem("Dump State to Log", #selector(debugDumpState)))
            let debugItem = NSMenuItem(title: "Debug", action: nil, keyEquivalent: "")
            debugItem.submenu = debugMenu
            menu.addItem(debugItem)
            menu.addItem(.separator())
        }

        let quit = NSMenuItem(title: "Quit Offscreen", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
        menu.addItem(quit)
    }

    private func headerText() -> String {
        switch engine.phase {
        case .inactive(.paused(let until?)):
            return "Paused until \(until.formatted(date: .omitted, time: .shortened))"
        case .inactive(.paused(nil)):
            return "Paused"
        case .inactive(.outsideOfficeHours):
            return "Outside office hours"
        case .inBreak:
            return "\(engine.activeBreak?.title ?? "Break") — \(Format.clock(engine.breakRemaining)) left"
        case .holding:
            let reasons = engine.holdReasons.map(\.label).joined(separator: ", ")
            return "Break held: \(reasons)"
        case _ where engine.isPausedByHold:
            let reasons = engine.holdReasons.map(\.label).joined(separator: ", ")
            return "Paused — \(reasons)"
        default:
            return "\(engine.nextBreakKind.title) in \(Format.clock(max(0, engine.timeUntilBreak)))"
        }
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: Actions

    @objc private func showSettings() { openSettings?() }
    @objc private func showStats() { openStats?() }
    @objc private func startBreakNow() { engine.startBreakNow() }
    @objc private func skipBreak() { engine.skipBreak() }
    @objc private func pause1h() { engine.pause(until: Date().addingTimeInterval(3600)) }
    @objc private func pauseIndefinitely() { engine.pause(until: nil) }
    @objc private func resume() { engine.resume() }

    @objc private func pauseUntilTomorrow() {
        let calendar = Calendar.current
        let tomorrow = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: Date()) ?? Date())
        engine.pause(until: tomorrow)
    }

    @objc private func debugBreakSoon() { engine.debugSetTimeUntilBreak(5) }
    @objc private func debugDumpState() { Log.engine.info("\(self.engine.debugDescription)") }
}

import AppKit
import CoreGraphics

/// Detects a frontmost app running fullscreen by comparing its layer-0 window
/// bounds against display bounds. Reads only bounds/PID/layer — never window
/// names (the one field that would require Screen Recording permission).
final class FullscreenAppMonitor {
    private(set) var isFullscreen = false
    private var timer: Timer?
    private var activationObserver: NSObjectProtocol?
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        timer = Poll.every(2.0) { [weak self] in self?.poll() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { [weak self] in self?.poll() }
        }
    }

    private func poll() {
        let fullscreen = Self.frontmostAppIsFullscreen()
        guard fullscreen != isFullscreen else { return }
        isFullscreen = fullscreen
        Log.monitors.info("fullscreen app frontmost: \(fullscreen)")
        onChange(fullscreen)
    }

    private static func frontmostAppIsFullscreen() -> Bool {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier
        else { return false }

        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        let displayBounds = NSScreen.screens.compactMap { screen -> CGRect? in
            guard let number = screen.deviceDescription[
                NSDeviceDescriptionKey("NSScreenNumber")
            ] as? NSNumber else { return nil }
            // CGDisplayBounds is in the same top-left global space as
            // kCGWindowBounds, unlike NSScreen.frame.
            return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
        }

        for window in windows {
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 0,
                  let ownerPID = window[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID == frontmost.processIdentifier,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { continue }

            for display in displayBounds {
                let tolerance: CGFloat = 2
                if abs(bounds.minX - display.minX) <= tolerance,
                   abs(bounds.minY - display.minY) <= tolerance,
                   abs(bounds.width - display.width) <= tolerance,
                   abs(bounds.height - display.height) <= tolerance {
                    return true
                }
            }
        }
        return false
    }
}

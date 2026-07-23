import Carbon.HIToolbox
import AppKit

/// Global hotkeys via Carbon's RegisterEventHotKey — the only global-hotkey
/// mechanism that needs no Accessibility/Input Monitoring permission.
final class HotkeyCenter {
    private var actions: [UInt32: () -> Void] = [:]
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?

    private static let signature: OSType = 0x4F53_434E // 'OSCN'

    init() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, event, userData -> OSStatus in
                guard let event, let userData else { return noErr }
                var hkID = EventHotKeyID()
                GetEventParameter(
                    event, EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID), nil,
                    MemoryLayout<EventHotKeyID>.size, nil, &hkID
                )
                // Carbon dispatches on the main event loop.
                let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
                MainActor.assumeIsolated { center.fire(hkID.id) }
                return noErr
            },
            1, &spec, selfPtr, &eventHandler
        )
        if status != noErr {
            Log.app.error("hotkey handler install failed: \(status)")
        }
    }

    func register(id: UInt32, keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        actions[id] = action
        var ref: EventHotKeyRef?
        let hkID = EventHotKeyID(signature: Self.signature, id: id)
        let status = RegisterEventHotKey(
            UInt32(keyCode), UInt32(modifiers), hkID,
            GetEventDispatcherTarget(), 0, &ref
        )
        if status == noErr, let ref {
            hotKeyRefs.append(ref)
        } else {
            Log.app.error("hotkey \(id) registration failed: \(status)")
        }
    }

    private func fire(_ id: UInt32) {
        actions[id]?()
    }
}

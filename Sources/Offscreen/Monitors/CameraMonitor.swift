import CoreMediaIO
import Foundation

/// Detects whether ANY app is using a camera by reading the CoreMediaIO
/// "device is running somewhere" HAL property — no capture session, so no
/// camera permission prompt. Polled because property listeners can silently
/// die across device replugs.
final class CameraMonitor {
    private(set) var isCameraOn = false
    private var timer: Timer?
    private let onChange: (Bool) -> Void

    init(onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        timer = Poll.every(2.0) { [weak self] in self?.poll() }
    }

    private func poll() {
        let on = Self.anyCameraRunning()
        guard on != isCameraOn else { return }
        isCameraOn = on
        Log.monitors.info("camera in use: \(on)")
        onChange(on)
    }

    private static func anyCameraRunning() -> Bool {
        for device in cameraDevices() {
            var address = CMIOObjectPropertyAddress(
                mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
                mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeWildcard),
                mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementWildcard)
            )
            var isRunning: UInt32 = 0
            var size = UInt32(MemoryLayout<UInt32>.size)
            if CMIOObjectGetPropertyData(device, &address, 0, nil, size, &size, &isRunning) == noErr,
               isRunning != 0 {
                return true
            }
        }
        return false
    }

    private static func cameraDevices() -> [CMIOObjectID] {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        var dataSize: UInt32 = 0
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &dataSize) == noErr,
              dataSize > 0
        else { return [] }
        var devices = [CMIOObjectID](
            repeating: 0, count: Int(dataSize) / MemoryLayout<CMIOObjectID>.size
        )
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, dataSize, &used, &devices) == noErr
        else { return [] }
        return devices
    }
}

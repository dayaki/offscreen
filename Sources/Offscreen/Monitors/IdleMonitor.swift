import CoreGraphics
import Foundation

/// Seconds since the user last touched keyboard/mouse, via CGEventSource
/// queries (permission-free; not an event tap). Reported once per second.
final class IdleMonitor {
    private var timer: Timer?
    private let onTick: (Double) -> Void

    init(onTick: @escaping (Double) -> Void) {
        self.onTick = onTick
        timer = Poll.every(1.0) { [weak self] in
            guard let self else { return }
            self.onTick(Self.idleSeconds())
        }
    }

    static func idleSeconds() -> Double {
        let types: [CGEventType] = [
            .mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown,
            .scrollWheel, .leftMouseDragged,
        ]
        return types
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
    }
}

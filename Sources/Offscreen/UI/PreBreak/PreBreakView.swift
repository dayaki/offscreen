import SwiftUI
import AppKit

/// Playful one-liners for the heads-up card. A fresh line is picked every
/// time the panel appears (never the same one twice in a row).
enum PreBreakCopy {
    private static let shortLines = [
        "Your eyes have earned this.",
        "Blink twice if you're ready.",
        "The pixels will survive without you.",
        "Look at something 20 feet away.",
        "Your screen could use a minute alone.",
        "Rest those hardworking eyeballs.",
        "Stretch, sip, stare into the distance.",
        "There's a horizon out there. Find it.",
        "Your posture called. It wants a word.",
        "The far wall misses you.",
        "Unclench the jaw. Drop the shoulders.",
        "A tiny vacation is approaching.",
    ]

    private static let longLines = [
        "A longer break. The desk can wait.",
        "Go refill the water. Stretch a little.",
        "Step away properly this time.",
    ]

    private static var lastLine: String?

    static func line(for kind: BreakKind) -> String {
        let pool: [String]
        switch kind {
        case .short: pool = shortLines
        case .long: pool = longLines
        case .planned(let name, _): return "\(name) is coming up."
        }
        let fresh = pool.filter { $0 != lastLine }
        let pick = (fresh.isEmpty ? pool : fresh).randomElement() ?? pool[0]
        lastLine = pick
        return "Almost time — \(pick)"
    }
}

/// Heads-up card shown before a break: gradient clock badge, big countdown,
/// a playful line, and start/snooze pills on a deep-indigo card.
struct PreBreakView: View {
    let engine: BreakEngine
    let line: String

    @State private var hostWindow: NSWindow?
    /// Cursor + window origin captured when a drag begins. Using the absolute
    /// cursor position (not the gesture's translation) avoids a feedback loop
    /// as the window moves under the pointer.
    @State private var dragAnchor: (mouse: NSPoint, origin: NSPoint)?

    private var secondsLeft: Int { max(0, Int(engine.timeUntilBreak.rounded(.up))) }

    private var timeText: String {
        String(format: "%02d:%02d", secondsLeft / 60, secondsLeft % 60)
    }

    /// Drag the card by its body (the buttons keep their own clicks).
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in
                guard let window = hostWindow else { return }
                let mouse = NSEvent.mouseLocation
                let anchor = dragAnchor ?? (mouse, window.frame.origin)
                if dragAnchor == nil { dragAnchor = anchor }
                window.setFrameOrigin(NSPoint(
                    x: anchor.origin.x + (mouse.x - anchor.mouse.x),
                    y: anchor.origin.y + (mouse.y - anchor.mouse.y)
                ))
            }
            .onEnded { _ in dragAnchor = nil }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 11) {
                ClockBadge(secondsLeft: secondsLeft, leadSeconds: engine.timing.leadTimeSeconds)

                VStack(alignment: .leading, spacing: 1) {
                    Text(timeText)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(countsDown: true))
                    Text(line)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture)

            HStack(spacing: 8) {
                Button { engine.startBreakNow() } label: {
                    Text("Start this break now")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 13)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.13), in: Capsule())
                }
                .buttonStyle(.plain)

                Spacer(minLength: 4)

                snoozePill(60, "+1m")
                snoozePill(300, "+5m")
                snoozePill(900, "+15m")
            }
        }
        .padding(17)
        .frame(width: 385, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Theme.Dusk.cardTop, Theme.Dusk.cardBottom],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.09), lineWidth: 1)
                )
        )
        .background(WindowReader { hostWindow = $0 })
        .environment(\.colorScheme, .dark)
    }

    private func snoozePill(_ seconds: Int, _ label: String) -> some View {
        let enabled = engine.snoozesRemaining > 0
        return Button { engine.snooze(seconds: seconds) } label: {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .overlay(Capsule().strokeBorder(.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .help(enabled ? "Snooze this break" : "No snoozes left this cycle")
    }
}

/// Reports the hosting NSWindow up to the view once it's placed, so the drag
/// gesture can move it. Transparent to the mouse so it never intercepts hits.
private struct WindowReader: NSViewRepresentable {
    let onResolve: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = PassthroughView()
        DispatchQueue.main.async { onResolve(view.window) }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async { onResolve(nsView.window) }
    }

    private final class PassthroughView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// Warm gradient dial: twelve ticks and a hand that sweeps as the
/// countdown runs out.
private struct ClockBadge: View {
    let secondsLeft: Int
    let leadSeconds: Int

    private var handAngle: Angle {
        let fraction = Double(secondsLeft) / Double(max(1, leadSeconds))
        return .degrees(-360 * fraction)
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Theme.Dusk.rose, Theme.Dusk.amber],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )
            ForEach(0..<12, id: \.self) { tick in
                Capsule()
                    .fill(.white.opacity(0.6))
                    .frame(width: 1.5, height: 3.5)
                    .offset(y: -16.5)
                    .rotationEffect(.degrees(Double(tick) * 30))
            }
            Capsule()
                .fill(.white)
                .frame(width: 2.5, height: 13)
                .offset(y: -6.5)
                .rotationEffect(handAngle)
                .animation(.linear(duration: 0.3), value: handAngle)
                .shadow(color: .black.opacity(0.15), radius: 1, y: 1)
        }
        .frame(width: 44, height: 44)
    }
}

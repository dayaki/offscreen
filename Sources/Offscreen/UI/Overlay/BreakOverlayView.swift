import SwiftUI

struct BreakOverlayView: View {
    let engine: BreakEngine
    var style: OverlayStyle = OverlayStyle()

    var body: some View {
        ZStack {
            OverlayBackground(style: style)

            VStack(spacing: 36) {
                Text(engine.activeBreak?.title ?? "Break")
                    .font(.system(size: 22, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.55))
                    .textCase(.uppercase)
                    .kerning(3)

                Text(engine.breakMessage)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)

                CountdownRing(progress: engine.breakProgress, text: Format.clock(engine.breakRemaining))
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    if engine.behavior.difficulty != .hardcore {
                        overlayButton(skipLabel, enabled: engine.canSkipOverlay) {
                            engine.skipBreak()
                        }
                    }
                    if engine.behavior.endEarlyMinimumSeconds != nil {
                        overlayButton("End Break", enabled: engine.canEndEarlyNow) {
                            engine.endBreakEarly()
                        }
                    }
                }
                .frame(height: 36)
            }
        }
        .ignoresSafeArea()
    }

    private var skipLabel: String {
        if engine.canSkipOverlay { return "Skip Break" }
        let wait = Double(engine.behavior.skipEnableDelaySeconds) - engine.breakElapsed
        return "Skip in \(max(1, Int(wait.rounded(.up))))"
    }

    private func overlayButton(_ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.plain)
            .font(.system(size: 14, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(enabled ? 0.6 : 0.25))
            .padding(.vertical, 8)
            .padding(.horizontal, 18)
            .background(.white.opacity(enabled ? 0.1 : 0.04), in: Capsule())
            .disabled(!enabled)
    }
}

import SwiftUI

struct CountdownRing: View {
    let progress: Double // fraction remaining, 1 → 0
    let text: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 6)
            Circle()
                .trim(from: 0, to: max(0, min(1, progress)))
                .stroke(.white.opacity(0.9), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: progress)
            Text(text)
                .font(.system(size: 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
        }
        .frame(width: 170, height: 170)
    }
}

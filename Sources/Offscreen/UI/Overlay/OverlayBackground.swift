import SwiftUI
import AppKit
import CoreImage

/// The break overlay's backdrop: animated aurora (default), system blur, or a
/// user-chosen image. All variants keep things dark so the countdown and
/// message stay readable.
struct OverlayBackground: View {
    let style: OverlayStyle

    var body: some View {
        switch style.kind {
        case .gradient:
            AuroraBackground()
        case .blur:
            BehindWindowBlur()
                .overlay(Color.black.opacity(0.35))
                .overlay(GrainOverlay())
        case .image:
            if let path = style.imagePath, let image = NSImage(contentsOfFile: path) {
                GeometryReader { geo in
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .overlay(Color.black.opacity(0.45))
            } else {
                OverlayBackground(style: OverlayStyle(kind: .gradient))
            }
        }
    }
}

/// Animated aurora. Preferred path: a per-pixel Metal shader (domain-warped
/// flowing waves + film grain, see Resources/Aurora.metal). When the bundle
/// carries no shader library, falls back to a pure-SwiftUI composition of a
/// drifting mesh gradient, traveling glow blobs, and blurred sine ribbons.
///
/// Repaint is driven by an explicit timer (AuroraClock), NOT
/// TimelineView(.animation): the overlay lives in a non-activating
/// screen-saver-level window shown via orderFrontRegardless(), where the
/// display link behind TimelineView never starts ticking.
struct AuroraBackground: View {
    /// Scripts/build-app.sh compiles Aurora.metal into the app bundle; running
    /// via `swift test`/`swift run` has no metallib, so we check once.
    private static let shaderAvailable =
        Bundle.main.url(forResource: "default", withExtension: "metallib") != nil

    @State private var clock = AuroraClock()

    var body: some View {
        GeometryReader { geo in
            let t = clock.time
            if Self.shaderAvailable {
                // The mesh doubles as the content the effect samples, so a
                // shader failure degrades to the animated mesh, not black.
                meshField(at: t)
                    .colorEffect(
                        ShaderLibrary.default.aurora(
                            .float2(geo.size),
                            .float(Float(t))
                        )
                    )
            } else {
                ZStack {
                    meshField(at: t)
                    glows(at: t, in: geo.size)
                    ribbons(at: t, in: geo.size)
                }
                .overlay(GrainOverlay())
                .overlay(vignette)
            }
        }
        .ignoresSafeArea()
        .onAppear { clock.start() }
        .onDisappear { clock.stop() }
    }

    // MARK: Mesh base

    private func meshField(at t: Double) -> some View {
        let drift = { (speed: Double, phase: Double) -> Float in
            Float(sin(t * speed + phase))
        }
        let points: [SIMD2<Float>] = [
            [0, 0], [0.5 + 0.25 * drift(0.50, 0), 0], [1, 0],
            [0, 0.5 + 0.22 * drift(0.42, 2)],
            [0.5 + 0.30 * drift(0.35, 1), 0.5 + 0.28 * drift(0.60, 3)],
            [1, 0.5 + 0.26 * drift(0.45, 5)],
            [0, 1], [0.5 + 0.24 * drift(0.52, 4), 1], [1, 1],
        ]

        let breathe = 0.5 + 0.5 * sin(t * 0.30)
        let roseAccent = Palette.rose.mix(with: Palette.amber, by: breathe)
        let violetAccent = Palette.violet.mix(with: Palette.plum, by: 1 - breathe)

        return MeshGradient(
            width: 3, height: 3,
            points: points,
            colors: [
                Palette.deep, violetAccent, Palette.navy,
                roseAccent, Palette.dusk, Palette.plum,
                Palette.navy, Palette.amberDim, Palette.deep,
            ]
        )
    }

    // MARK: Glow blobs

    private func glows(at t: Double, in size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            glow(
                Theme.Dusk.violet, radius: 0.52 * w,
                x: w * (0.28 + 0.24 * sin(t * 0.26)),
                y: h * (0.32 + 0.26 * sin(t * 0.33 + 1.7))
            )
            glow(
                Theme.Dusk.rose, radius: 0.46 * w,
                x: w * (0.72 + 0.22 * sin(t * 0.21 + 4.1)),
                y: h * (0.62 + 0.24 * sin(t * 0.29 + 0.6))
            )
            glow(
                Theme.Dusk.amber, radius: 0.50 * w,
                x: w * (0.55 + 0.30 * sin(t * 0.17 + 2.4)),
                y: h * (0.18 + 0.20 * sin(t * 0.24 + 3.3))
            )
        }
        .blendMode(.screen)
    }

    private func glow(_ color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) -> some View {
        RadialGradient(
            colors: [color.opacity(0.34), color.opacity(0)],
            center: .center, startRadius: 0, endRadius: radius
        )
        .frame(width: radius * 2, height: radius * 2)
        .position(x: x, y: y)
    }

    // MARK: Wave ribbons

    private func ribbons(at t: Double, in size: CGSize) -> some View {
        ZStack {
            WaveRibbon(phase: t * 0.9, baseline: 0.30, amplitude: 0.085)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Dusk.violet, Theme.Dusk.rose],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size.height * 0.14, lineCap: .round)
                )
                .blur(radius: 46)
                .opacity(0.40)
            WaveRibbon(phase: -t * 0.65 + 2.0, baseline: 0.72, amplitude: 0.10)
                .stroke(
                    LinearGradient(
                        colors: [Theme.Dusk.amber, Theme.Dusk.rose],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: size.height * 0.16, lineCap: .round)
                )
                .blur(radius: 52)
                .opacity(0.34)
        }
        .blendMode(.screen)
    }

    private var vignette: some View {
        EllipticalGradient(
            stops: [
                .init(color: .clear, location: 0.55),
                .init(color: .black.opacity(0.35), location: 1.0),
            ],
            center: .center
        )
        .allowsHitTesting(false)
    }

    /// Golden-hour site tokens dimmed to mesh-mixing levels; bright accents
    /// (glows, ribbons) come straight from Theme.Dusk.
    private enum Palette {
        static let deep = Theme.Dusk.bg0
        static let navy = Theme.Dusk.bg1
        static let dusk = Color(hex: 0x241736)
        static let violet = Color(hex: 0x6B5294)
        static let rose = Color(hex: 0x9E4D61)
        static let amber = Color(hex: 0xB88242)
        static let amberDim = Color(hex: 0x5C3A20)
        static let plum = Color(hex: 0x5C2957)
    }
}

/// 30 fps repaint driver for the aurora. Publishes elapsed seconds via
/// @Observable so any view reading `time` re-renders on each tick. Runs only
/// while an overlay is on screen (started/stopped from onAppear/onDisappear).
@Observable
final class AuroraClock {
    private(set) var time: Double = 0
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let epoch = ContinuousClock.now
    @ObservationIgnored private var logged = 0

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        timer.tolerance = 1.0 / 60.0
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Log.windows.info("aurora clock started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        Log.windows.info("aurora clock stopped at t=\(self.time, privacy: .public)")
    }

    private func tick() {
        let d = epoch.duration(to: .now)
        time = Double(d.components.seconds) + Double(d.components.attoseconds) / 1e18
        // A few early breadcrumbs so a stalled clock is visible in the log.
        if logged < 3, time > Double(logged + 1) * 2 {
            logged += 1
            Log.windows.info("aurora clock ticking, t=\(self.time, privacy: .public)")
        }
    }
}

/// An open sine curve across the width — two stacked frequencies so crests
/// look organic rather than metronomic. Stroked wide + blurred = aurora band.
private struct WaveRibbon: Shape {
    var phase: Double
    var baseline: CGFloat  // fraction of height
    var amplitude: CGFloat // fraction of height

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let steps = 72
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            let angle = Double(fx) * 2 * .pi * 1.8 + phase
            let wave = sin(angle) + 0.55 * sin(angle * 1.7 + 1.3)
            let point = CGPoint(
                // Overshoot the edges so the round caps stay offscreen.
                x: rect.width * (fx * 1.2 - 0.1),
                y: rect.height * (baseline + amplitude * CGFloat(wave))
            )
            if i == 0 { p.move(to: point) } else { p.addLine(to: point) }
        }
        return p
    }
}

/// Static film-grain layer: a small monochrome noise tile (generated once via
/// Core Image) tiled across the screen in overlay blend mode. Static grain
/// reads as texture without the shimmer of animated noise.
struct GrainOverlay: View {
    var opacity: Double = 0.055

    var body: some View {
        Image(nsImage: Self.tile)
            .resizable(resizingMode: .tile)
            .opacity(opacity)
            .blendMode(.overlay)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private static let tile: NSImage = {
        let side = 256
        let rect = CGRect(x: 0, y: 0, width: side, height: side)
        guard
            let noise = CIFilter(name: "CIRandomGenerator")?.outputImage?
                .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
                .cropped(to: rect),
            let cg = CIContext().createCGImage(noise, from: rect)
        else { return NSImage(size: NSSize(width: side, height: side)) }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }()
}

private struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

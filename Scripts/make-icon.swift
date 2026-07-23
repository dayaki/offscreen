// Generates Resources/AppIcon.icns: the "eyes" symbol on a night-blue
// gradient squircle. Run once: swift Scripts/make-icon.swift
import AppKit

let sizes = [16, 32, 64, 128, 256, 512, 1024]

func render(_ pixels: Int) -> NSImage {
    let size = NSSize(width: pixels, height: pixels)
    let image = NSImage(size: size)
    image.lockFocus()

    let rect = NSRect(origin: .zero, size: size)
    let inset = rect.insetBy(dx: rect.width * 0.05, dy: rect.height * 0.05)
    let path = NSBezierPath(roundedRect: inset, xRadius: inset.width * 0.22, yRadius: inset.width * 0.22)
    let gradient = NSGradient(
        starting: NSColor(calibratedRed: 0.16, green: 0.32, blue: 0.55, alpha: 1),
        ending: NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.18, alpha: 1)
    )
    gradient?.draw(in: path, angle: -90)

    let config = NSImage.SymbolConfiguration(
        pointSize: CGFloat(pixels) * 0.42, weight: .medium
    )
    if let symbol = NSImage(systemSymbolName: "eyes", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let tinted = NSImage(size: symbol.size)
        tinted.lockFocus()
        NSColor.white.set()
        let symbolRect = NSRect(origin: .zero, size: symbol.size)
        symbol.draw(in: symbolRect)
        symbolRect.fill(using: .sourceAtop)
        tinted.unlockFocus()

        let target = NSRect(
            x: (size.width - tinted.size.width) / 2,
            y: (size.height - tinted.size.height) / 2,
            width: tinted.size.width,
            height: tinted.size.height
        )
        tinted.draw(in: target)
    }

    image.unlockFocus()
    return image
}

let iconsetURL = URL(fileURLWithPath: "Resources/AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

for pixels in sizes {
    let image = render(pixels)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { continue }
    let base = pixels <= 512 ? pixels : 512
    let names = pixels <= 512
        ? ["icon_\(base)x\(base).png"]
        : ["icon_512x512@2x.png"]
    for name in names {
        try png.write(to: iconsetURL.appendingPathComponent(name))
    }
    if pixels >= 32, pixels <= 1024, pixels != 1024 {
        // also serves as the @2x of the size below it
        let half = pixels / 2
        try png.write(to: iconsetURL.appendingPathComponent("icon_\(half)x\(half)@2x.png"))
    }
}

let task = Process()
task.launchPath = "/usr/bin/iconutil"
task.arguments = ["-c", "icns", iconsetURL.path, "-o", "Resources/AppIcon.icns"]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "✓ Resources/AppIcon.icns" : "iconutil failed")

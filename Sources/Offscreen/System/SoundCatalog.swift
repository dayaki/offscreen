import AppKit

/// The catalog of ambient tracks that can play during a break: a set of
/// built-in loops shipped with the app, plus any audio files the user drops
/// into the Sounds folder.
///
/// A track is stored in settings as a small string identifier:
///   - `"none"`             → silent
///   - `"bundled:rain.m4a"` → a shipped loop (in the app bundle's Ambient/)
///   - `"custom:waves.mp3"` → a file in the user's Sounds folder
enum SoundCatalog {
    static let none = "none"

    /// Built-in ambient loops (file in Resources/Ambient, display label). They
    /// loop seamlessly, so they fill a break of any length.
    static let bundled: [(file: String, label: String)] = [
        ("rain.m4a", "Rain"),
        ("ocean.m4a", "Ocean Waves"),
        ("brown-noise.m4a", "Brown Noise"),
        ("wind.m4a", "Soft Wind"),
    ]

    static let audioExtensions: Set<String> = ["mp3", "wav", "aiff", "aif", "m4a", "caf", "aac", "flac"]

    /// `~/Library/Application Support/Offscreen/Sounds` — where the user drops
    /// their own audio files (e.g. tracks downloaded from Pixabay).
    static var customDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("Offscreen/Sounds", isDirectory: true)
    }

    /// Creates the Sounds folder if needed and returns it.
    @discardableResult
    static func ensureCustomDirectory() -> URL {
        let dir = customDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Audio filenames currently sitting in the Sounds folder, sorted.
    static func customSounds() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: customDirectory, includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { audioExtensions.contains($0.pathExtension.lowercased()) }
            .map(\.lastPathComponent)
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: Identifier helpers

    static func bundledID(_ file: String) -> String { "bundled:\(file)" }
    static func customID(_ filename: String) -> String { "custom:\(filename)" }

    /// A human-readable label for a stored identifier.
    static func label(for id: String) -> String {
        if id.isEmpty || id == none { return "None" }
        if id.hasPrefix("bundled:") {
            let file = String(id.dropFirst("bundled:".count))
            return bundled.first { $0.file == file }?.label ?? file
        }
        if id.hasPrefix("custom:") { return String(id.dropFirst("custom:".count)) }
        return id
    }

    /// Resolves an identifier to a playable file URL on disk, or nil for
    /// "none"/missing. A bundled track that's absent (e.g. running via
    /// `swift run`) or a deleted custom file both resolve to nil gracefully.
    static func url(for id: String) -> URL? {
        guard !id.isEmpty, id != none else { return nil }
        if id.hasPrefix("bundled:") {
            let file = String(id.dropFirst("bundled:".count))
            let name = (file as NSString).deletingPathExtension
            let ext = (file as NSString).pathExtension
            return Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Ambient")
        }
        if id.hasPrefix("custom:") {
            let url = customDirectory.appendingPathComponent(String(id.dropFirst("custom:".count)))
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        // Tolerate a legacy absolute path.
        let url = URL(fileURLWithPath: id)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    /// Copies a user-picked file into the Sounds folder and returns its
    /// `custom:` identifier (used by "Add your own…"). Overwrites a same-named
    /// file so re-adding refreshes it.
    static func importCustom(from source: URL) -> String? {
        let dir = ensureCustomDirectory()
        let dest = dir.appendingPathComponent(source.lastPathComponent)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.copyItem(at: source, to: dest)
            return customID(dest.lastPathComponent)
        } catch {
            Log.app.error("failed to import sound: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

struct AppearanceTab: View {
    let store: SettingsStore

    @State private var customSounds: [String] = SoundCatalog.customSounds()
    @State private var preview = AmbientPreview()

    var body: some View {
        Form {
            Section("Break screen") {
                Picker("Background", selection: store.binding(\.overlayStyle.kind)) {
                    ForEach(OverlayStyleKind.allCases, id: \.self) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                if store.settings.overlayStyle.kind == .image {
                    HStack {
                        Text(store.settings.overlayStyle.imagePath.map {
                            URL(fileURLWithPath: $0).lastPathComponent
                        } ?? "No image chosen")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        Spacer()
                        Button("Choose Image…") { pickImage() }
                    }
                }
            }

            Section {
                messageEditor(
                    "Short break messages",
                    binding: store.binding(\.customShortMessages),
                    placeholder: BreakMessages.short
                )
                messageEditor(
                    "Long break messages",
                    binding: store.binding(\.customLongMessages),
                    placeholder: BreakMessages.long
                )
            } header: {
                Text("Messages")
            } footer: {
                Text("One message per line. Leave empty to use the built-in set; a random one shows on each break.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Play a sound when a break ends", isOn: store.binding(\.sound.enabled))
                if store.settings.sound.enabled {
                    HStack {
                        Picker("Sound", selection: store.binding(\.sound.ambient)) {
                            Text("None").tag(SoundCatalog.none)
                            ForEach(SoundCatalog.bundled, id: \.file) { track in
                                Text(track.label).tag(SoundCatalog.bundledID(track.file))
                            }
                            if !customSounds.isEmpty {
                                Divider()
                                ForEach(customSounds, id: \.self) { file in
                                    Text(file).tag(SoundCatalog.customID(file))
                                }
                            }
                        }
                        Button {
                            preview.toggle(
                                id: store.settings.sound.ambient,
                                volume: store.settings.sound.volume
                            )
                        } label: {
                            Image(systemName: preview.isPlaying ? "stop.circle.fill" : "play.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(store.settings.sound.ambient == SoundCatalog.none)
                        .help(preview.isPlaying ? "Stop preview" : "Preview this sound")
                    }
                    Slider(value: store.binding(\.sound.volume), in: 0...1) {
                        Text("Volume")
                    }
                }
            } header: {
                Text("When a break ends")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Plays when a break finishes — not during it — so you know it's over, even from across the room. It keeps playing until you're back at the keyboard or mouse, then stops on its own.")
                    HStack(spacing: 8) {
                        Button("Add Your Own…") { addOwnSound() }
                        Button("Show Folder") { revealSoundsFolder() }
                        Button("Rescan") { customSounds = SoundCatalog.customSounds() }
                    }
                    .padding(.top, 2)
                    Text("“Add Your Own…” copies an audio file into your Sounds folder and selects it. You can also drop files there directly (e.g. tracks downloaded from Pixabay) and click Rescan.")
                        .foregroundStyle(.tertiary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { customSounds = SoundCatalog.customSounds() }
        .onDisappear { preview.stop() }
    }

    private func addOwnSound() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.message = "Choose an audio file to use as an ambient break track."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let id = SoundCatalog.importCustom(from: url) else { return }
        customSounds = SoundCatalog.customSounds()
        store.update { $0.sound.ambient = id }
    }

    private func revealSoundsFolder() {
        let dir = SoundCatalog.ensureCustomDirectory()
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dir.path)
        customSounds = SoundCatalog.customSounds()
    }

    private func messageEditor(_ label: String, binding: Binding<[String]>, placeholder: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.callout)
            TextEditor(text: Binding(
                get: { binding.wrappedValue.joined(separator: "\n") },
                set: { text in
                    binding.wrappedValue = text
                        .split(separator: "\n", omittingEmptySubsequences: true)
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            ))
            .font(.callout)
            .frame(height: 70)
            .overlay(alignment: .topLeading) {
                if binding.wrappedValue.isEmpty {
                    Text(placeholder.prefix(2).joined(separator: "\n") + "\n…")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }
        }
    }

    private func pickImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        guard panel.runModal() == .OK, let url = panel.url else { return }
        store.update { $0.overlayStyle.imagePath = url.path }
    }
}

/// Previews an ambient track in Settings: a looping player with a play/stop
/// toggle. @Observable so the button icon reflects the playing state.
@Observable
final class AmbientPreview {
    private(set) var isPlaying = false
    @ObservationIgnored private var player: AVAudioPlayer?

    func toggle(id: String, volume: Double) {
        if isPlaying { stop(); return }
        guard let url = SoundCatalog.url(for: id),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.numberOfLoops = -1
        player.volume = Float(volume)
        player.play()
        self.player = player
        isPlaying = true
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
    }
}

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct SmartPauseTab: View {
    let store: SettingsStore

    var body: some View {
        Form {
            Section {
                Toggle("Meetings and calls (camera on)", isOn: store.binding(\.smartPause.pauseOnCamera))
                Toggle("Meetings and calls (microphone in use)", isOn: store.binding(\.smartPause.pauseOnMic))
                Toggle("Video or audio playback", isOn: store.binding(\.smartPause.pauseOnMedia))
                if store.settings.smartPause.pauseOnMedia {
                    VStack(alignment: .leading, spacing: 2) {
                        Toggle("Keep going for music players", isOn: store.binding(\.smartPause.ignoreMusicPlayers))
                        Text("Spotify, Apple Music, and iTunes won't hold breaks. Meetings still pause (they use the microphone).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.leading, 18)
                }
                Toggle("Screen sharing or recording", isOn: store.binding(\.smartPause.pauseOnScreenShare))
                Toggle("Fullscreen apps and games", isOn: store.binding(\.smartPause.pauseOnFullscreen))
            } header: {
                Text("Automatically hold breaks during")
            }

            Section("Deep focus apps") {
                let ids = store.settings.smartPause.focusAppBundleIDs
                if ids.isEmpty {
                    Text("Breaks are held while any app you add here is frontmost.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(ids, id: \.self) { bundleID in
                    HStack {
                        Text(appName(for: bundleID))
                        Text(bundleID).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Button(role: .destructive) {
                            store.update { $0.smartPause.focusAppBundleIDs.removeAll { $0 == bundleID } }
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
                Button("Add App…") { pickApp() }
            }

            Section("Idle") {
                Stepper(
                    "Pause the timer after \(Format.duration(store.settings.smartPause.idlePauseSeconds)) idle",
                    value: store.binding(\.smartPause.idlePauseSeconds),
                    in: 30...900, step: 30
                )
                Stepper(
                    "Hold an imminent break while typing (last \(store.settings.smartPause.deferWhileTypingSeconds) sec)",
                    value: store.binding(\.smartPause.deferWhileTypingSeconds),
                    in: 0...10
                )
            }
        }
        .formStyle(.grouped)
    }

    private func appName(for bundleID: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return bundleID
        }
        return FileManager.default.displayName(atPath: url.path)
    }

    private func pickApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        let newIDs = panel.urls.compactMap { Bundle(url: $0)?.bundleIdentifier }
        store.update { settings in
            for id in newIDs where !settings.smartPause.focusAppBundleIDs.contains(id) {
                settings.smartPause.focusAppBundleIDs.append(id)
            }
        }
    }
}

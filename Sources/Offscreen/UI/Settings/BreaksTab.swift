import SwiftUI

struct BreaksTab: View {
    let store: SettingsStore

    private var timing: TimingConfig { store.settings.timing }

    var body: some View {
        Form {
            Section {
                Picker("Preset", selection: Binding(
                    get: { timing.presetName },
                    set: { name in
                        if let preset = TimingConfig.presets.first(where: { $0.name == name }) {
                            store.update { $0.timing = preset.config }
                        }
                    }
                )) {
                    ForEach(TimingConfig.presets, id: \.name) { preset in
                        Text(preset.name).tag(preset.name)
                    }
                    if timing.presetName == "Custom" {
                        Text("Custom").tag("Custom")
                    }
                }
            }

            Section("Short breaks") {
                Stepper(
                    "Work for \(Format.duration(timing.workSeconds))",
                    value: minutesBinding(\.timing.workSeconds), in: 1...180
                )
                Stepper(
                    "Break for \(Format.duration(timing.shortBreakSeconds))",
                    value: store.binding(\.timing.shortBreakSeconds), in: 5...600, step: 5
                )
            }

            Section("Long breaks") {
                Stepper(
                    timing.longBreakEvery == 0
                        ? "Long breaks off"
                        : "Every \(ordinal(timing.longBreakEvery)) break is long",
                    value: store.binding(\.timing.longBreakEvery), in: 0...10
                )
                if timing.longBreakEvery > 0 {
                    Stepper(
                        "Long break for \(Format.duration(timing.longBreakSeconds))",
                        value: minutesBinding(\.timing.longBreakSeconds), in: 1...60
                    )
                }
            }

            Section("Notifications") {
                Stepper(
                    "Heads-up \(Format.duration(timing.leadTimeSeconds)) before",
                    value: store.binding(\.timing.leadTimeSeconds), in: 0...300, step: 15
                )
                Stepper(
                    "Snooze limit: \(timing.snoozeLimitPerCycle) per cycle",
                    value: store.binding(\.timing.snoozeLimitPerCycle), in: 0...10
                )
            }
        }
        .formStyle(.grouped)
    }

    /// Steps a seconds-valued field in whole minutes.
    private func minutesBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Int> {
        Binding(
            get: { store.settings[keyPath: keyPath] / 60 },
            set: { minutes in store.update { $0[keyPath: keyPath] = minutes * 60 } }
        )
    }

    private func ordinal(_ n: Int) -> String {
        switch n {
        case 1: "1st"
        case 2: "2nd"
        case 3: "3rd"
        default: "\(n)th"
        }
    }
}

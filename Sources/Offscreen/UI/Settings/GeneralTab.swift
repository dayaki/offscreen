import SwiftUI

struct GeneralTab: View {
    let store: SettingsStore
    let login: LoginItemManager

    @State private var launchAtLogin = false
    @State private var loginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        guard on != login.isEnabled else { return }
                        loginError = login.setEnabled(on)
                        launchAtLogin = login.isEnabled
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Toggle("Show countdown in menu bar", isOn: store.binding(\.showCountdownInMenuBar))
                Toggle("Track usage stats (stored locally)", isOn: store.binding(\.statsEnabled))
            }

            Section("Break enforcement") {
                Picker("Skip difficulty", selection: store.binding(\.behavior.difficulty)) {
                    ForEach(DifficultyMode.allCases, id: \.self) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch store.settings.behavior.difficulty {
                case .casual:
                    difficultyCaption("Breaks can be skipped at any time.")
                case .balanced:
                    Stepper(
                        "Skip unlocks after \(store.settings.behavior.skipEnableDelaySeconds) sec",
                        value: store.binding(\.behavior.skipEnableDelaySeconds), in: 1...60
                    )
                    difficultyCaption("The skip button enables a few seconds into each break.")
                case .hardcore:
                    difficultyCaption("No skipping — breaks always run to completion.")
                }

                Toggle("Allow ending breaks early", isOn: Binding(
                    get: { store.settings.behavior.endEarlyMinimumSeconds != nil },
                    set: { on in store.update { $0.behavior.endEarlyMinimumSeconds = on ? 10 : nil } }
                ))
                if let minimum = store.settings.behavior.endEarlyMinimumSeconds {
                    Stepper(
                        "…after at least \(minimum) sec",
                        value: Binding(
                            get: { minimum },
                            set: { v in store.update { $0.behavior.endEarlyMinimumSeconds = v } }
                        ), in: 5...300, step: 5
                    )
                }
            }

            Section("Before a break") {
                Stepper(
                    "Cursor countdown for last \(store.settings.behavior.cursorPillSeconds) sec",
                    value: store.binding(\.behavior.cursorPillSeconds), in: 0...60, step: 5
                )
                Toggle("Lock screen when a break starts", isOn: store.binding(\.behavior.autoLockOnBreakStart))
            }
        }
        .formStyle(.grouped)
        .onAppear { launchAtLogin = login.isEnabled }
    }

    private func difficultyCaption(_ text: String) -> some View {
        Text(text).font(.caption).foregroundStyle(.secondary)
    }
}

import SwiftUI

struct ScheduleTab: View {
    let store: SettingsStore

    var body: some View {
        Form {
            Section("Office hours") {
                Toggle("Only remind during office hours", isOn: store.binding(\.officeHours.enabled))
                if store.settings.officeHours.enabled {
                    minuteOfDayPicker("From", store.binding(\.officeHours.startMinute))
                    minuteOfDayPicker("Until", store.binding(\.officeHours.endMinute))
                    WeekdayPicker(selection: store.binding(\.officeHours.weekdays))
                }
            }

            Section {
                ForEach(store.settings.plannedBreaks) { plannedBreak in
                    PlannedBreakRow(store: store, plannedBreak: plannedBreak)
                }
                Button("Add Planned Break…") {
                    store.update { $0.plannedBreaks.append(PlannedBreak()) }
                }
            } header: {
                Text("Planned breaks")
            } footer: {
                Text("Named breaks at a fixed time — a lunch pause, an afternoon walk. They use the same heads-up notice and Smart Pause holds as regular breaks.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func minuteOfDayPicker(_ label: String, _ minutes: Binding<Int>) -> some View {
        DatePicker(
            label,
            selection: Binding(
                get: {
                    Calendar.current.date(
                        bySettingHour: minutes.wrappedValue / 60,
                        minute: minutes.wrappedValue % 60, second: 0, of: Date()
                    ) ?? Date()
                },
                set: { date in
                    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                    minutes.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
                }
            ),
            displayedComponents: .hourAndMinute
        )
    }
}

private struct PlannedBreakRow: View {
    let store: SettingsStore
    let plannedBreak: PlannedBreak

    /// Binding into this row's element in the settings array (by id).
    private func field<T: Equatable>(_ keyPath: WritableKeyPath<PlannedBreak, T>) -> Binding<T> {
        Binding(
            get: {
                store.settings.plannedBreaks.first { $0.id == plannedBreak.id }?[keyPath: keyPath]
                    ?? plannedBreak[keyPath: keyPath]
            },
            set: { newValue in
                store.update { settings in
                    guard let index = settings.plannedBreaks.firstIndex(where: { $0.id == plannedBreak.id })
                    else { return }
                    settings.plannedBreaks[index][keyPath: keyPath] = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: field(\.enabled)).labelsHidden()
                TextField("Name", text: field(\.name)).frame(maxWidth: 140)
                DatePicker(
                    "",
                    selection: Binding(
                        get: {
                            Calendar.current.date(
                                bySettingHour: plannedBreak.hour, minute: plannedBreak.minute,
                                second: 0, of: Date()
                            ) ?? Date()
                        },
                        set: { date in
                            let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                            store.update { settings in
                                guard let index = settings.plannedBreaks.firstIndex(where: { $0.id == plannedBreak.id })
                                else { return }
                                settings.plannedBreaks[index].hour = c.hour ?? 12
                                settings.plannedBreaks[index].minute = c.minute ?? 0
                            }
                        }
                    ),
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                Stepper(
                    "for \(Format.duration(plannedBreak.durationSeconds))",
                    value: Binding(
                        get: { plannedBreak.durationSeconds / 60 },
                        set: { minutes in
                            store.update { settings in
                                guard let index = settings.plannedBreaks.firstIndex(where: { $0.id == plannedBreak.id })
                                else { return }
                                settings.plannedBreaks[index].durationSeconds = minutes * 60
                            }
                        }
                    ),
                    in: 1...240
                )
                Spacer()
                Button(role: .destructive) {
                    store.update { $0.plannedBreaks.removeAll { $0.id == plannedBreak.id } }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
            }
            WeekdayPicker(selection: field(\.weekdays))
        }
        .padding(.vertical, 2)
    }
}

struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    private static let symbols = ["S", "M", "T", "W", "T", "F", "S"] // weekday 1...7

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...7, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button(Self.symbols[weekday - 1]) {
                    if isOn { selection.remove(weekday) } else { selection.insert(weekday) }
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .frame(width: 24, height: 24)
                .background(isOn ? Color.accentColor : Color.primary.opacity(0.08), in: Circle())
                .foregroundStyle(isOn ? .white : .primary)
            }
        }
    }
}

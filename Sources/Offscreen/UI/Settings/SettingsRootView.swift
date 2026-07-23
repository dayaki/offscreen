import SwiftUI

enum SettingsSection: String, CaseIterable, Identifiable {
    case general, breaks, smartPause, schedule, appearance, about

    var id: String { rawValue }

    var label: String {
        switch self {
        case .general: "General"
        case .breaks: "Breaks"
        case .smartPause: "Smart Pause"
        case .schedule: "Schedule"
        case .appearance: "Appearance"
        case .about: "About"
        }
    }

    var icon: String {
        switch self {
        case .general: "gearshape.fill"
        case .breaks: "timer"
        case .smartPause: "pause.circle.fill"
        case .schedule: "calendar"
        case .appearance: "paintbrush.fill"
        case .about: "info.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .general: .gray
        case .breaks: Theme.amber
        case .smartPause: Theme.rose
        case .schedule: Theme.violet
        case .appearance: Theme.plum
        case .about: .secondary
        }
    }
}

/// Sidebar-navigation settings window (System Settings-style, in the spirit
/// of Lookaway's sectioned preferences).
struct SettingsRootView: View {
    let store: SettingsStore
    let login: LoginItemManager

    @State private var selection: SettingsSection = .general

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
        .frame(width: 780, height: 540)
        .tint(Theme.violet)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Image(systemName: "eyes")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.brandGradient)
                Text("Offscreen")
                    .font(.title3.weight(.semibold))
            }
            .padding(.horizontal, 14)
            .padding(.top, 40) // clears the traffic lights
            .padding(.bottom, 14)

            ForEach(SettingsSection.allCases) { section in
                sidebarRow(section)
            }
            Spacer()
        }
        .frame(width: 195)
        .background(.thinMaterial)
    }

    private func sidebarRow(_ section: SettingsSection) -> some View {
        let isSelected = selection == section
        return Button {
            selection = section
        } label: {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(section.tint.gradient, in: RoundedRectangle(cornerRadius: 6))
                Text(section.label)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear),
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(selection.label)
                .font(.title2.weight(.semibold))
                .padding(.horizontal, 22)
                .padding(.top, 34)
                .padding(.bottom, 4)

            Group {
                switch selection {
                case .general: GeneralTab(store: store, login: login)
                case .breaks: BreaksTab(store: store)
                case .smartPause: SmartPauseTab(store: store)
                case .schedule: ScheduleTab(store: store)
                case .appearance: AppearanceTab(store: store)
                case .about: AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "eyes")
                .font(.system(size: 44))
                .foregroundStyle(Theme.brandGradient)
            Text("Offscreen")
                .font(.title2.weight(.semibold))
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                .foregroundStyle(.secondary)
            Text("Smart screen breaks for healthier eyes.\nBuilt for personal use.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.callout)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

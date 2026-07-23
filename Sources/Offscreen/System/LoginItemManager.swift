import ServiceManagement

/// Launch-at-login via SMAppService. Only meaningful when running from the
/// installed bundle (~/Applications/Offscreen.app), not a bare dev binary.
final class LoginItemManager {
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: "Enabled"
        case .requiresApproval: "Waiting for approval in System Settings"
        case .notRegistered: "Off"
        case .notFound: "App bundle not found by launchd"
        @unknown default: "Unknown"
        }
    }

    func setEnabled(_ enabled: Bool) -> String? {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return nil
        } catch {
            Log.app.error("login item toggle failed: \(error, privacy: .public)")
            return error.localizedDescription
        }
    }
}

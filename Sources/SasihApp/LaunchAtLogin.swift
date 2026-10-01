import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns the actual resulting state so callers can resync UI that
    /// mirrors it — `register()`/`unregister()` can silently fail (e.g. login
    /// items restricted by MDM, or an approval-required state), and a toggle
    /// bound to its own local state rather than this truth would otherwise
    /// show whatever the user clicked regardless of whether it took effect.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            // Non-fatal — the core display-safety behavior of the app does
            // not depend on this. The caller resyncs its UI to `isEnabled`.
        }
        return isEnabled
    }
}

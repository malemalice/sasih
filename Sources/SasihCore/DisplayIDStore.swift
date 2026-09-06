import CoreGraphics
import Foundation

/// Persists the internal display's ID and the "is it currently disabled" flag,
/// so both survive a process crash/force-quit — that's the only way to know,
/// on next launch, whether the display needs to be restored before any UI shows.
public protocol DisplayIDPersisting {
    func save(_ id: CGDirectDisplayID)
    func load() -> CGDirectDisplayID?
    func saveOffState(_ isOff: Bool)
    func loadOffState() -> Bool
    func saveAutoRevertOnReconnect(_ enabled: Bool)
    func loadAutoRevertOnReconnect() -> Bool
}

/// Real implementation: UserDefaults as the primary store, with a plain-text
/// backup file as a fallback in case UserDefaults is ever wiped/unavailable.
public final class DisplayIDStore: DisplayIDPersisting {
    private let defaults: UserDefaults
    private let fileURL: URL
    private let idKey = "BackupInternalDisplayID"
    private let offStateKey = "IsInternalDisplayOff"
    private let autoRevertKey = "AutoRevertInternalOffOnReconnect"

    public init(
        defaults: UserDefaults = .standard,
        fileURL: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".sasih_internal_display_id")
    ) {
        self.defaults = defaults
        self.fileURL = fileURL
    }

    public func save(_ id: CGDirectDisplayID) {
        defaults.set(Int(id), forKey: idKey)
        try? String(id).write(to: fileURL, atomically: true, encoding: .utf8)
    }

    public func load() -> CGDirectDisplayID? {
        if let value = defaults.object(forKey: idKey) as? Int {
            return CGDirectDisplayID(value)
        }
        if let text = try? String(contentsOf: fileURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
            let value = UInt32(text) {
            return CGDirectDisplayID(value)
        }
        return nil
    }

    public func saveOffState(_ isOff: Bool) {
        defaults.set(isOff, forKey: offStateKey)
    }

    public func loadOffState() -> Bool {
        defaults.bool(forKey: offStateKey)
    }

    public func saveAutoRevertOnReconnect(_ enabled: Bool) {
        defaults.set(enabled, forKey: autoRevertKey)
    }

    /// Defaults to `true` (opt-out preference) — most users want the app to
    /// restore their off-state automatically once the external display they
    /// were relying on shows back up.
    public func loadAutoRevertOnReconnect() -> Bool {
        guard defaults.object(forKey: autoRevertKey) != nil else { return true }
        return defaults.bool(forKey: autoRevertKey)
    }
}

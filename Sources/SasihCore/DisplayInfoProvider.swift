import CoreGraphics

/// Queries which displays are currently connected/online, which are drawable,
/// and which is built-in.
public protocol DisplayInfoProviding {
    func onlineDisplayIDs() -> [CGDirectDisplayID]

    /// Displays that are connected, awake, and available for drawing
    /// (`CGGetActiveDisplayList`). Stricter than `onlineDisplayIDs()`: the
    /// online list can retain non-drawable entries (stale/ghost displays,
    /// indirect hardware mirrors), which must never be mistaken for "the user
    /// has a working screen".
    func activeDisplayIDs() -> [CGDirectDisplayID]

    func isBuiltin(_ id: CGDirectDisplayID) -> Bool
}

public extension DisplayInfoProviding {
    func builtinDisplayID() -> CGDirectDisplayID? {
        onlineDisplayIDs().first(where: isBuiltin)
    }

    func externalDisplayCount() -> Int {
        onlineDisplayIDs().filter { !isBuiltin($0) }.count
    }

    /// External displays the user can actually see something on: online *and*
    /// drawable. Every blackout/restore decision uses this, never the raw
    /// online count — a non-drawable entry in the online list otherwise blocks
    /// the emergency restore and lets wake/auto-revert black out the internal
    /// panel with nothing left to fall back to (field incident 2026-09-21).
    func usableExternalDisplayIDs() -> [CGDirectDisplayID] {
        let active = Set(activeDisplayIDs())
        return onlineDisplayIDs().filter { !isBuiltin($0) && active.contains($0) }
    }

    func usableExternalDisplayCount() -> Int {
        usableExternalDisplayIDs().count
    }
}

/// Real implementation via CoreGraphics.
///
/// `onlineDisplayIDs()` uses `CGGetOnlineDisplayList` (connectability), while
/// `activeDisplayIDs()` uses `CGGetActiveDisplayList` (drawability). Online is
/// the superset — it includes hardware mirrors that are not drawable — so it
/// is only used to inspect persisted/disabled panels, never to prove that an
/// external display is present.
public struct CGDisplayInfoProvider: DisplayInfoProviding {
    // When both the internal display (disabled by us) and every external are
    // gone, WindowServer synthesizes its own placeholder display rather than
    // leave the system with zero displays. It reports vendor "unkn" / model
    // "virt" (0x756E6B6E / 0x76697274) and isn't builtin, so left unfiltered
    // it gets counted as "an external is still connected" — permanently
    // blocking the emergency restore from ever seeing a true zero count.
    private static let syntheticVendor: UInt32 = 0x756E_6B6E
    private static let syntheticModel: UInt32 = 0x7669_7274

    public init() {}

    public func onlineDisplayIDs() -> [CGDirectDisplayID] {
        Self.displayList(from: CGGetOnlineDisplayList)
    }

    public func activeDisplayIDs() -> [CGDirectDisplayID] {
        Self.displayList(from: CGGetActiveDisplayList)
    }

    public func isBuiltin(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(id) != 0
    }

    private static func displayList(
        from fetch: (UInt32, UnsafeMutablePointer<CGDirectDisplayID>?, UnsafeMutablePointer<UInt32>?) -> CGError
    ) -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        _ = fetch(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        _ = fetch(count, &ids, &count)
        return ids.filter { !Self.isSyntheticPlaceholder($0) }
    }

    private static func isSyntheticPlaceholder(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == syntheticVendor && CGDisplayModelNumber(id) == syntheticModel
    }
}

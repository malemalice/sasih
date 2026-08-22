import CoreGraphics

/// Queries which displays are currently connected/online, and which is built-in.
public protocol DisplayInfoProviding {
    func onlineDisplayIDs() -> [CGDirectDisplayID]
    func isBuiltin(_ id: CGDirectDisplayID) -> Bool
}

public extension DisplayInfoProviding {
    func builtinDisplayID() -> CGDirectDisplayID? {
        onlineDisplayIDs().first(where: isBuiltin)
    }

    func externalDisplayCount() -> Int {
        onlineDisplayIDs().filter { !isBuiltin($0) }.count
    }
}

/// Real implementation via CoreGraphics.
///
/// Uses CGGetOnlineDisplayList, not CGGetActiveDisplayList: the active list
/// excludes non-primary displays that are currently mirrored, which would
/// hide a connected external monitor entirely while mirroring is on.
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
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids.filter { !Self.isSyntheticPlaceholder($0) }
    }

    public func isBuiltin(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(id) != 0
    }

    private static func isSyntheticPlaceholder(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayVendorNumber(id) == syntheticVendor && CGDisplayModelNumber(id) == syntheticModel
    }
}

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
    public init() {}

    public func onlineDisplayIDs() -> [CGDirectDisplayID] {
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        guard count > 0 else { return [] }
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        return ids
    }

    public func isBuiltin(_ id: CGDirectDisplayID) -> Bool {
        CGDisplayIsBuiltin(id) != 0
    }
}

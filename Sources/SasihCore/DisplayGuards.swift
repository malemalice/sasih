/// Pure safety guards — no I/O, trivially exhaustive to test.
public enum DisplayGuards {
    /// Refuse to disable the internal display unless at least one *usable*
    /// external is present — online and drawable, not merely listed as
    /// connected. A stale/ghost entry in the online display list must never be
    /// treated as a working screen.
    public static func canDisableInternal(usableExternalDisplayCount: Int) -> Bool {
        usableExternalDisplayCount > 0
    }

    /// Never disable the only remaining active display, independent of the
    /// external-count check above (defense in depth).
    public static func isLastActiveDisplay(activeDisplayCount: Int) -> Bool {
        activeDisplayCount <= 1
    }
}

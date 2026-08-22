/// Pure safety guards — no I/O, trivially exhaustive to test.
public enum DisplayGuards {
    /// Refuse to disable the internal display unless at least one external is present.
    public static func canDisableInternal(externalDisplayCount: Int) -> Bool {
        externalDisplayCount > 0
    }

    /// Never disable the only remaining active display, independent of the
    /// external-count check above (defense in depth).
    public static func isLastActiveDisplay(activeDisplayCount: Int) -> Bool {
        activeDisplayCount <= 1
    }
}

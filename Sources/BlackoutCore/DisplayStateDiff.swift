import CoreGraphics

public struct DisplayChange: Equatable {
    public let id: CGDirectDisplayID
    public let enabled: Bool

    public init(id: CGDirectDisplayID, enabled: Bool) {
        self.id = id
        self.enabled = enabled
    }
}

public enum DisplayStateDiff {
    /// Produces the minimal set of changes needed to move `current` to `target`.
    ///
    /// Never emits a change for a display already at its target state — issuing
    /// SLSConfigureDisplayEnabled on an already-disabled display fails the whole
    /// transaction, so this diff must be exact, not just "close enough".
    public static func diff(
        current: [CGDirectDisplayID: Bool],
        target: [CGDirectDisplayID: Bool]
    ) -> [DisplayChange] {
        var changes: [DisplayChange] = []
        for (id, targetEnabled) in target {
            let currentEnabled = current[id] ?? true
            if currentEnabled != targetEnabled {
                changes.append(DisplayChange(id: id, enabled: targetEnabled))
            }
        }
        return changes
    }
}

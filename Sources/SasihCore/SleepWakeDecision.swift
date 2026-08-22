public enum WakeAction: Equatable {
    /// Internal display was off before sleep and an external is still present — turn it off again.
    case reapplyOff
    /// Internal display was off before sleep but no external is present on wake — leave it on.
    case leaveOn
    /// Internal display was already on before sleep — nothing to do.
    case doNothing
}

public enum SleepWakeDecision {
    /// macOS re-enables all displays on wake as part of its own reconfiguration.
    /// This decides whether that needs to be undone.
    public static func wakeAction(wasOffBeforeSleep: Bool, externalPresentOnWake: Bool) -> WakeAction {
        guard wasOffBeforeSleep else { return .doNothing }
        return externalPresentOnWake ? .reapplyOff : .leaveOn
    }
}

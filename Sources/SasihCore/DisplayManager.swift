import CoreGraphics
import os

/// Single source of truth for "is the internal display off." All dependencies
/// are constructor-injected so this class is fully unit-testable with fakes —
/// it never calls dlopen/dlsym or queries real display hardware directly.
public final class DisplayManager {
    private let configurer: DisplayConfiguring
    private let infoProvider: DisplayInfoProviding
    private let idStore: DisplayIDPersisting

    // Diagnostics for the sleep/wake state-loss class of bug: every decision
    // point here is timing-dependent and impossible to reproduce under test,
    // so the unified log is the only way to see what actually happened.
    // Note: every interpolated value needs `privacy: .public` — without it the
    // log redacts them (arrays show up as `<private>`), which makes the output
    // useless for exactly the questions we need answered.
    private let logger = Logger(subsystem: "com.adaptivid.sasih", category: "DisplayManager")

    public private(set) var isInternalDisplayOff: Bool
    public private(set) var lastError: String?

    private var cachedInternalDisplayID: CGDirectDisplayID?

    /// True when the internal display is currently on only because we fell
    /// back to it (no external present when we needed to decide), not because
    /// the user chose it. Drives whether `performEmergencyCheckIfNeeded` may
    /// automatically turn it off again once an external display reappears.
    /// In-memory only — a fresh launch has no fallback to reconcile.
    private var internalOnIsFallback = false

    /// User preference: automatically restore "internal off" once an external
    /// display reconnects after we fell back to the internal display.
    public var autoRevertOnReconnectEnabled: Bool {
        get { idStore.loadAutoRevertOnReconnect() }
        set { idStore.saveAutoRevertOnReconnect(newValue) }
    }

    public init(
        configurer: DisplayConfiguring,
        infoProvider: DisplayInfoProviding,
        idStore: DisplayIDPersisting
    ) {
        self.configurer = configurer
        self.infoProvider = infoProvider
        self.idStore = idStore
        self.cachedInternalDisplayID = idStore.load()
        self.isInternalDisplayOff = idStore.loadOffState()
        logger.notice("init: cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public) isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public)")
    }

    public var externalDisplayCount: Int {
        infoProvider.externalDisplayCount()
    }

    @discardableResult
    public func disableInternalDisplay() -> Bool {
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let externalCount = onlineIDs.filter { !infoProvider.isBuiltin($0) }.count
        logger.notice("disableInternalDisplay: onlineIDs=\(onlineIDs, privacy: .public) externalCount=\(externalCount, privacy: .public)")

        guard DisplayGuards.canDisableInternal(externalDisplayCount: externalCount) else {
            lastError = "No external display detected."
            logger.notice("disableInternalDisplay: refused — no external display detected")
            return false
        }
        guard !DisplayGuards.isLastActiveDisplay(activeDisplayCount: onlineIDs.count) else {
            lastError = "Refusing to disable the last active display."
            logger.notice("disableInternalDisplay: refused — would be the last active display")
            return false
        }
        guard let internalID = resolveInternalDisplayID(from: onlineIDs) else {
            lastError = "Could not find internal display ID."
            logger.notice("disableInternalDisplay: failed — could not resolve internal display ID")
            return false
        }

        idStore.save(internalID)
        cachedInternalDisplayID = internalID

        guard configurer.setDisplay(internalID, enabled: false) else {
            lastError = "Failed to disable internal display."
            logger.notice("disableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(false) FAILED")
            return false
        }

        isInternalDisplayOff = true
        idStore.saveOffState(true)
        lastError = nil
        logger.notice("disableInternalDisplay: internalID=\(internalID, privacy: .public) disabled successfully")
        return true
    }

    @discardableResult
    public func enableInternalDisplay() -> Bool {
        guard let internalID = cachedInternalDisplayID ?? idStore.load() else {
            lastError = "Internal display ID unknown — cannot restore."
            logger.notice("enableInternalDisplay: failed — internal display ID unknown")
            return false
        }

        guard configurer.setDisplay(internalID, enabled: true) else {
            lastError = "Failed to enable internal display."
            logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(true) FAILED")
            return false
        }

        isInternalDisplayOff = false
        idStore.saveOffState(false)
        lastError = nil
        logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) enabled successfully")
        return true
    }

    public func toggle() {
        logger.notice("toggle: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) (before)")
        // A manual toggle is always a deliberate choice — it overrides
        // whatever fallback state we were tracking.
        internalOnIsFallback = false
        if isInternalDisplayOff {
            enableInternalDisplay()
        } else {
            disableInternalDisplay()
        }
    }

    /// Call periodically (safety-net timer) and on every display-reconfiguration
    /// event. If the internal display is off and no external is present, restore
    /// immediately — this is the top-priority correctness guarantee of the app.
    /// Also the counterpart reconciliation: if the internal display is only on
    /// because we fell back to it, and an external has since reappeared, turn
    /// it back off — subject to the user's auto-revert preference.
    ///
    /// Note on the zero-count case: an empty online list is the *intended*
    /// signature of a genuine unplug (see CGDisplayInfoProvider — WindowServer
    /// leaves only a synthetic placeholder, which is filtered out). It can also
    /// occur transiently mid-reconfiguration, so the logging below records the
    /// count that drove the decision.
    public func performEmergencyCheckIfNeeded() {
        // One snapshot, so the logged list and the count that drives the
        // decision below can never disagree about which instant they describe.
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let externalCount = onlineIDs.filter { !infoProvider.isBuiltin($0) }.count
        logger.notice("performEmergencyCheckIfNeeded: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) internalOnIsFallback=\(self.internalOnIsFallback, privacy: .public) onlineIDs=\(onlineIDs, privacy: .public) externalCount=\(externalCount, privacy: .public) cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public)")

        if isInternalDisplayOff {
            guard externalCount == 0 else {
                logger.notice("performEmergencyCheckIfNeeded: external present — nothing to do")
                return
            }
            logger.notice("performEmergencyCheckIfNeeded: no external present — restoring internal")
            internalOnIsFallback = true
            enableInternalDisplay()
            return
        }

        guard internalOnIsFallback, autoRevertOnReconnectEnabled, externalCount > 0 else { return }
        logger.notice("performEmergencyCheckIfNeeded: external reconnected after fallback — reapplying off")
        if disableInternalDisplay() {
            internalOnIsFallback = false
        }
    }

    /// Call on wake from sleep. Reads the persisted off-state rather than a
    /// caller-supplied snapshot, since disable/enable already keep that state
    /// current at all times.
    public func handleWake() {
        let wasOff = idStore.loadOffState()
        let externalPresent = externalDisplayCount > 0
        let action = SleepWakeDecision.wakeAction(wasOffBeforeSleep: wasOff, externalPresentOnWake: externalPresent)
        logger.notice("handleWake: wasOff=\(wasOff, privacy: .public) externalPresent=\(externalPresent, privacy: .public) action=\(String(describing: action), privacy: .public)")
        switch action {
        case .reapplyOff:
            disableInternalDisplay()
        case .leaveOn:
            isInternalDisplayOff = false
            idStore.saveOffState(false)
            internalOnIsFallback = true
        case .doNothing:
            break
        }
    }

    /// Call once at app startup, before any UI is shown. Recovers from a
    /// crash/force-quit that left the internal display off in a previous session.
    public func restoreOnLaunchIfNeeded() {
        guard idStore.loadOffState() else { return }
        logger.notice("restoreOnLaunchIfNeeded: previous session left internal off — restoring")
        cachedInternalDisplayID = idStore.load()
        enableInternalDisplay()
    }

    /// Call before the app quits normally — never leave the internal display off.
    public func restoreBeforeQuit() {
        guard isInternalDisplayOff else { return }
        logger.notice("restoreBeforeQuit: restoring internal display before quit")
        enableInternalDisplay()
    }

    private func resolveInternalDisplayID(from onlineIDs: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        onlineIDs.first(where: infoProvider.isBuiltin) ?? cachedInternalDisplayID
    }
}

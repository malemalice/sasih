import CoreGraphics
import Foundation
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

    /// True while a blackout is waiting for a mirrored external to become a
    /// separate, drawable display (we asked macOS to stop mirroring). The
    /// blackout itself is only applied once that external is actually usable,
    /// through the normal guarded disable path. In-memory only.
    public private(set) var isBlackoutPendingUnmirror = false
    private var unmirrorDeadline: TimeInterval?
    /// Monotonic seconds (system uptime), so wall-clock changes can't skew
    /// the un-mirroring timeout.
    private let now: () -> TimeInterval

    /// How long to wait for macOS to finish un-mirroring before giving up.
    static let unmirrorTimeout: TimeInterval = 15

    /// Externals we took out of mirroring to apply a blackout. When the user
    /// turns Blackout off, they are mirrored back onto the built-in display so
    /// the setup returns to how they had it. Only an un-mirror *we* did is
    /// ever undone. In-memory only (mirroring was changed `.forSession`).
    private var displaysToRemirror: [CGDirectDisplayID] = []
    private var remirrorDeadline: TimeInterval?

    /// How long to wait for the built-in display to come back before giving
    /// up on re-mirroring (the screens then simply stay extended).
    static let remirrorTimeout: TimeInterval = 15

    /// User preference: automatically restore "internal off" once an external
    /// display reconnects after we fell back to the internal display.
    public var autoRevertOnReconnectEnabled: Bool {
        get { idStore.loadAutoRevertOnReconnect() }
        set { idStore.saveAutoRevertOnReconnect(newValue) }
    }

    public init(
        configurer: DisplayConfiguring,
        infoProvider: DisplayInfoProviding,
        idStore: DisplayIDPersisting,
        now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.configurer = configurer
        self.infoProvider = infoProvider
        self.idStore = idStore
        self.now = now
        self.cachedInternalDisplayID = idStore.load()
        self.isInternalDisplayOff = idStore.loadOffState()
        logger.notice("init: cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public) isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public)")
    }

    public var externalDisplayCount: Int {
        infoProvider.externalDisplayCount()
    }

    /// Externals the user can actually see: online *and* drawable. This is the
    /// predicate every blackout/restore decision uses (see
    /// `DisplayInfoProviding.usableExternalDisplayCount`).
    public var usableExternalDisplayCount: Int {
        infoProvider.usableExternalDisplayCount()
    }

    /// Externals that are only mirroring the built-in display. Blackout can
    /// still be turned on with one of these: it stops mirroring first.
    public var mirroredExternalDisplayCount: Int {
        infoProvider.mirroredExternalDisplayIDs().count
    }

    @discardableResult
    public func disableInternalDisplay() -> Bool {
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let activeIDs = infoProvider.activeDisplayIDs()
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        logger.notice("disableInternalDisplay: onlineIDs=\(onlineIDs, privacy: .public) activeIDs=\(activeIDs, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public)")

        // Already off — e.g. macOS dropped the panel across a sleep/wake, or a
        // previous session left it off. Never issue a hardware call for a
        // display that isn't online; just make the recorded state agree.
        guard isInternalDisplayOnline(in: onlineIDs) else {
            isInternalDisplayOff = true
            idStore.saveOffState(true)
            lastError = nil
            logger.notice("disableInternalDisplay: internal display already offline — recording off state")
            return true
        }

        guard DisplayGuards.canDisableInternal(usableExternalDisplayCount: usableExternalCount) else {
            // A mirrored external is a real screen, just not a drawable one
            // yet. Stop mirroring (both screens stay on) and let the emergency
            // check apply the blackout once it is usable — never before.
            let mirroredIDs = infoProvider.mirroredExternalDisplayIDs()
            if !mirroredIDs.isEmpty {
                if configurer.stopMirroring(mirroredIDs) {
                    displaysToRemirror = mirroredIDs
                    isBlackoutPendingUnmirror = true
                    unmirrorDeadline = now() + Self.unmirrorTimeout
                    lastError = nil
                    logger.notice("disableInternalDisplay: external mirrored (mirroredIDs=\(mirroredIDs, privacy: .public)) — stopped mirroring, blackout pending")
                } else {
                    lastError = "Couldn't stop screen mirroring. Turn off Mirror in System Settings → Displays."
                    logger.notice("disableInternalDisplay: stopMirroring FAILED mirroredIDs=\(mirroredIDs, privacy: .public)")
                }
                return false
            }
            lastError = "No external display detected."
            logger.notice("disableInternalDisplay: refused — no drawable external display (onlineIDs=\(onlineIDs, privacy: .public) activeIDs=\(activeIDs, privacy: .public))")
            return false
        }
        guard !DisplayGuards.isLastActiveDisplay(activeDisplayCount: activeIDs.count) else {
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
        // Deliberately no "already online → skip" shortcut here: the online
        // list can retain a ghost/non-drawable builtin entry, and trusting it
        // would silently skip a real restore and leave the panel dark. Always
        // attempt the enable and reconcile with reality only if it fails.
        guard let internalID = cachedInternalDisplayID ?? idStore.load() else {
            lastError = "Internal display ID unknown — cannot restore."
            logger.notice("enableInternalDisplay: failed — internal display ID unknown")
            return false
        }

        guard configurer.setDisplay(internalID, enabled: true) else {
            // SkyLight fails a transaction for a display already in the target
            // state. That used to strand a persisted off-state forever after a
            // reboot (the reboot restores the panel, UserDefaults does not), so
            // every launch/retry surfaced "Failed to enable internal display."
            // for a panel that was visibly on. The panel can also come back
            // concurrently (macOS reconfigures asynchronously). Either way,
            // re-read reality before declaring failure.
            let onlineAfterFailure = infoProvider.onlineDisplayIDs()
            if let liveInternalID = builtinDisplayID(in: onlineAfterFailure) {
                recordEnabledState(liveInternalID)
                logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(true) failed but panel is online — recorded on state")
                return true
            }
            lastError = "Failed to enable internal display."
            logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) setDisplay(true) FAILED onlineIDs=\(onlineAfterFailure, privacy: .public)")
            return false
        }

        recordEnabledState(internalID)
        logger.notice("enableInternalDisplay: internalID=\(internalID, privacy: .public) enabled successfully")
        return true
    }

    public func toggle() {
        logger.notice("toggle: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) isBlackoutPendingUnmirror=\(self.isBlackoutPendingUnmirror, privacy: .public) (before)")
        // A manual toggle is always a deliberate choice — it overrides
        // whatever fallback state we were tracking.
        internalOnIsFallback = false
        // Toggling while a blackout is pending means "never mind": put the
        // mirroring back as it was.
        if isBlackoutPendingUnmirror {
            clearPendingUnmirror()
            scheduleRemirror()
            return
        }
        if isInternalDisplayOff {
            if enableInternalDisplay() {
                scheduleRemirror()
            }
        } else {
            disableInternalDisplay()
        }
    }

    /// Call periodically (safety-net timer) and on every display-reconfiguration
    /// event. If the internal display is off and no *drawable* external is
    /// present, restore immediately — this is the top-priority correctness
    /// guarantee of the app. Also the counterpart reconciliation: if the
    /// internal display is only on because we fell back to it, and a drawable
    /// external has since reappeared, turn it back off — subject to the user's
    /// auto-revert preference.
    ///
    /// `screensAreAsleep` must be true while macOS has the screens in display
    /// sleep: then *no* display is drawable (including a perfectly healthy
    /// external), and acting on that snapshot would cancel blackout on every
    /// display-sleep cycle. AppDelegate tracks it via the screensDidSleep/Wake
    /// notifications and re-runs this check right after the screens wake.
    ///
    /// Note on the zero-count case: an empty online list is the *intended*
    /// signature of a genuine unplug (see CGDisplayInfoProvider — WindowServer
    /// leaves only a synthetic placeholder, which is filtered out). It can also
    /// occur transiently mid-reconfiguration, so the logging below records the
    /// lists that drove the decision.
    public func performEmergencyCheckIfNeeded(screensAreAsleep: Bool = false) {
        // One snapshot, so the logged lists and the counts that drive the
        // decision below can never disagree about which instant they describe.
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        logger.notice("performEmergencyCheckIfNeeded: isInternalDisplayOff=\(self.isInternalDisplayOff, privacy: .public) internalOnIsFallback=\(self.internalOnIsFallback, privacy: .public) screensAreAsleep=\(screensAreAsleep, privacy: .public) onlineIDs=\(onlineIDs, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public) cachedInternalDisplayID=\(String(describing: self.cachedInternalDisplayID), privacy: .public)")

        guard !screensAreAsleep else {
            logger.notice("performEmergencyCheckIfNeeded: screens asleep — deferring (no state change)")
            return
        }

        if isBlackoutPendingUnmirror {
            if usableExternalCount > 0 {
                clearPendingUnmirror()
                logger.notice("performEmergencyCheckIfNeeded: mirrored external is now drawable — applying pending blackout")
                // Every disable guard re-runs here; nothing is bypassed.
                if disableInternalDisplay() {
                    internalOnIsFallback = false
                }
            } else if let deadline = unmirrorDeadline, now() >= deadline {
                clearPendingUnmirror()
                clearRemirror()
                lastError = "Couldn't stop screen mirroring. Turn off Mirror in System Settings → Displays."
                logger.notice("performEmergencyCheckIfNeeded: pending blackout timed out — external never became drawable")
            } else if isInternalDisplayOnline(in: onlineIDs) {
                // Waiting is only safe while the panel is visibly on; otherwise
                // fall through to the normal restore logic below.
                logger.notice("performEmergencyCheckIfNeeded: blackout pending — waiting for the external to finish un-mirroring")
                return
            }
        }

        if remirrorDeadline != nil {
            remirrorIfReady()
        }

        // The panel being absent from the online list is ground truth that it
        // is off. Record that instead of trusting the recorded on-state: the
        // reapply-off below would otherwise call disableInternalDisplay() for
        // an already-off panel, the last-active-display guard would refuse it
        // forever, and the fallback flag would never clear. A drawable external
        // outside the fallback window is still ignored, since the online list
        // can transiently omit the panel mid-reconfiguration — but a merely
        // listed (non-drawable) external must not hold the recorded state on.
        if !isInternalDisplayOnline(in: onlineIDs), !isInternalDisplayOff,
           (usableExternalCount == 0 || internalOnIsFallback) {
            logger.notice("performEmergencyCheckIfNeeded: panel offline while state said on — reconciling to off")
            isInternalDisplayOff = true
            idStore.saveOffState(true)
            internalOnIsFallback = false
        }

        if isInternalDisplayOff {
            guard usableExternalCount == 0 else {
                logger.notice("performEmergencyCheckIfNeeded: drawable external present — nothing to do")
                return
            }
            logger.notice("performEmergencyCheckIfNeeded: no drawable external present — restoring internal")
            // The external we un-mirrored is gone; nothing to mirror back to.
            clearRemirror()
            internalOnIsFallback = true
            enableInternalDisplay()
            return
        }

        // A reconnected external that macOS put back into mirroring counts too:
        // the disable path stops mirroring first and applies blackout once the
        // external is drawable.
        let externalReconnected = usableExternalCount > 0 || !infoProvider.mirroredExternalDisplayIDs().isEmpty
        guard internalOnIsFallback, autoRevertOnReconnectEnabled, externalReconnected else { return }
        logger.notice("performEmergencyCheckIfNeeded: drawable external reconnected after fallback — reapplying off")
        if disableInternalDisplay() {
            internalOnIsFallback = false
        }
    }

    /// Call on wake from sleep. Reads the persisted off-state rather than a
    /// caller-supplied snapshot, since disable/enable already keep that state
    /// current at all times.
    public func handleWake() {
        let wasOff = idStore.loadOffState()
        // A drawable external is required to re-apply blackout: a stale/ghost
        // entry in the online list must not black out the panel macOS just
        // restored. If the external enumerates late, this falls back to
        // `leaveOn` and auto-revert re-applies once it is actually drawable.
        let usableExternalCount = infoProvider.usableExternalDisplayCount()
        let externalPresent = usableExternalCount > 0
        let action = SleepWakeDecision.wakeAction(wasOffBeforeSleep: wasOff, externalPresentOnWake: externalPresent)
        logger.notice("handleWake: wasOff=\(wasOff, privacy: .public) usableExternalCount=\(usableExternalCount, privacy: .public) externalPresent=\(externalPresent, privacy: .public) action=\(String(describing: action), privacy: .public)")
        switch action {
        case .reapplyOff:
            disableInternalDisplay()
        case .leaveOn:
            // Not a user "Blackout off": don't re-mirror behind their back.
            clearRemirror()
            internalOnIsFallback = true
            if isInternalDisplayOnline(in: infoProvider.onlineDisplayIDs()) {
                isInternalDisplayOff = false
                idStore.saveOffState(false)
            } else {
                // macOS re-enables displays as part of wake, but not always
                // reliably — the exact state-loss case this app exists for.
                // Restore it ourselves; if that fails, leave the off-state
                // recorded so the emergency check and launch restore keep
                // retrying rather than trusting an assumption.
                logger.notice("handleWake: macOS did not restore the internal display — restoring explicitly")
                enableInternalDisplay()
            }
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

    private func clearPendingUnmirror() {
        isBlackoutPendingUnmirror = false
        unmirrorDeadline = nil
    }

    /// Arms the re-mirror (if we un-mirrored anything) and tries it at once;
    /// the emergency check retries until the built-in display is drawable.
    private func scheduleRemirror() {
        guard !displaysToRemirror.isEmpty else { return }
        remirrorDeadline = now() + Self.remirrorTimeout
        remirrorIfReady()
    }

    /// Re-mirrors only once the built-in display is back on and drawable and
    /// the externals are still connected — mirroring never turns a screen off,
    /// so a failure or timeout just leaves the screens extended.
    private func remirrorIfReady() {
        guard !isInternalDisplayOff, !isBlackoutPendingUnmirror else {
            clearRemirror()
            return
        }
        let activeIDs = infoProvider.activeDisplayIDs()
        guard let builtinID = activeIDs.first(where: infoProvider.isBuiltin) else {
            expireRemirrorIfDue()
            return
        }
        let ids = displaysToRemirror.filter(activeIDs.contains)
        guard !ids.isEmpty else {
            expireRemirrorIfDue()
            return
        }
        if configurer.startMirroring(ids, of: builtinID) {
            logger.notice("remirror: mirrored \(ids, privacy: .public) back onto builtin \(builtinID, privacy: .public)")
            clearRemirror()
        } else {
            logger.notice("remirror: startMirroring FAILED ids=\(ids, privacy: .public) builtin=\(builtinID, privacy: .public)")
            expireRemirrorIfDue()
        }
    }

    private func expireRemirrorIfDue() {
        guard let deadline = remirrorDeadline, now() >= deadline else { return }
        logger.notice("remirror: gave up — leaving displays extended")
        clearRemirror()
    }

    private func clearRemirror() {
        displaysToRemirror = []
        remirrorDeadline = nil
    }

    private func isInternalDisplayOnline(in onlineIDs: [CGDirectDisplayID]) -> Bool {
        builtinDisplayID(in: onlineIDs) != nil
    }

    private func builtinDisplayID(in onlineIDs: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        onlineIDs.first(where: infoProvider.isBuiltin)
    }

    /// Records "on" consistently across memory, UserDefaults, and the ID cache.
    /// A live builtin is the authoritative ID, so it also refreshes a stale
    /// persisted one (e.g. from an earlier boot topology) that would otherwise
    /// break a later restore.
    private func recordEnabledState(_ id: CGDirectDisplayID) {
        if cachedInternalDisplayID != id {
            cachedInternalDisplayID = id
            idStore.save(id)
        }
        isInternalDisplayOff = false
        idStore.saveOffState(false)
        lastError = nil
    }

    private func resolveInternalDisplayID(from onlineIDs: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        onlineIDs.first(where: infoProvider.isBuiltin) ?? cachedInternalDisplayID
    }
}

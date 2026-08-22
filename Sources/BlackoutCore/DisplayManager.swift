import CoreGraphics

/// Single source of truth for "is the internal display off." All dependencies
/// are constructor-injected so this class is fully unit-testable with fakes —
/// it never calls dlopen/dlsym or queries real display hardware directly.
public final class DisplayManager {
    private let configurer: DisplayConfiguring
    private let infoProvider: DisplayInfoProviding
    private let idStore: DisplayIDPersisting

    public private(set) var isInternalDisplayOff: Bool
    public private(set) var lastError: String?

    private var cachedInternalDisplayID: CGDirectDisplayID?

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
    }

    public var externalDisplayCount: Int {
        infoProvider.externalDisplayCount()
    }

    @discardableResult
    public func disableInternalDisplay() -> Bool {
        let onlineIDs = infoProvider.onlineDisplayIDs()
        let externalCount = onlineIDs.filter { !infoProvider.isBuiltin($0) }.count

        guard DisplayGuards.canDisableInternal(externalDisplayCount: externalCount) else {
            lastError = "No external display detected."
            return false
        }
        guard !DisplayGuards.isLastActiveDisplay(activeDisplayCount: onlineIDs.count) else {
            lastError = "Refusing to disable the last active display."
            return false
        }
        guard let internalID = resolveInternalDisplayID(from: onlineIDs) else {
            lastError = "Could not find internal display ID."
            return false
        }

        idStore.save(internalID)
        cachedInternalDisplayID = internalID

        guard configurer.setDisplay(internalID, enabled: false) else {
            lastError = "Failed to disable internal display."
            return false
        }

        isInternalDisplayOff = true
        idStore.saveOffState(true)
        lastError = nil
        return true
    }

    @discardableResult
    public func enableInternalDisplay() -> Bool {
        guard let internalID = cachedInternalDisplayID ?? idStore.load() else {
            lastError = "Internal display ID unknown — cannot restore."
            return false
        }

        guard configurer.setDisplay(internalID, enabled: true) else {
            lastError = "Failed to enable internal display."
            return false
        }

        isInternalDisplayOff = false
        idStore.saveOffState(false)
        lastError = nil
        return true
    }

    public func toggle() {
        if isInternalDisplayOff {
            enableInternalDisplay()
        } else {
            disableInternalDisplay()
        }
    }

    /// Call periodically (safety-net timer) and on every display-reconfiguration
    /// event. If the internal display is off and no external is present, restore
    /// immediately — this is the top-priority correctness guarantee of the app.
    public func performEmergencyCheckIfNeeded() {
        guard isInternalDisplayOff else { return }
        guard externalDisplayCount == 0 else { return }
        enableInternalDisplay()
    }

    /// Call on wake from sleep. Reads the persisted off-state rather than a
    /// caller-supplied snapshot, since disable/enable already keep that state
    /// current at all times.
    public func handleWake() {
        let wasOff = idStore.loadOffState()
        let externalPresent = externalDisplayCount > 0
        switch SleepWakeDecision.wakeAction(wasOffBeforeSleep: wasOff, externalPresentOnWake: externalPresent) {
        case .reapplyOff:
            disableInternalDisplay()
        case .leaveOn:
            isInternalDisplayOff = false
            idStore.saveOffState(false)
        case .doNothing:
            break
        }
    }

    /// Call once at app startup, before any UI is shown. Recovers from a
    /// crash/force-quit that left the internal display off in a previous session.
    public func restoreOnLaunchIfNeeded() {
        guard idStore.loadOffState() else { return }
        cachedInternalDisplayID = idStore.load()
        enableInternalDisplay()
    }

    /// Call before the app quits normally — never leave the internal display off.
    public func restoreBeforeQuit() {
        guard isInternalDisplayOff else { return }
        enableInternalDisplay()
    }

    private func resolveInternalDisplayID(from onlineIDs: [CGDirectDisplayID]) -> CGDirectDisplayID? {
        onlineIDs.first(where: infoProvider.isBuiltin) ?? cachedInternalDisplayID
    }
}

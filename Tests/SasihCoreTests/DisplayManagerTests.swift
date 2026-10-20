import CoreGraphics
import Testing
@testable import SasihCore

private final class FakeConfigurer: DisplayConfiguring {
    var shouldSucceed = true
    var calls: [(id: CGDirectDisplayID, enabled: Bool)] = []
    var onCall: (() -> Void)?

    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool {
        calls.append((id, enabled))
        onCall?()
        return shouldSucceed
    }

    var stopMirroringSucceeds = true
    var stopMirroringCalls: [[CGDirectDisplayID]] = []

    func stopMirroring(_ ids: [CGDirectDisplayID]) -> Bool {
        stopMirroringCalls.append(ids)
        return stopMirroringSucceeds
    }

    var startMirroringSucceeds = true
    var startMirroringCalls: [(ids: [CGDirectDisplayID], master: CGDirectDisplayID)] = []

    func startMirroring(_ ids: [CGDirectDisplayID], of master: CGDirectDisplayID) -> Bool {
        startMirroringCalls.append((ids, master))
        return startMirroringSucceeds
    }
}

private final class FakeInfoProvider: DisplayInfoProviding {
    var online: [CGDirectDisplayID: Bool] = [:] // id -> isBuiltin

    /// IDs reported as active/drawable. `nil` means "every online display is
    /// drawable", so tests that only configure `online` keep their meaning.
    var active: Set<CGDirectDisplayID>?

    func onlineDisplayIDs() -> [CGDirectDisplayID] { Array(online.keys) }
    func activeDisplayIDs() -> [CGDirectDisplayID] { Array(active ?? Set(online.keys)) }
    func isBuiltin(_ id: CGDirectDisplayID) -> Bool { online[id] ?? false }

    /// Externals reported as hardware-mirroring the builtin.
    var mirrored: [CGDirectDisplayID] = []
    func mirroredExternalDisplayIDs() -> [CGDirectDisplayID] { mirrored }
}

private final class FakeIDStore: DisplayIDPersisting {
    var storedID: CGDirectDisplayID?
    var storedOffState = false
    var storedAutoRevert = true

    func save(_ id: CGDirectDisplayID) { storedID = id }
    func load() -> CGDirectDisplayID? { storedID }
    func saveOffState(_ isOff: Bool) { storedOffState = isOff }
    func loadOffState() -> Bool { storedOffState }
    func saveAutoRevertOnReconnect(_ enabled: Bool) { storedAutoRevert = enabled }
    func loadAutoRevertOnReconnect() -> Bool { storedAutoRevert }
}

final class DisplayManagerTests {
    private let configurer = FakeConfigurer()
    private let infoProvider = FakeInfoProvider()
    private let idStore = FakeIDStore()
    private let manager: DisplayManager
    private var clock: Double = 0

    init() {
        manager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
    }

    /// Builtin 1 on; external 2 online but only mirroring it (not drawable).
    private func makeMirroredManager() -> DisplayManager {
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1]
        infoProvider.mirrored = [2]
        return DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore, now: { self.clock })
    }

    /// What macOS does once mirroring stops: the external becomes drawable.
    private func finishUnmirroring() {
        infoProvider.active = [1, 2]
        infoProvider.mirrored = []
    }

    @Test func disableWithMirroredExternalStopsMirroringAndWaits() {
        let mirroredManager = makeMirroredManager()

        #expect(mirroredManager.disableInternalDisplay() == false)
        #expect(configurer.stopMirroringCalls == [[2]])
        #expect(mirroredManager.isBlackoutPendingUnmirror == true)
        #expect(mirroredManager.lastError == nil)
        // Never black out before the external is actually drawable.
        #expect(configurer.calls.isEmpty)
        #expect(mirroredManager.isInternalDisplayOff == false)
    }

    @Test func pendingBlackoutWaitsWhileExternalIsStillMirrored() {
        let mirroredManager = makeMirroredManager()
        _ = mirroredManager.disableInternalDisplay()

        mirroredManager.performEmergencyCheckIfNeeded()

        #expect(mirroredManager.isBlackoutPendingUnmirror == true)
        #expect(configurer.calls.isEmpty)
        #expect(configurer.stopMirroringCalls.count == 1)
    }

    @Test func pendingBlackoutAppliesOnceExternalIsDrawable() {
        let mirroredManager = makeMirroredManager()
        _ = mirroredManager.disableInternalDisplay()
        finishUnmirroring()

        mirroredManager.performEmergencyCheckIfNeeded()

        #expect(mirroredManager.isBlackoutPendingUnmirror == false)
        #expect(mirroredManager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == false)
    }

    @Test func pendingBlackoutDefersWhileScreensAsleep() {
        let mirroredManager = makeMirroredManager()
        _ = mirroredManager.disableInternalDisplay()
        finishUnmirroring()

        mirroredManager.performEmergencyCheckIfNeeded(screensAreAsleep: true)

        #expect(mirroredManager.isBlackoutPendingUnmirror == true)
        #expect(configurer.calls.isEmpty)
    }

    @Test func pendingBlackoutGivesUpAfterTimeout() {
        let mirroredManager = makeMirroredManager()
        _ = mirroredManager.disableInternalDisplay()

        clock += DisplayManager.unmirrorTimeout + 1
        mirroredManager.performEmergencyCheckIfNeeded()

        #expect(mirroredManager.isBlackoutPendingUnmirror == false)
        #expect(mirroredManager.isInternalDisplayOff == false)
        #expect(mirroredManager.lastError?.hasPrefix("Couldn't stop screen mirroring.") == true)
        #expect(configurer.calls.isEmpty)
    }

    @Test func stopMirroringFailureSurfacesErrorAndLeavesPanelOn() {
        configurer.stopMirroringSucceeds = false
        let mirroredManager = makeMirroredManager()

        #expect(mirroredManager.disableInternalDisplay() == false)
        #expect(mirroredManager.isBlackoutPendingUnmirror == false)
        #expect(mirroredManager.lastError?.hasPrefix("Couldn't stop screen mirroring.") == true)
        #expect(configurer.calls.isEmpty)
    }

    @Test func toggleWhileBlackoutPendingCancelsIt() {
        let mirroredManager = makeMirroredManager()
        mirroredManager.toggle()
        #expect(mirroredManager.isBlackoutPendingUnmirror == true)

        mirroredManager.toggle()
        #expect(mirroredManager.isBlackoutPendingUnmirror == false)

        finishUnmirroring()
        mirroredManager.performEmergencyCheckIfNeeded()
        #expect(mirroredManager.isInternalDisplayOff == false)
        #expect(configurer.calls.isEmpty)
    }

    /// Mirrored → blackout applied (panel offline, external drawable).
    private func makeBlackedOutAfterUnmirror() -> DisplayManager {
        let mirroredManager = makeMirroredManager()
        mirroredManager.toggle()
        finishUnmirroring()
        mirroredManager.performEmergencyCheckIfNeeded()
        // The disabled panel leaves the online list.
        infoProvider.online = [2: false]
        infoProvider.active = [2]
        return mirroredManager
    }

    /// What macOS does once the panel is re-enabled.
    private func panelBack() {
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1, 2]
    }

    @Test func blackoutOffRemirrorsOnceBuiltinIsBack() {
        let blackedOut = makeBlackedOutAfterUnmirror()
        #expect(blackedOut.isInternalDisplayOff == true)

        // The enable lands, but the panel isn't drawable yet: wait.
        configurer.onCall = { self.infoProvider.online = [1: true, 2: false] }
        blackedOut.toggle()
        #expect(blackedOut.isInternalDisplayOff == false)
        #expect(configurer.startMirroringCalls.isEmpty)

        panelBack()
        blackedOut.performEmergencyCheckIfNeeded()
        #expect(configurer.startMirroringCalls.count == 1)
        #expect(configurer.startMirroringCalls.first?.ids == [2])
        #expect(configurer.startMirroringCalls.first?.master == 1)

        // Only once.
        blackedOut.performEmergencyCheckIfNeeded()
        #expect(configurer.startMirroringCalls.count == 1)
    }

    @Test func blackoutOffRemirrorsImmediatelyWhenBuiltinAlreadyDrawable() {
        let blackedOut = makeBlackedOutAfterUnmirror()
        configurer.onCall = { self.panelBack() }

        blackedOut.toggle()

        #expect(configurer.startMirroringCalls.first?.ids == [2])
    }

    @Test func blackoutOffWithoutPriorUnmirrorNeverMirrors() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [2: false]
        configurer.onCall = { self.panelBack() }

        manager.toggle()
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.startMirroringCalls.isEmpty)
    }

    @Test func remirrorGivesUpAfterTimeoutLeavingScreensExtended() {
        let blackedOut = makeBlackedOutAfterUnmirror()
        configurer.onCall = { self.infoProvider.online = [1: true, 2: false] }
        blackedOut.toggle()

        clock += DisplayManager.remirrorTimeout + 1
        blackedOut.performEmergencyCheckIfNeeded()
        panelBack()
        blackedOut.performEmergencyCheckIfNeeded()

        #expect(configurer.startMirroringCalls.isEmpty)
        #expect(blackedOut.isInternalDisplayOff == false)
    }

    @Test func emergencyRestoreAfterUnplugDoesNotRemirror() {
        let blackedOut = makeBlackedOutAfterUnmirror()

        // External unplugged while blacked out → emergency restore.
        infoProvider.online = [:]
        infoProvider.active = []
        blackedOut.performEmergencyCheckIfNeeded()
        #expect(blackedOut.isInternalDisplayOff == false)

        // It comes back later; we must not mirror on our own.
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1, 2]
        blackedOut.autoRevertOnReconnectEnabled = false
        blackedOut.performEmergencyCheckIfNeeded()
        #expect(configurer.startMirroringCalls.isEmpty)
    }

    @Test func cancellingPendingBlackoutRemirrors() {
        let mirroredManager = makeMirroredManager()
        mirroredManager.toggle()
        #expect(mirroredManager.isBlackoutPendingUnmirror == true)

        mirroredManager.toggle() // never mind
        finishUnmirroring()
        mirroredManager.performEmergencyCheckIfNeeded()

        #expect(configurer.calls.isEmpty)
        #expect(configurer.startMirroringCalls.first?.ids == [2])
        #expect(configurer.startMirroringCalls.first?.master == 1)
    }

    @Test func failedRemirrorRetriesThenSucceeds() {
        let blackedOut = makeBlackedOutAfterUnmirror()
        configurer.onCall = { self.panelBack() }
        configurer.startMirroringSucceeds = false
        blackedOut.toggle()
        #expect(configurer.startMirroringCalls.count == 1)

        configurer.startMirroringSucceeds = true
        blackedOut.performEmergencyCheckIfNeeded()
        #expect(configurer.startMirroringCalls.count == 2)

        blackedOut.performEmergencyCheckIfNeeded()
        #expect(configurer.startMirroringCalls.count == 2)
    }

    @Test func autoRevertStopsMirroringWhenExternalReconnectsMirrored() {
        infoProvider.online = [1: true, 2: false]
        let reconnectManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore, now: { self.clock })
        _ = reconnectManager.disableInternalDisplay()

        // External unplugged → fallback restore.
        infoProvider.online = [:]
        reconnectManager.performEmergencyCheckIfNeeded()
        #expect(reconnectManager.isInternalDisplayOff == false)

        // macOS reconnects it in mirror mode.
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1]
        infoProvider.mirrored = [2]
        configurer.calls.removeAll()
        reconnectManager.performEmergencyCheckIfNeeded()
        #expect(configurer.stopMirroringCalls == [[2]])
        #expect(configurer.calls.isEmpty)

        finishUnmirroring()
        reconnectManager.performEmergencyCheckIfNeeded()
        #expect(reconnectManager.isInternalDisplayOff == true)
        #expect(configurer.calls.last?.enabled == false)
    }

    @Test func disableRefusedWithNoExternalDisplay() {
        infoProvider.online = [1: true] // only builtin
        #expect(manager.disableInternalDisplay() == false)
        #expect(manager.lastError == "No external display detected.")
        #expect(configurer.calls.isEmpty)
    }

    @Test func disableSucceedsWithExternalPresent() {
        infoProvider.online = [1: true, 2: false]
        #expect(manager.disableInternalDisplay() == true)
        #expect(manager.isInternalDisplayOff == true)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == false)
        #expect(idStore.storedOffState == true)
    }

    @Test func disableRefusedWhenItWouldBeLastActiveDisplay() {
        infoProvider.online = [1: true] // single active display, even though logically "builtin"
        #expect(manager.disableInternalDisplay() == false)
    }

    @Test func disableWhenPanelAlreadyOfflineRecordsStateWithoutHardwareCall() {
        infoProvider.online = [2: false] // external only; the panel is already off
        #expect(manager.disableInternalDisplay() == true)
        #expect(manager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
        #expect(configurer.calls.isEmpty)
        #expect(manager.lastError == nil)
    }

    @Test func enableRestoresUsingCachedID() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [2: false] // the panel is now absent from the online list
        configurer.calls.removeAll()

        #expect(manager.enableInternalDisplay() == true)
        #expect(manager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func enableWhenPanelAlreadyOnlineHealsAfterRejectedNoOp() {
        // Field scenario: the user rebooted while "off" was persisted. The
        // reboot cleared the WindowServer disable (panel is visibly on) but
        // UserDefaults still says off. SkyLight rejects the no-op enable; the
        // recorded state must still converge instead of erroring forever.
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [1: true]
        configurer.shouldSucceed = false // SkyLight rejects a no-op change

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        #expect(rebootedManager.isInternalDisplayOff == true)

        #expect(rebootedManager.enableInternalDisplay() == true)
        #expect(rebootedManager.isInternalDisplayOff == false)
        #expect(rebootedManager.lastError == nil)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.count == 1)
    }

    @Test func restoreOnLaunchHealsStaleOffStateAfterReboot() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [1: true]
        configurer.shouldSucceed = false

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        rebootedManager.restoreOnLaunchIfNeeded()

        #expect(rebootedManager.isInternalDisplayOff == false)
        #expect(rebootedManager.lastError == nil)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.count == 1)
    }

    @Test func enableRefreshesStaleCachedIDFromOnlineBuiltin() {
        idStore.storedID = 99 // stale ID from an earlier boot topology
        idStore.storedOffState = true
        infoProvider.online = [1: true]
        configurer.shouldSucceed = false

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        #expect(rebootedManager.enableInternalDisplay() == true)

        #expect(idStore.storedID == 1)
        #expect(configurer.calls.map(\.id) == [99])
    }

    @Test func enableStillAttemptsHardwareRestoreWhenOnlineListShowsPanel() {
        // The online list can retain a ghost/non-drawable builtin entry right
        // after a disable. Trusting it would skip the restore and leave the
        // panel dark, so the enable must always reach the hardware.
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()

        #expect(manager.enableInternalDisplay() == true)
        #expect(configurer.calls.count == 1)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func enableTreatsPanelAppearingAfterFailedTransactionAsSuccess() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [:] // panel offline when the attempt starts
        configurer.shouldSucceed = false

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        // macOS restores the panel concurrently with our failed transaction.
        configurer.onCall = { self.infoProvider.online = [1: true] }

        #expect(rebootedManager.enableInternalDisplay() == true)
        #expect(rebootedManager.isInternalDisplayOff == false)
        #expect(rebootedManager.lastError == nil)
        #expect(idStore.storedOffState == false)
    }

    @Test func enableFailureWhenPanelStaysOffSurfacesError() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [:]
        configurer.shouldSucceed = false

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)

        #expect(rebootedManager.enableInternalDisplay() == false)
        #expect(rebootedManager.lastError == "Failed to enable internal display.")
        #expect(rebootedManager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
    }

    @Test func emergencyCheckHealsStateWhenPanelIsAlreadyOn() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [1: true]
        configurer.shouldSucceed = false

        let rebootedManager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        rebootedManager.performEmergencyCheckIfNeeded()

        #expect(rebootedManager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
        #expect(rebootedManager.lastError == nil)
    }

    @Test func emergencyCheckRestoresWhenExternalDisappears() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()

        infoProvider.online = [:] // external unplugged; the panel is already offline
        configurer.calls.removeAll()
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func emergencyCheckDoesNothingWhenAlreadyOn() {
        infoProvider.online = [1: true]
        manager.performEmergencyCheckIfNeeded()
        #expect(configurer.calls.isEmpty)
    }

    @Test func restoreOnLaunchRecoversFromCrash() {
        // Simulate a previous session that crashed while the display was off:
        // the panel is still absent from the online list (the disable lasts
        // until reboot).
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [2: false]

        manager.restoreOnLaunchIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func restoreOnLaunchDoesNothingWhenPreviouslyOn() {
        idStore.storedOffState = false
        manager.restoreOnLaunchIfNeeded()
        #expect(configurer.calls.isEmpty)
    }

    @Test func restoreBeforeQuitRestoresIfOff() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        manager.restoreBeforeQuit()
        #expect(manager.isInternalDisplayOff == false)
    }

    @Test func handleWakeReappliesOffWhenExternalStillPresent() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()

        manager.handleWake()

        #expect(manager.isInternalDisplayOff == true)
        #expect(configurer.calls.last?.enabled == false)
    }

    @Test func handleWakeLeavesOnWhenExternalGone() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true] // external gone by the time we wake

        manager.handleWake()

        #expect(manager.isInternalDisplayOff == false)
    }

    @Test func handleWakeDoesNotTouchHardwareWhenMacOSRestoredPanel() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()
        infoProvider.online = [1: true] // macOS re-enabled the panel itself

        manager.handleWake()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.isEmpty)
    }

    @Test func handleWakeRestoresInternalWhenMacOSDidNot() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()
        infoProvider.online = [:] // no external, and the panel is still offline

        manager.handleWake()

        #expect(manager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func handleWakeKeepsOffRecordedWhenRestoreFails() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()
        configurer.shouldSucceed = false
        infoProvider.online = [:]

        manager.handleWake()

        // The attempt failed — keep recording "off" so the emergency check and
        // launch restore keep retrying instead of claiming the panel is on.
        #expect(manager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func emergencyCheckReconcilesFallbackPanelAlreadyOffline() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true]
        manager.handleWake() // fallback: panel on, flag set
        #expect(manager.isInternalDisplayOff == false)
        configurer.calls.removeAll()

        // External returns, but the panel is physically offline while the
        // recorded state still says "on" — the stuck state from the field logs.
        infoProvider.online = [2: false]
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
        #expect(configurer.calls.isEmpty)

        // And the next tick must not retry a no-op disable forever.
        manager.performEmergencyCheckIfNeeded()
        #expect(configurer.calls.isEmpty)
    }

    @Test func emergencyCheckRestoresPanelWhenStateSaidOnButPanelOffline() {
        // Persisted state claims the panel is on (e.g. written by a pre-fix
        // build), but nothing is online at all — the stranding case.
        idStore.storedID = 1
        idStore.storedOffState = false
        infoProvider.online = [:]

        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func handleWakeLeavesOnFlagsFallbackForReconciliation() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true] // external gone by the time we wake

        manager.handleWake()
        #expect(manager.isInternalDisplayOff == false)

        // External reconnects later — auto-revert should reapply "off".
        infoProvider.online = [1: true, 2: false]
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == true)
        #expect(configurer.calls.last?.enabled == false)
    }

    @Test func reconciliationDoesNothingWhenAutoRevertDisabled() {
        idStore.storedAutoRevert = false
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true]
        manager.handleWake()
        configurer.calls.removeAll()

        infoProvider.online = [1: true, 2: false]
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.isEmpty)
    }

    @Test func reconciliationDoesNothingWhenInternalOnIsNotFallback() {
        // User manually left it on — no fallback flag set — reconnect must
        // not fight a deliberate user choice.
        infoProvider.online = [1: true, 2: false]
        manager.performEmergencyCheckIfNeeded()
        #expect(configurer.calls.isEmpty)
        #expect(manager.isInternalDisplayOff == false)
    }

    @Test func manualToggleClearsFallbackFlag() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true]
        manager.handleWake() // sets fallback flag, leaves internal on

        manager.toggle() // user manually disables again — refused, no external
        infoProvider.online = [1: true, 2: false]
        configurer.calls.removeAll()
        manager.performEmergencyCheckIfNeeded()

        // Flag was cleared by the manual toggle, so reconnect does nothing.
        #expect(configurer.calls.isEmpty)
    }

    @Test func failedConfigureCallSurfacesError() {
        infoProvider.online = [1: true, 2: false]
        configurer.shouldSucceed = false

        #expect(manager.disableInternalDisplay() == false)
        #expect(manager.lastError == "Failed to disable internal display.")
        #expect(manager.isInternalDisplayOff == false)
    }

    // MARK: - Non-drawable (stale/ghost) external entries

    @Test func disableRefusedWhenOnlyListedExternalIsNotDrawable() {
        // WindowServer can keep a stale/ghost entry in the online list while
        // nothing is drawable on it — that must not count as a working screen.
        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1]

        #expect(manager.disableInternalDisplay() == false)
        #expect(manager.lastError == "No external display detected.")
        #expect(configurer.calls.isEmpty)
    }

    @Test func emergencyCheckRestoresWhenOnlyListedExternalIsNotDrawable() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [2: false] // panel off; only a non-drawable external listed
        infoProvider.active = []

        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func emergencyCheckReconcilesDivergedStateWithNonDrawableExternal() {
        // Recorded "on" but the panel is physically offline, and the only
        // listed external is not drawable: this used to be a silent no-op —
        // the shape of the 2026-09-21 field incident.
        idStore.storedID = 1
        idStore.storedOffState = false
        infoProvider.online = [2: false]
        infoProvider.active = []

        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    @Test func autoRevertDoesNotActOnNonDrawableExternal() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        infoProvider.online = [1: true]
        manager.handleWake() // fallback: internal left on, flag set
        configurer.calls.removeAll()

        infoProvider.online = [1: true, 2: false]
        infoProvider.active = [1] // listed but not drawable
        manager.performEmergencyCheckIfNeeded()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.isEmpty)
    }

    @Test func handleWakeLeavesOnWhenExternalIsNotDrawable() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()

        infoProvider.online = [2: false] // external listed but not drawable
        infoProvider.active = []

        manager.handleWake()

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.last?.id == 1)
        #expect(configurer.calls.last?.enabled == true)
    }

    // MARK: - Display sleep

    @Test func emergencyCheckDefersWhileScreensAreAsleep() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()
        configurer.calls.removeAll()

        // Display sleep: the external is still connected but nothing is
        // drawable, including the panel.
        infoProvider.online = [2: false]
        infoProvider.active = []

        manager.performEmergencyCheckIfNeeded(screensAreAsleep: true)

        #expect(manager.isInternalDisplayOff == true)
        #expect(idStore.storedOffState == true)
        #expect(configurer.calls.isEmpty)

        // Screens wake with the external drawable again: blackout is preserved.
        infoProvider.active = [2]
        manager.performEmergencyCheckIfNeeded(screensAreAsleep: false)

        #expect(manager.isInternalDisplayOff == true)
        #expect(configurer.calls.isEmpty)
    }

    @Test func emergencyCheckRestoresAfterScreensWakeWhenExternalIsGone() {
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [2: false] // stale entry only, nothing drawable
        infoProvider.active = []

        manager.performEmergencyCheckIfNeeded(screensAreAsleep: true)
        #expect(configurer.calls.isEmpty) // deferred while asleep

        infoProvider.online = [:]
        manager.performEmergencyCheckIfNeeded(screensAreAsleep: false)

        #expect(manager.isInternalDisplayOff == false)
        #expect(configurer.calls.last?.enabled == true)
    }
}

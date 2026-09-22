import CoreGraphics
import Testing
@testable import SasihCore

private final class FakeConfigurer: DisplayConfiguring {
    var shouldSucceed = true
    var calls: [(id: CGDirectDisplayID, enabled: Bool)] = []

    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool {
        calls.append((id, enabled))
        return shouldSucceed
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

    init() {
        manager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
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
        #expect(manager.enableInternalDisplay() == true)
        #expect(manager.isInternalDisplayOff == false)
        #expect(idStore.storedOffState == false)
    }

    @Test func emergencyCheckRestoresWhenExternalDisappears() {
        infoProvider.online = [1: true, 2: false]
        _ = manager.disableInternalDisplay()

        infoProvider.online = [1: true] // external unplugged
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
        // Simulate a previous session that crashed while the display was off.
        idStore.storedID = 1
        idStore.storedOffState = true
        infoProvider.online = [1: true, 2: false]

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

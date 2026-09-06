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

    func onlineDisplayIDs() -> [CGDirectDisplayID] { Array(online.keys) }
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
}

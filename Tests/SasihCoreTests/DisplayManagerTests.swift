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

    func save(_ id: CGDirectDisplayID) { storedID = id }
    func load() -> CGDirectDisplayID? { storedID }
    func saveOffState(_ isOff: Bool) { storedOffState = isOff }
    func loadOffState() -> Bool { storedOffState }
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

    @Test func failedConfigureCallSurfacesError() {
        infoProvider.online = [1: true, 2: false]
        configurer.shouldSucceed = false

        #expect(manager.disableInternalDisplay() == false)
        #expect(manager.lastError == "Failed to disable internal display.")
        #expect(manager.isInternalDisplayOff == false)
    }
}

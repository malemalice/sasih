import CoreGraphics
import Testing
import SasihCore
@testable import SasihApp

private final class FakeConfigurer: DisplayConfiguring {
    var shouldSucceed = true
    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool { shouldSucceed }
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

private final class FakeTouchBarRecovery: TouchBarRecovering, @unchecked Sendable {
    var nudgeCallCount = 0
    func nudge() { nudgeCallCount += 1 }
}

@MainActor
final class DisplayStateViewModelTests {
    private let configurer = FakeConfigurer()
    private let infoProvider = FakeInfoProvider()
    private let idStore = FakeIDStore()
    private let touchBarRecovery = FakeTouchBarRecovery()

    private func makeViewModel() -> DisplayStateViewModel {
        let manager = DisplayManager(configurer: configurer, infoProvider: infoProvider, idStore: idStore)
        return DisplayStateViewModel(manager: manager, touchBarRecovery: touchBarRecovery)
    }

    @Test func toggleFromOffToOnNudgesTouchBar() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedID = 1
        idStore.storedOffState = true // starts off

        let viewModel = makeViewModel()
        viewModel.toggle() // off -> on

        #expect(viewModel.isInternalDisplayOff == false)
        #expect(touchBarRecovery.nudgeCallCount == 1)
    }

    @Test func toggleFromOnToOffDoesNotNudge() {
        infoProvider.online = [1: true, 2: false]
        idStore.storedOffState = false // starts on

        let viewModel = makeViewModel()
        viewModel.toggle() // on -> off

        #expect(viewModel.isInternalDisplayOff == true)
        #expect(touchBarRecovery.nudgeCallCount == 0)
    }

    @Test func toggleThatFailsToEnableDoesNotNudge() {
        // Off before toggle, but no cached display ID anywhere — enable fails,
        // so the display never actually transitions off -> on.
        idStore.storedID = nil
        idStore.storedOffState = true

        let viewModel = makeViewModel()
        viewModel.toggle()

        #expect(viewModel.isInternalDisplayOff == true) // still off, enable failed
        #expect(touchBarRecovery.nudgeCallCount == 0)
    }
}

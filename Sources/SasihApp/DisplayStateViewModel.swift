import SasihCore
import Combine

@MainActor
final class DisplayStateViewModel: ObservableObject {
    let manager: DisplayManager
    private let touchBarRecovery: TouchBarRecovering
    @Published private(set) var isInternalDisplayOff: Bool
    @Published private(set) var lastError: String?
    @Published private(set) var hasExternalDisplay: Bool
    @Published var autoRevertOnReconnectEnabled: Bool {
        didSet { manager.autoRevertOnReconnectEnabled = autoRevertOnReconnectEnabled }
    }

    init(manager: DisplayManager, touchBarRecovery: TouchBarRecovering = TouchBarRecovery()) {
        self.manager = manager
        self.touchBarRecovery = touchBarRecovery
        self.isInternalDisplayOff = manager.isInternalDisplayOff
        self.lastError = manager.lastError
        self.hasExternalDisplay = manager.externalDisplayCount > 0
        self.autoRevertOnReconnectEnabled = manager.autoRevertOnReconnectEnabled
    }

    func refresh() {
        isInternalDisplayOff = manager.isInternalDisplayOff
        lastError = manager.lastError
        hasExternalDisplay = manager.externalDisplayCount > 0
    }

    func toggle() {
        let wasOff = manager.isInternalDisplayOff
        manager.toggle()
        refresh()
        if wasOff && !isInternalDisplayOff {
            touchBarRecovery.nudge()
        }
    }

    /// Maps the Blackout switch's desired value to the right action. The guard
    /// keeps this intent-based: if the state changed since the switch was
    /// rendered (e.g. auto-revert), a stale click can't invert the outcome.
    func setBlackoutActive(_ isActive: Bool) {
        guard isActive != isInternalDisplayOff else { return }
        toggle()
    }
}

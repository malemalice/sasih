import SasihCore
import Combine

@MainActor
final class DisplayStateViewModel: ObservableObject {
    let manager: DisplayManager
    @Published private(set) var isInternalDisplayOff: Bool
    @Published private(set) var lastError: String?
    @Published private(set) var hasExternalDisplay: Bool

    init(manager: DisplayManager) {
        self.manager = manager
        self.isInternalDisplayOff = manager.isInternalDisplayOff
        self.lastError = manager.lastError
        self.hasExternalDisplay = manager.externalDisplayCount > 0
    }

    func refresh() {
        isInternalDisplayOff = manager.isInternalDisplayOff
        lastError = manager.lastError
        hasExternalDisplay = manager.externalDisplayCount > 0
    }

    func toggle() {
        manager.toggle()
        refresh()
    }
}

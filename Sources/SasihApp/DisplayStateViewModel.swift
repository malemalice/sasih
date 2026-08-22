import SasihCore
import Combine

@MainActor
final class DisplayStateViewModel: ObservableObject {
    let manager: DisplayManager
    @Published private(set) var isInternalDisplayOff: Bool
    @Published private(set) var lastError: String?

    init(manager: DisplayManager) {
        self.manager = manager
        self.isInternalDisplayOff = manager.isInternalDisplayOff
        self.lastError = manager.lastError
    }

    func refresh() {
        isInternalDisplayOff = manager.isInternalDisplayOff
        lastError = manager.lastError
    }

    func toggle() {
        manager.toggle()
        refresh()
    }
}

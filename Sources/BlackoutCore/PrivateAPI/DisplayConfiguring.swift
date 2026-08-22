import CoreGraphics

/// Applies an enabled/disabled state to a display. Abstracted so DisplayManager
/// can be unit tested without touching the real private API or display hardware.
public protocol DisplayConfiguring {
    @discardableResult
    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool
}

/// Real implementation: wraps the resolved private symbol in the public
/// CGBeginDisplayConfiguration/CGCompleteDisplayConfiguration transaction.
public struct PrivateAPIDisplayConfigurer: DisplayConfiguring {
    private let symbolLookup: SymbolLookup

    public init(symbolLookup: SymbolLookup = DlsymSymbolLookup()) {
        self.symbolLookup = symbolLookup
    }

    public func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool {
        guard let resolved = SymbolResolution.resolve(using: symbolLookup) else { return false }

        var configRef: CGDisplayConfigRef?
        var result = CGBeginDisplayConfiguration(&configRef)
        guard result == .success else { return false }

        result = resolved.fn(configRef, id, enabled ? 1 : 0)
        guard result == .success else {
            CGCancelDisplayConfiguration(configRef)
            return false
        }

        result = CGCompleteDisplayConfiguration(configRef, .forSession)
        return result == .success
    }
}

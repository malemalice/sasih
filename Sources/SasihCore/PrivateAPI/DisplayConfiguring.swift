import CoreGraphics

/// Applies an enabled/disabled state to a display. Abstracted so DisplayManager
/// can be unit tested without touching the real private API or display hardware.
public protocol DisplayConfiguring {
    @discardableResult
    func setDisplay(_ id: CGDirectDisplayID, enabled: Bool) -> Bool

    /// Takes the given displays out of their mirror set for the current login
    /// session, so a mirrored external becomes a separate, drawable display.
    /// Both screens stay on — this never makes anything dark.
    func stopMirroring(_ ids: [CGDirectDisplayID]) -> Bool

    /// Puts the given displays back into hardware mirroring of `master` for
    /// the current login session. Both screens stay on.
    func startMirroring(_ ids: [CGDirectDisplayID], of master: CGDirectDisplayID) -> Bool
}

public extension DisplayConfiguring {
    func stopMirroring(_ ids: [CGDirectDisplayID]) -> Bool { false }
    func startMirroring(_ ids: [CGDirectDisplayID], of master: CGDirectDisplayID) -> Bool { false }
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

    /// Public CoreGraphics API (no private symbol). `.forSession` so the
    /// user's own mirroring preference comes back at their next login.
    public func stopMirroring(_ ids: [CGDirectDisplayID]) -> Bool {
        configureMirroring(ids, of: kCGNullDirectDisplay)
    }

    public func startMirroring(_ ids: [CGDirectDisplayID], of master: CGDirectDisplayID) -> Bool {
        configureMirroring(ids, of: master)
    }

    private func configureMirroring(_ ids: [CGDirectDisplayID], of master: CGDirectDisplayID) -> Bool {
        guard !ids.isEmpty else { return false }

        var configRef: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&configRef) == .success else { return false }

        for id in ids {
            guard CGConfigureDisplayMirrorOfDisplay(configRef, id, master) == .success else {
                CGCancelDisplayConfiguration(configRef)
                return false
            }
        }

        return CGCompleteDisplayConfiguration(configRef, .forSession) == .success
    }
}

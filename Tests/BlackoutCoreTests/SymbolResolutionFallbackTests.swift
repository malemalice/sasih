import CoreGraphics
import Testing
@testable import BlackoutCore

/// A free function with no captures can be used directly as a @convention(c)
/// function pointer value — this stands in for a real resolved private symbol.
private func dummyConfigureDisplayEnabled(
    _ ref: OpaquePointer?,
    _ id: CGDirectDisplayID,
    _ enabled: Int32
) -> CGError {
    .success
}

private struct FakeSymbolLookup: SymbolLookup {
    let resolvable: Set<String>

    func lookup(_ name: String) -> ConfigureDisplayEnabledFn? {
        resolvable.contains(name) ? dummyConfigureDisplayEnabled : nil
    }
}

struct SymbolResolutionFallbackTests {
    @Test func prefersPrimaryNameWhenBothResolve() {
        let lookup = FakeSymbolLookup(resolvable: ["SLSConfigureDisplayEnabled", "CGSConfigureDisplayEnabled"])
        let resolved = SymbolResolution.resolve(using: lookup)
        #expect(resolved?.name == "SLSConfigureDisplayEnabled")
    }

    @Test func fallsBackToLegacyNameWhenPrimaryFails() {
        let lookup = FakeSymbolLookup(resolvable: ["CGSConfigureDisplayEnabled"])
        let resolved = SymbolResolution.resolve(using: lookup)
        #expect(resolved?.name == "CGSConfigureDisplayEnabled")
    }

    @Test func returnsNilWhenNeitherResolves() {
        let lookup = FakeSymbolLookup(resolvable: [])
        #expect(SymbolResolution.resolve(using: lookup) == nil)
    }

    @Test func displayConfigurerReturnsFalseWhenSymbolUnavailable() {
        let configurer = PrivateAPIDisplayConfigurer(symbolLookup: FakeSymbolLookup(resolvable: []))
        // Does not crash or silently no-op — reports failure so DisplayManager
        // can surface a visible error instead of pretending to have succeeded.
        #expect(configurer.setDisplay(1, enabled: false) == false)
    }
}

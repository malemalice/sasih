import CoreGraphics
import Darwin

public typealias ConfigureDisplayEnabledFn = @convention(c) (OpaquePointer?, CGDirectDisplayID, Int32) -> CGError

/// Looks up a single named C symbol, returning it as a typed function pointer.
public protocol SymbolLookup {
    func lookup(_ name: String) -> ConfigureDisplayEnabledFn?
}

/// Real lookup via dlopen/dlsym against SkyLight.framework.
public struct DlsymSymbolLookup: SymbolLookup {
    public init() {}

    public func lookup(_ name: String) -> ConfigureDisplayEnabledFn? {
        guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
            return nil
        }
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: ConfigureDisplayEnabledFn.self)
    }
}

public enum SymbolResolution {
    /// Tried in order; SLS is the current name, CGS is the older fallback.
    public static let candidateNames = ["SLSConfigureDisplayEnabled", "CGSConfigureDisplayEnabled"]

    /// Returns the first resolvable symbol by name, or nil if none resolve
    /// (meaning the private API isn't available on this macOS build).
    public static func resolve(using lookup: SymbolLookup) -> (name: String, fn: ConfigureDisplayEnabledFn)? {
        for name in candidateNames {
            if let fn = lookup.lookup(name) {
                return (name, fn)
            }
        }
        return nil
    }
}

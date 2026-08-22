import CoreGraphics
import Darwin
import Foundation

typealias ConfigureDisplayEnabledFn = @convention(c) (OpaquePointer?, CGDirectDisplayID, Int32) -> CGError

func resolveConfigureDisplayEnabled() -> (name: String, fn: ConfigureDisplayEnabledFn)? {
    guard let handle = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_NOW) else {
        print("FAIL: could not dlopen SkyLight.framework")
        return nil
    }
    for name in ["SLSConfigureDisplayEnabled", "CGSConfigureDisplayEnabled"] {
        if let sym = dlsym(handle, name) {
            let fn = unsafeBitCast(sym, to: ConfigureDisplayEnabledFn.self)
            return (name, fn)
        }
    }
    return nil
}

func activeDisplays() -> [CGDirectDisplayID] {
    // CGGetOnlineDisplayList (not CGGetActiveDisplayList) — the active list excludes
    // non-primary displays that are currently mirrored, which would hide a connected
    // external monitor entirely if mirroring is on.
    var count: UInt32 = 0
    CGGetOnlineDisplayList(0, nil, &count)
    guard count > 0 else { return [] }
    var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
    CGGetOnlineDisplayList(count, &ids, &count)
    return ids
}

func setDisplay(_ configureFn: ConfigureDisplayEnabledFn, id: CGDirectDisplayID, enabled: Bool) -> CGError {
    var configRef: CGDisplayConfigRef?
    var result = CGBeginDisplayConfiguration(&configRef)
    guard result == .success else { return result }
    result = configureFn(configRef, id, enabled ? 1 : 0)
    if result != .success {
        CGCancelDisplayConfiguration(configRef)
        return result
    }
    result = CGCompleteDisplayConfiguration(configRef, .forSession)
    return result
}

// MARK: - Global state for signal-safety restore

nonisolated(unsafe) var g_configureFn: ConfigureDisplayEnabledFn?
nonisolated(unsafe) var g_internalDisplayID: CGDirectDisplayID = 0
nonisolated(unsafe) var g_didDisable = false

func restoreHandler(_ sig: Int32) {
    if g_didDisable, let fn = g_configureFn {
        _ = setDisplay(fn, id: g_internalDisplayID, enabled: true)
        write(STDOUT_FILENO, "\nInterrupted — internal display restored.\n", 43)
    }
    exit(1)
}

// MARK: - Main

print("Sasih spike — validating SLSConfigureDisplayEnabled on this machine")
print(String(repeating: "-", count: 60))

let displays = activeDisplays()
guard !displays.isEmpty else {
    print("FAIL: no active displays found")
    exit(1)
}

var internalID: CGDirectDisplayID?
var externalIDs: [CGDirectDisplayID] = []
for id in displays {
    if CGDisplayIsBuiltin(id) != 0 {
        internalID = id
    } else {
        externalIDs.append(id)
    }
}

guard let internalID else {
    print("FAIL: could not find a built-in display among active displays: \(displays)")
    exit(1)
}
print("Built-in display ID: \(internalID)")
print("External display ID(s): \(externalIDs)")

guard !externalIDs.isEmpty else {
    print("FAIL: no external display connected. Refusing to proceed (would strand the user with no display).")
    exit(1)
}

guard let resolved = resolveConfigureDisplayEnabled() else {
    print("FAIL: neither SLSConfigureDisplayEnabled nor CGSConfigureDisplayEnabled resolved via dlsym.")
    print("This means the private API approach is not viable on this macOS build — re-evaluate before continuing.")
    exit(1)
}
print("Resolved private symbol: \(resolved.name)")

g_configureFn = resolved.fn
g_internalDisplayID = internalID

signal(SIGINT, restoreHandler)
signal(SIGTERM, restoreHandler)

print("")
print("Press Enter to disable the internal display for 5 seconds, then it will auto re-enable.")
print("(Ctrl-C at any point will immediately restore it.)")
_ = readLine()

print("Disabling internal display \(internalID)...")
let disableResult = setDisplay(resolved.fn, id: internalID, enabled: false)
g_didDisable = (disableResult == .success)
print("Disable result: \(disableResult) (raw: \(disableResult.rawValue)) — \(disableResult == .success ? "SUCCESS" : "FAILURE")")

guard disableResult == .success else {
    print("FAIL: disable call did not succeed. Aborting without further action.")
    exit(1)
}

Thread.sleep(forTimeInterval: 5.0)

print("Re-enabling internal display \(internalID)...")
let enableResult = setDisplay(resolved.fn, id: internalID, enabled: true)
g_didDisable = false
print("Enable result: \(enableResult) (raw: \(enableResult.rawValue)) — \(enableResult == .success ? "SUCCESS" : "FAILURE")")

if disableResult == .success && enableResult == .success {
    print("")
    print("SPIKE PASSED: confirm visually that the internal panel went dark and came back.")
} else {
    print("")
    print("SPIKE FAILED: check CGError codes above.")
    exit(1)
}

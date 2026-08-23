import Foundation

/// Best-effort fix for a real hardware quirk on Touch Bar Macs (13" M1/M2
/// MacBook Pro — the only Apple Silicon models with a Touch Bar): after
/// DisplayManager re-enables the internal display via the private
/// SLSConfigureDisplayEnabled API, the Touch Bar can be left blank (still
/// touch-responsive, just not rendering) because its DFR session doesn't get
/// resignaled the way it would by a "real" display change.
///
/// Confirmed via live testing (2026-08-23): restarting ControlStrip and/or
/// TouchBarServer does NOT fix this. Only a WindowServer restart (logout) or
/// a display sleep→wake cycle does. This automates the sleep→wake cycle so
/// the user doesn't have to log out.
enum TouchBarRecovery {
    static func isTouchBarPresent() -> Bool {
        runQuiet("/usr/bin/pgrep", ["-x", "TouchBarServer"]) == 0
    }

    static func nudge() {
        guard isTouchBarPresent() else { return }
        DispatchQueue.global(qos: .utility).async {
            _ = runQuiet("/usr/bin/pmset", ["displaysleepnow"])
            Thread.sleep(forTimeInterval: 0.5)
            _ = runQuiet("/usr/bin/caffeinate", ["-u", "-t", "1"])
        }
    }

    @discardableResult
    private static func runQuiet(_ path: String, _ args: [String]) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = args
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return -1
        }
        task.waitUntilExit()
        return task.terminationStatus
    }
}

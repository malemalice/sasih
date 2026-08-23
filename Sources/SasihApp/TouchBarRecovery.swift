import Foundation

/// Runs an external process and reports its exit status. Abstracted so
/// TouchBarRecovery is unit-testable without actually shelling out.
protocol ProcessRunning: Sendable {
    @discardableResult
    func run(_ path: String, _ args: [String]) -> Int32
}

/// Real implementation: wraps Foundation's Process.
struct RealProcessRunner: ProcessRunning {
    @discardableResult
    func run(_ path: String, _ args: [String]) -> Int32 {
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

protocol TouchBarRecovering {
    func nudge()
}

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
struct TouchBarRecovery: TouchBarRecovering {
    private let runner: ProcessRunning
    private let sleepDelay: @Sendable (TimeInterval) -> Void
    private let dispatchAsync: (@escaping @Sendable () -> Void) -> Void

    init(
        runner: ProcessRunning = RealProcessRunner(),
        sleepDelay: @escaping @Sendable (TimeInterval) -> Void = { Thread.sleep(forTimeInterval: $0) },
        dispatchAsync: @escaping (@escaping @Sendable () -> Void) -> Void = { work in
            DispatchQueue.global(qos: .utility).async(execute: work)
        }
    ) {
        self.runner = runner
        self.sleepDelay = sleepDelay
        self.dispatchAsync = dispatchAsync
    }

    func isTouchBarPresent() -> Bool {
        runner.run("/usr/bin/pgrep", ["-x", "TouchBarServer"]) == 0
    }

    func nudge() {
        guard isTouchBarPresent() else { return }
        dispatchAsync { [runner, sleepDelay] in
            runner.run("/usr/bin/pmset", ["displaysleepnow"])
            sleepDelay(0.5)
            runner.run("/usr/bin/caffeinate", ["-u", "-t", "1"])
        }
    }
}

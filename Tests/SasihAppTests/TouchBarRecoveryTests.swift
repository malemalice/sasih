import Testing
@testable import SasihApp

private final class FakeProcessRunner: ProcessRunning, @unchecked Sendable {
    var calls: [(path: String, args: [String])] = []
    var pgrepResult: Int32 = 0

    func run(_ path: String, _ args: [String]) -> Int32 {
        calls.append((path, args))
        if path == "/usr/bin/pgrep" {
            return pgrepResult
        }
        return 0
    }
}

final class TouchBarRecoveryTests {
    private let runner = FakeProcessRunner()
    private let recovery: TouchBarRecovery

    init() {
        recovery = TouchBarRecovery(
            runner: runner,
            sleepDelay: { _ in },
            dispatchAsync: { work in work() } // run synchronously so assertions are deterministic
        )
    }

    @Test func isTouchBarPresentTrueWhenPgrepFindsProcess() {
        runner.pgrepResult = 0
        #expect(recovery.isTouchBarPresent() == true)
    }

    @Test func isTouchBarPresentFalseWhenPgrepFindsNothing() {
        runner.pgrepResult = 1
        #expect(recovery.isTouchBarPresent() == false)
    }

    @Test func nudgeDoesNothingWhenTouchBarAbsent() {
        runner.pgrepResult = 1
        recovery.nudge()
        #expect(runner.calls.count == 1) // only the pgrep presence check
        #expect(runner.calls[0].path == "/usr/bin/pgrep")
    }

    @Test func nudgeSleepsThenWakesWhenTouchBarPresent() {
        runner.pgrepResult = 0
        recovery.nudge()
        #expect(runner.calls.map(\.path) == [
            "/usr/bin/pgrep",
            "/usr/bin/pmset",
            "/usr/bin/caffeinate",
        ])
        #expect(runner.calls[1].args == ["displaysleepnow"])
        #expect(runner.calls[2].args == ["-u", "-t", "1"])
    }
}

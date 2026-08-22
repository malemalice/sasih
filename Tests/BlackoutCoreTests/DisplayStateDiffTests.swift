import CoreGraphics
import Testing
@testable import BlackoutCore

struct DisplayStateDiffTests {
    @Test func noChangeWhenAlreadyAtTarget() {
        let current: [CGDirectDisplayID: Bool] = [1: false, 2: true]
        let target: [CGDirectDisplayID: Bool] = [1: false, 2: true]
        #expect(DisplayStateDiff.diff(current: current, target: target) == [])
    }

    @Test func emitsChangeWhenDifferent() {
        let current: [CGDirectDisplayID: Bool] = [1: true]
        let target: [CGDirectDisplayID: Bool] = [1: false]
        #expect(DisplayStateDiff.diff(current: current, target: target) == [DisplayChange(id: 1, enabled: false)])
    }

    @Test func mixedChangesOnlyEmitsWhatDiffers() {
        let current: [CGDirectDisplayID: Bool] = [1: true, 2: false, 3: true]
        let target: [CGDirectDisplayID: Bool] = [1: false, 2: false, 3: false]
        let result = DisplayStateDiff.diff(current: current, target: target).sorted { $0.id < $1.id }
        #expect(result == [DisplayChange(id: 1, enabled: false), DisplayChange(id: 3, enabled: false)])
    }

    @Test func unknownCurrentStateAssumedEnabled() {
        // A display not present in `current` (never seen before) is assumed enabled,
        // so a target of `enabled: true` produces no spurious change.
        let current: [CGDirectDisplayID: Bool] = [:]
        let target: [CGDirectDisplayID: Bool] = [5: true]
        #expect(DisplayStateDiff.diff(current: current, target: target) == [])
    }

    @Test func emptyTargetProducesNoChanges() {
        let current: [CGDirectDisplayID: Bool] = [1: true, 2: false]
        #expect(DisplayStateDiff.diff(current: current, target: [:]) == [])
    }
}

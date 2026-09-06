import Testing
@testable import SasihCore

struct DisplayIDStoreTests {
    @Test func roundTripSaveLoad() {
        #expect(DisplayIDStoreScenario.roundTripSaveLoad())
    }

    @Test func loadReturnsNilWhenNothingSaved() {
        #expect(DisplayIDStoreScenario.loadReturnsNilWhenNothingSaved())
    }

    @Test func fallsBackToFileWhenDefaultsMissing() {
        #expect(DisplayIDStoreScenario.fallsBackToFileWhenDefaultsMissing())
    }

    @Test func usesDefaultsWhenFileIsCorruptOrMissing() {
        #expect(DisplayIDStoreScenario.usesDefaultsWhenFileIsCorruptOrMissing())
    }

    @Test func offStateDefaultsToFalse() {
        #expect(DisplayIDStoreScenario.offStateDefaultsToFalse())
    }

    @Test func offStateRoundTrip() {
        #expect(DisplayIDStoreScenario.offStateRoundTrip())
    }

    @Test func autoRevertDefaultsToTrue() {
        #expect(DisplayIDStoreScenario.autoRevertDefaultsToTrue())
    }

    @Test func autoRevertRoundTrip() {
        #expect(DisplayIDStoreScenario.autoRevertRoundTrip())
    }
}

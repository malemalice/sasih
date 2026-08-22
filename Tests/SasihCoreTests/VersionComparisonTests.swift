import Testing
@testable import SasihCore

struct VersionComparisonTests {
    @Test func newerPatchVersionIsNewer() {
        #expect(VersionComparison.isNewer("0.2.0", than: "0.1.0"))
    }

    @Test func identicalVersionsAreNotNewer() {
        #expect(!VersionComparison.isNewer("0.1.0", than: "0.1.0"))
    }

    @Test func olderVersionIsNotNewer() {
        #expect(!VersionComparison.isNewer("0.1.0", than: "0.2.0"))
    }

    @Test func comparesNumericallyNotLexicographically() {
        #expect(VersionComparison.isNewer("1.10.0", than: "1.9.0"))
    }

    @Test func missingComponentsTreatedAsZero() {
        #expect(!VersionComparison.isNewer("1.0", than: "1.0.0"))
        #expect(VersionComparison.isNewer("1.0.1", than: "1.0"))
    }

    @Test func majorVersionDominates() {
        #expect(VersionComparison.isNewer("2.0.0", than: "1.9.9"))
    }
}

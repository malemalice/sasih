import Testing
@testable import SasihCore

struct DisplayGuardsTests {
    @Test func canDisableInternalRequiresAtLeastOneUsableExternal() {
        #expect(DisplayGuards.canDisableInternal(usableExternalDisplayCount: 0) == false)
        #expect(DisplayGuards.canDisableInternal(usableExternalDisplayCount: 1) == true)
        #expect(DisplayGuards.canDisableInternal(usableExternalDisplayCount: 5) == true)
    }

    @Test func isLastActiveDisplay() {
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 0) == true)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 1) == true)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 2) == false)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 10) == false)
    }
}

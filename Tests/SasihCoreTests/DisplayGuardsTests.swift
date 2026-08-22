import Testing
@testable import SasihCore

struct DisplayGuardsTests {
    @Test func canDisableInternalRequiresAtLeastOneExternal() {
        #expect(DisplayGuards.canDisableInternal(externalDisplayCount: 0) == false)
        #expect(DisplayGuards.canDisableInternal(externalDisplayCount: 1) == true)
        #expect(DisplayGuards.canDisableInternal(externalDisplayCount: 5) == true)
    }

    @Test func isLastActiveDisplay() {
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 0) == true)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 1) == true)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 2) == false)
        #expect(DisplayGuards.isLastActiveDisplay(activeDisplayCount: 10) == false)
    }
}

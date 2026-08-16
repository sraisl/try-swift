import Testing
@testable import TryCore

@Test func versionIsSet() {
    #expect(TryCoreVersion.string == "0.1.0")
}

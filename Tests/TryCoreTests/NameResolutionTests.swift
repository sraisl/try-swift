import Testing
@testable import TryCore

@Suite struct NameResolutionTests {
    @Test func uniqueDirNameReturnsAsIsWhenFree() {
        let result = NameResolution.uniqueDirName(triesPath: "/tries", dirName: "foo") { _ in false }
        #expect(result == "foo")
    }

    @Test func uniqueDirNameAppendsDashSuffixOnCollision() {
        let taken: Set<String> = ["/tries/foo", "/tries/foo-2"]
        let result = NameResolution.uniqueDirName(triesPath: "/tries", dirName: "foo") { taken.contains($0) }
        #expect(result == "foo-3")
    }

    @Test func versioningReturnsBaseAloneWhenFree() {
        // Matches upstream: returns `base` without the date prefix when free.
        let result = NameResolution.resolveUniqueNameWithVersioning(
            triesPath: "/tries", datePrefix: "2026-08-16", base: "widget"
        ) { _ in false }
        #expect(result == "widget")
    }

    @Test func versioningIncrementsTrailingDigitsReturningBaseAlone() {
        let taken: Set<String> = [
            "/tries/2026-08-16-foo2", "/tries/2026-08-16-foo3",
        ]
        let result = NameResolution.resolveUniqueNameWithVersioning(
            triesPath: "/tries", datePrefix: "2026-08-16", base: "foo2"
        ) { taken.contains($0) }
        #expect(result == "foo4")
    }

    @Test func versioningFallsBackToDashSuffixWithoutTrailingDigits() {
        let taken: Set<String> = ["/tries/2026-08-16-widget"]
        let result = NameResolution.resolveUniqueNameWithVersioning(
            triesPath: "/tries", datePrefix: "2026-08-16", base: "widget"
        ) { taken.contains($0) }
        #expect(result == "widget-2")
    }
}

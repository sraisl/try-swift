import Testing
@testable import TryTerminal

@Suite struct MetricsTests {
    @Test func plainAsciiWidthEqualsLength() {
        #expect(Metrics.visibleWidth("hello") == 5)
    }

    @Test func stripsANSISequencesFromWidth() {
        let colored = "\u{1B}[1mhello\u{1B}[0m"
        #expect(Metrics.visibleWidth(colored) == 5)
    }

    @Test func emojiCountsAsDoubleWidth() {
        #expect(Metrics.visibleWidth("\u{1F600}") == 2) // grinning face
    }

    @Test func variationSelectorIsZeroWidth() {
        #expect(Metrics.charWidth(Unicode.Scalar(0xFE0F)!) == 0)
    }

    @Test func truncateReturnsUnchangedWhenWithinBudget() {
        #expect(Metrics.truncate("short", maxWidth: 10) == "short")
    }

    @Test func truncateAppendsOverflowMarker() {
        let result = Metrics.truncate("this is a long string", maxWidth: 10)
        #expect(result.hasSuffix("\u{2026}"))
        #expect(Metrics.visibleWidth(result) <= 10)
    }

    @Test func truncateFromStartKeepsTail() {
        // Matches upstream's truncate_from_start: it keeps the trailing
        // portion but does NOT prepend an overflow marker (unlike truncate,
        // which truncates from the end and does add one).
        let result = Metrics.truncateFromStart("/very/long/path/to/file.txt", maxWidth: 15)
        #expect(result.hasSuffix("file.txt"))
        #expect(Metrics.visibleWidth(result) <= 15)
    }
}

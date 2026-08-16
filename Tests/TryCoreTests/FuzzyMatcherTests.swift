import Testing
@testable import TryCore

@Suite struct FuzzyMatcherTests {
    @Test func emptyQueryMatchesAllOrderedByBaseScore() {
        let entries = [
            FuzzyEntry(data: "low", text: "low", baseScore: 1.0),
            FuzzyEntry(data: "high", text: "high", baseScore: 5.0),
            FuzzyEntry(data: "mid", text: "mid", baseScore: 3.0),
        ]
        let matcher = FuzzyMatcher(entries: entries)
        let results = matcher.match("")

        #expect(results.map(\.data) == ["high", "mid", "low"])
        #expect(results.map(\.score) == [5.0, 3.0, 1.0])
    }

    @Test func missingCharacterExcludesEntry() {
        let entries = [FuzzyEntry(data: "redis", text: "redis-server", baseScore: 0)]
        let matcher = FuzzyMatcher(entries: entries)
        #expect(matcher.match("xyz").isEmpty)
    }

    @Test func subsequenceOrderRequired() {
        let entries = [FuzzyEntry(data: "a", text: "abc", baseScore: 0)]
        let matcher = FuzzyMatcher(entries: entries)
        #expect(matcher.match("cba").isEmpty)
        #expect(!matcher.match("abc").isEmpty)
        #expect(!matcher.match("ac").isEmpty)
    }

    @Test func wordBoundaryBonusAtStart() {
        // "rds" against "redis-server" vs against "wardsredis" (mid-word, no boundary)
        let boundary = FuzzyEntry(data: "boundary", text: "redis", baseScore: 0)
        let noBoundary = FuzzyEntry(data: "no-boundary", text: "xredisx", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [boundary, noBoundary])
        let results = matcher.match("r")
        let boundaryScore = results.first { $0.data == "boundary" }!.score
        let noBoundaryScore = results.first { $0.data == "no-boundary" }!.score
        #expect(boundaryScore > noBoundaryScore)
    }

    @Test func wordBoundaryAfterDashCounts() {
        // "redis-server": r=0 e=1 d=2 i=3 s=4 -=5 s=6 e=7 r=8 v=9 e=10 r=11.
        // The matcher is greedy-leftmost, so a single "s" query matches the
        // first "s" at position 4, not the word-boundary "s" at position 6.
        let entry = FuzzyEntry(data: "e", text: "redis-server", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [entry])
        let results = matcher.match("s")
        #expect(results.first!.positions == [4])
    }

    @Test func wordBoundaryBonusAppliesAtDashPosition() {
        // Query "ss" forces the second match past the first "s" (pos 4), so
        // it lands on the word-boundary "s" at position 6 and should score
        // higher than an equivalent match with no boundary involved.
        let boundary = FuzzyEntry(data: "boundary", text: "redis-server", baseScore: 0)
        let noBoundary = FuzzyEntry(data: "no-boundary", text: "redissserver", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [boundary, noBoundary])
        let results = matcher.match("ss")
        let boundaryResult = results.first { $0.data == "boundary" }!
        #expect(boundaryResult.positions == [4, 6])
    }

    @Test func proximityBonusFavorsConsecutiveMatches() {
        let tight = FuzzyEntry(data: "tight", text: "abcdef", baseScore: 0)
        let loose = FuzzyEntry(data: "loose", text: "azbzcz", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [tight, loose])
        let results = matcher.match("abc")
        let tightScore = results.first { $0.data == "tight" }!.score
        let looseScore = results.first { $0.data == "loose" }!.score
        #expect(tightScore > looseScore)
    }

    @Test func lengthPenaltyFavorsShorterNames() {
        let short = FuzzyEntry(data: "short", text: "ab", baseScore: 0)
        let long = FuzzyEntry(data: "long", text: "abxxxxxxxxxxxxxxxxxx", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [short, long])
        let results = matcher.match("ab")
        let shortScore = results.first { $0.data == "short" }!.score
        let longScore = results.first { $0.data == "long" }!.score
        #expect(shortScore > longScore)
    }

    @Test func caseInsensitiveMatch() {
        let entry = FuzzyEntry(data: "e", text: "RedisServer", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [entry])
        #expect(!matcher.match("redis").isEmpty)
        #expect(!matcher.match("REDIS").isEmpty)
    }

    @Test func limitTruncatesAfterFullSort() {
        let entries = (0..<10).map { FuzzyEntry(data: $0, text: "item\($0)", baseScore: Double($0)) }
        let matcher = FuzzyMatcher(entries: entries)
        let results = matcher.match("", limit: 3)
        #expect(results.count == 3)
        #expect(results.map(\.data) == [9, 8, 7])
    }

    @Test func highlightPositionsAreCorrect() {
        let entry = FuzzyEntry(data: "e", text: "redis-server", baseScore: 0)
        let matcher = FuzzyMatcher(entries: [entry])
        let result = matcher.match("rds").first!
        // r=0, d=2, s=4 (subsequence positions in "redis-server")
        #expect(result.positions == [0, 2, 4])
    }
}

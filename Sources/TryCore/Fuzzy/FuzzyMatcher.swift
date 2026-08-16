/// Port of lib/fuzzy.rb's `Fuzzy` class scoring engine.
///
/// Scoring recipe per candidate, given a non-empty query:
///   - subsequence match required (case-insensitive); any missing char -> no match
///   - +1.0 per matched character
///   - +1.0 word-boundary bonus if the match sits at position 0, or the previous
///     character is not in [a-z0-9] (ASCII-only, matches Ruby's WORD_BOUNDARY_RE)
///   - proximity bonus += 2.0 / sqrt(gap + 1), gap = found - lastPos - 1
///   - after all chars matched: score *= queryLen / (lastPos + 1)         (density bonus)
///   - score *= 10.0 / (entry.text.count + 10.0)                          (length penalty)
/// Empty query matches everything at baseScore, unsorted by match quality.
private enum FuzzyScoringTables {
    static let sqrtTable: [Double] = (0...64).map { 2.0 / (Double($0 + 1)).squareRoot() }
}

public struct FuzzyMatcher<T: Sendable> {
    private let entries: [FuzzyEntry<T>]

    public init(entries: [FuzzyEntry<T>]) {
        self.entries = entries
    }

    /// Mirrors `Fuzzy#match(query).limit(n)`: full sort by descending score,
    /// then hard-truncate to `limit` if provided.
    public func match(_ query: String, limit: Int? = nil) -> [FuzzyMatch<T>] {
        let queryChars = Array(query.lowercased())

        var results: [FuzzyMatch<T>] = []
        results.reserveCapacity(entries.count)

        for entry in entries {
            guard let (score, positions) = Self.calculateMatch(entry, queryChars: queryChars) else {
                continue
            }
            results.append(FuzzyMatch(data: entry.data, text: entry.text, positions: positions, score: score))
        }

        results.sort { $0.score > $1.score }

        if let limit, results.count > limit {
            return Array(results.prefix(limit))
        }
        return results
    }

    private static func calculateMatch(
        _ entry: FuzzyEntry<T>, queryChars: [Character]
    ) -> (score: Double, positions: [Int])? {
        if queryChars.isEmpty {
            return (entry.baseScore, [])
        }

        let text = entry.textLower
        var positions: [Int] = []
        positions.reserveCapacity(queryChars.count)
        var score = entry.baseScore
        var lastPos = -1
        var searchFrom = 0

        for qc in queryChars {
            guard let found = findChar(qc, in: text, from: searchFrom) else {
                return nil
            }
            positions.append(found)
            score += 1.0

            if found == 0 || isWordBoundary(text[found - 1]) {
                score += 1.0
            }

            if lastPos >= 0 {
                let gap = found - lastPos - 1
                let table = FuzzyScoringTables.sqrtTable
                score += gap < table.count ? table[gap] : 2.0 / Double(gap + 1).squareRoot()
            }

            lastPos = found
            searchFrom = found + 1
        }

        if lastPos >= 0 {
            score *= Double(queryChars.count) / Double(lastPos + 1)
        }
        score *= 10.0 / (Double(entry.text.count) + 10.0)

        return (score, positions)
    }

    private static func findChar(_ char: Character, in text: [Character], from start: Int) -> Int? {
        var i = start
        while i < text.count {
            if text[i] == char { return i }
            i += 1
        }
        return nil
    }

    private static func isWordBoundary(_ char: Character) -> Bool {
        guard let ascii = char.asciiValue else { return true }
        let isLower = ascii >= 97 && ascii <= 122
        let isDigit = ascii >= 48 && ascii <= 57
        return !(isLower || isDigit)
    }
}

import Foundation

/// Port of lib/tui.rb's `Tui::Metrics` module. Width calculations scoped to
/// what this app's own output needs (ASCII + emoji + variation selectors) -
/// not full Unicode East-Asian-width support.
public enum Metrics {
    private static let ansiStripPattern = #"\x1B\[[0-9;]*[A-Za-z]"#
    private static let escapeTerminator = CharacterSet.letters

    public static func charWidth(_ code: UInt32) -> Int {
        if code >= 0xFE00 && code <= 0xFE0F { return 0 }
        if code >= 0x1F300 && code <= 0x1FAFF { return 2 }
        return 1
    }

    public static func charWidth(_ scalar: Unicode.Scalar) -> Int {
        charWidth(scalar.value)
    }

    public static func isZeroWidth(_ scalar: Unicode.Scalar) -> Bool {
        let code = scalar.value
        return (code >= 0xFE00 && code <= 0xFE0F)
            || (code >= 0x200B && code <= 0x200D)
            || (code >= 0x0300 && code <= 0x036F)
            || (code >= 0xE0100 && code <= 0xE01EF)
    }

    public static func isWide(_ scalar: Unicode.Scalar) -> Bool {
        charWidth(scalar) == 2
    }

    public static func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: ansiStripPattern, with: "", options: .regularExpression)
    }

    public static func visibleWidth(_ text: String) -> Int {
        let stripped = stripANSI(text)
        return stripped.unicodeScalars.reduce(0) { $0 + charWidth($1) }
    }

    /// Truncates from the end to fit `maxWidth` visible columns. ANSI escape
    /// sequences encountered before the cutoff pass through unmodified (they
    /// don't count toward width); trailing whitespace is stripped before the
    /// overflow marker is appended, matching Ruby's `.rstrip + overflow`.
    public static func truncate(_ text: String, maxWidth: Int, overflow: String = "\u{2026}") -> String {
        guard visibleWidth(text) > maxWidth else { return text }

        let overflowWidth = visibleWidth(overflow)
        let target = max(maxWidth - overflowWidth, 0)

        var result = ""
        var width = 0
        var inEscape = false
        var escapeBuf = ""

        for ch in text {
            if inEscape {
                escapeBuf.append(ch)
                if ch.unicodeScalars.allSatisfy({ escapeTerminator.contains($0) }) {
                    result += escapeBuf
                    escapeBuf = ""
                    inEscape = false
                }
                continue
            }
            if ch == "\u{1B}" {
                inEscape = true
                escapeBuf = String(ch)
                continue
            }

            let cw = ch.unicodeScalars.reduce(0) { $0 + charWidth($1) }
            if width + cw > target { break }
            result.append(ch)
            width += cw
        }

        return rstripped(result) + overflow
    }

    /// Truncates from the start, keeping the tail - preserves any leading
    /// ANSI escape sequences (e.g. a dim/color prefix) ahead of the cut.
    public static func truncateFromStart(_ text: String, maxWidth: Int) -> String {
        let visWidth = visibleWidth(text)
        guard visWidth > maxWidth else { return text }

        var leadingEscapes = ""
        var inEscape = false
        var escapeBuf = ""
        for ch in text {
            if inEscape {
                escapeBuf.append(ch)
                if ch.unicodeScalars.allSatisfy({ escapeTerminator.contains($0) }) {
                    leadingEscapes += escapeBuf
                    escapeBuf = ""
                    inEscape = false
                }
            } else if ch == "\u{1B}" {
                inEscape = true
                escapeBuf = String(ch)
            } else {
                break
            }
        }

        let charsToSkip = visWidth - maxWidth
        var skipped = 0
        var result = ""
        inEscape = false

        for ch in text {
            if inEscape {
                if skipped >= charsToSkip { result.append(ch) }
                if ch.unicodeScalars.allSatisfy({ escapeTerminator.contains($0) }) { inEscape = false }
                continue
            }
            if ch == "\u{1B}" {
                inEscape = true
                if skipped >= charsToSkip { result.append(ch) }
                continue
            }

            let cw = ch.unicodeScalars.reduce(0) { $0 + charWidth($1) }
            if skipped < charsToSkip {
                skipped += cw
            } else {
                result.append(ch)
            }
        }

        return leadingEscapes + result
    }

    private static func rstripped(_ text: String) -> String {
        var chars = Array(text)
        while let last = chars.last, last.isWhitespace {
            chars.removeLast()
        }
        return String(chars)
    }
}

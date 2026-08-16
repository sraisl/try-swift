/// Port of lib/tui.rb's `Tui::SegmentWriter` (plus its nested FillSegment/
/// EmojiSegment). Builds a line's left/center/right content as a sequence of
/// segments, deferring fill-character expansion until the enclosing width is
/// known.
public enum SegmentStyle {
    case dim, bold, highlight, accent
}

public enum Segment {
    case text(String)
    case fill(char: String, style: SegmentStyle?)
    case emoji(String, width: Int, charCount: Int)

    static func emoji(_ char: String) -> Segment {
        var width = 0
        var charCount = 0
        for scalar in char.unicodeScalars {
            let w = Metrics.charWidth(scalar)
            width += w
            if w > 0 { charCount += 1 }
        }
        return .emoji(char, width: width, charCount: charCount)
    }

    var widthDelta: Int {
        switch self {
        case .emoji(let char, let width, let charCount):
            _ = char
            return width - charCount
        default:
            return 0
        }
    }
}

public final class SegmentWriter {
    public let zIndex: Int
    private var segments: [Segment] = []
    private(set) var hasWide = false
    private var widthDeltaTotal = 0

    public init(zIndex: Int) {
        self.zIndex = zIndex
    }

    @discardableResult
    public func write(_ text: String) -> SegmentWriter {
        guard !text.isEmpty else { return self }
        segments.append(.text(text))
        return self
    }

    @discardableResult
    public func write(_ segment: Segment) -> SegmentWriter {
        if case .emoji = segment {
            hasWide = true
            widthDeltaTotal += segment.widthDelta
        }
        segments.append(segment)
        return self
    }

    @discardableResult
    public func writeDim(_ text: String) -> SegmentWriter {
        write(TuiText.dim(text))
    }

    @discardableResult
    public func writeBold(_ text: String) -> SegmentWriter {
        write(TuiText.bold(text))
    }

    @discardableResult
    public func writeHighlight(_ text: String) -> SegmentWriter {
        write(TuiText.highlight(text))
    }

    @discardableResult
    public func writeFill(char: String = " ", style: SegmentStyle? = nil) -> SegmentWriter {
        segments.append(.fill(char: char, style: style))
        return self
    }

    public var isEmpty: Bool { segments.isEmpty }

    public func toString(width: Int? = nil) -> String {
        var rendered = ""
        for segment in segments {
            switch segment {
            case .text(let s):
                rendered += s
            case .emoji(let char, _, _):
                rendered += char
            case .fill(let char, let style):
                guard let width else {
                    fatalError("fill requires width context")
                }
                rendered += renderFill(char: char, style: style, rendered: rendered, width: width)
            }
        }
        return rendered
    }

    private func renderFill(char: String, style: SegmentStyle?, rendered: String, width: Int) -> String {
        let maxFill = width - 1
        let remaining = maxFill - Metrics.visibleWidth(rendered)
        guard remaining > 0 else { return "" }

        var pattern = char
        if pattern.isEmpty { pattern = " " }
        let patternWidth = max(Metrics.visibleWidth(pattern), 1)
        let repeatCount = Int((Double(remaining) / Double(patternWidth)).rounded(.up))
        var filler = String(repeating: pattern, count: max(repeatCount, 0))
        filler = Metrics.truncate(filler, maxWidth: remaining, overflow: "")
        return applyStyle(filler, style)
    }

    private func applyStyle(_ text: String, _ style: SegmentStyle?) -> String {
        switch style {
        case .dim: return TuiText.dim(text)
        case .bold: return TuiText.bold(text)
        case .highlight: return TuiText.highlight(text)
        case .accent: return TuiText.accent(text)
        case nil: return text
        }
    }
}

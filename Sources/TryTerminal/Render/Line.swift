/// Port of lib/tui.rb's `Tui::Line`. Composes left/center/right segment
/// writers into a single rendered row, truncating each to fit and
/// positioning center/right relative to the available width.
public final class Line {
    public var background: String?
    public var truncate: Bool

    private let leftWriter = SegmentWriter(zIndex: 1)
    private var centerWriter: SegmentWriter?
    private var rightWriter: SegmentWriter?
    private(set) var hasInput = false
    private var inputPrefixWidth = 0

    public init(background: String? = nil, truncate: Bool = true) {
        self.background = background
        self.truncate = truncate
    }

    public var write: SegmentWriter { leftWriter }
    public var left: SegmentWriter { leftWriter }

    public var center: SegmentWriter {
        if let centerWriter { return centerWriter }
        let w = SegmentWriter(zIndex: 2)
        centerWriter = w
        return w
    }

    public var right: SegmentWriter {
        if let rightWriter { return rightWriter }
        let w = SegmentWriter(zIndex: 0)
        rightWriter = w
        return w
    }

    public func markHasInput(prefixWidth: Int) {
        hasInput = true
        inputPrefixWidth = prefixWidth
    }

    public func cursorColumn(inputField: InputFieldState) -> Int {
        inputPrefixWidth + inputField.cursor + 1
    }

    public func render(width: Int, trailingNewline: Bool) -> String {
        var buffer = "\r"
        buffer += ANSI.clearEOL

        if let background, TuiColors.enabled {
            buffer += background
        }

        let maxContent = width - 1
        let contentWidth = max(width, 1)

        var leftText = leftWriter.toString(width: contentWidth)
        var centerText = centerWriter?.toString(width: contentWidth) ?? ""
        var rightText = rightWriter?.toString(width: contentWidth) ?? ""

        if truncate, !leftText.isEmpty {
            leftText = Metrics.truncate(leftText, maxWidth: maxContent)
        }
        let leftWidth = leftText.isEmpty ? 0 : Metrics.visibleWidth(leftText)

        if !centerText.isEmpty {
            let maxCenter = maxContent - leftWidth - 4
            if maxCenter > 0 {
                centerText = Metrics.truncate(centerText, maxWidth: maxCenter)
            } else {
                centerText = ""
            }
        }
        let centerWidth = centerText.isEmpty ? 0 : Metrics.visibleWidth(centerText)

        let usedByLeftCenter = leftWidth + centerWidth + (centerWidth > 0 ? 2 : 0)
        let availableForRight = maxContent - usedByLeftCenter - 1

        var rightWidth = 0
        if !rightText.isEmpty {
            rightWidth = Metrics.visibleWidth(rightText)
            if availableForRight <= 0 {
                rightText = ""
                rightWidth = 0
            } else if rightWidth > availableForRight {
                rightText = Metrics.truncateFromStart(rightText, maxWidth: availableForRight)
                rightWidth = Metrics.visibleWidth(rightText)
            }
        }

        let centerCol = centerText.isEmpty ? 0 : max((maxContent - centerWidth) / 2, leftWidth + 1)
        let rightCol = rightText.isEmpty ? maxContent : (maxContent - rightWidth)

        if !leftText.isEmpty { buffer += leftText }
        var currentPos = leftWidth

        if !centerText.isEmpty {
            let gapToCenter = centerCol - currentPos
            if gapToCenter > 0 { buffer += String(repeating: " ", count: gapToCenter) }
            buffer += centerText
            currentPos = centerCol + centerWidth
        }

        let fillEnd = rightText.isEmpty ? maxContent : rightCol
        let gap = fillEnd - currentPos
        if gap > 0 { buffer += String(repeating: " ", count: gap) }

        if !rightText.isEmpty {
            buffer += rightText
            buffer += ANSI.resetFG
        }

        buffer += ANSI.reset
        if trailingNewline { buffer += "\n" }

        return buffer
    }
}

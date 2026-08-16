import Darwin
import Foundation

/// Port of lib/tui.rb's `Tui::Screen`. Builds an entire frame into one
/// buffer and issues a single `write(2)` to avoid flicker from partial
/// writes, matching the Ruby original's discipline exactly.
public final class Screen {
    public let header = Section()
    public let body = Section()
    public let footer = Section()

    private let fd: Int32
    private let fixedWidth: Int?
    private let fixedHeight: Int?
    public private(set) var width: Int = 80
    public private(set) var height: Int = 24
    private var inputField: InputFieldState?

    public init(fd: Int32 = STDERR_FILENO, width: Int? = nil, height: Int? = nil) {
        self.fd = fd
        self.fixedWidth = width
        self.fixedHeight = height
        refreshSize()
    }

    @discardableResult
    public func refreshSize() -> Screen {
        let (rows, cols) = TerminalSize.current()
        height = fixedHeight ?? rows
        width = fixedWidth ?? cols
        return self
    }

    public func input(_ placeholder: String = "", value: String = "", cursor: Int? = nil) -> InputFieldState {
        precondition(inputField == nil, "screen already has an input")
        let field = InputFieldState(placeholder: placeholder, text: value, cursor: cursor)
        inputField = field
        return field
    }

    /// Lets the caller push edits back into the screen's tracked input field
    /// state (needed because InputFieldState is a value type, unlike Ruby's
    /// mutable InputField object).
    public func setInputField(_ field: InputFieldState) {
        inputField = field
    }

    public func clear() {
        header.clear()
        body.clear()
        footer.clear()
        inputField = nil
    }

    /// Builds the full frame and issues one write to the underlying fd.
    /// Returns the built buffer (useful for tests that want to assert on
    /// content without a real terminal).
    @discardableResult
    public func flush() -> String {
        refreshSize()

        var buf = ANSI.home

        var cursorRow: Int?
        var cursorCol: Int?
        var currentRow = 0

        for line in header.lines {
            if let inputField, line.hasInput {
                cursorRow = currentRow + 1
                cursorCol = line.cursorColumn(inputField: inputField)
            }
            buf += line.render(width: width, trailingNewline: true)
            currentRow += 1
        }

        let footerLineCount = footer.lines.count
        let bodySpace = height - currentRow - footerLineCount

        var bodyRendered = 0
        for line in body.lines {
            if bodyRendered >= bodySpace { break }
            if let inputField, line.hasInput {
                cursorRow = currentRow + 1
                cursorCol = line.cursorColumn(inputField: inputField)
            }
            buf += line.render(width: width, trailingNewline: true)
            currentRow += 1
            bodyRendered += 1
        }

        let gap = bodySpace - bodyRendered
        let blankLine = "\r" + ANSI.clearEOL + String(repeating: " ", count: max(width - 1, 0)) + "\n"
        let blankLineNoNewline = "\r" + ANSI.clearEOL + String(repeating: " ", count: max(width - 1, 0))
        var i = 0
        while i < gap {
            if i == gap - 1 && footer.lines.isEmpty {
                buf += blankLineNoNewline
            } else {
                buf += blankLine
            }
            currentRow += 1
            i += 1
        }

        for (idx, line) in footer.lines.enumerated() {
            if let inputField, line.hasInput {
                cursorRow = currentRow + 1
                cursorCol = line.cursorColumn(inputField: inputField)
            }
            if idx == footerLineCount - 1 {
                buf += line.render(width: width, trailingNewline: false)
            } else {
                buf += line.render(width: width, trailingNewline: true)
            }
            currentRow += 1
        }

        if let cursorRow, let cursorCol, inputField != nil {
            buf += "\u{1B}[\(cursorRow);\(cursorCol)H"
            buf += ANSI.show
        } else {
            buf += ANSI.hide
        }

        buf += ANSI.reset

        writeToFD(buf)
        clear()
        return buf
    }

    private func writeToFD(_ text: String) {
        let data = Array(text.utf8)
        data.withUnsafeBufferPointer { ptr in
            guard let base = ptr.baseAddress else { return }
            _ = Darwin.write(fd, base, ptr.count)
        }
    }
}

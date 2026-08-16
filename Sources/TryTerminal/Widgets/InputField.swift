/// Port of lib/tui.rb's `Tui::InputField`, as a value type since it's small
/// and copied into TUIState.
public struct InputFieldState: Equatable {
    public var placeholder: String
    public var text: String
    public var cursor: Int

    public init(placeholder: String = "", text: String = "", cursor: Int? = nil) {
        self.placeholder = placeholder
        self.text = text
        self.cursor = cursor ?? text.count
        clampCursor()
    }

    /// Returns true if the key was consumed as text-editing, false if the
    /// caller (app-level dispatcher) should handle it instead. Mirrors
    /// `handle_key`'s exact keybinding table.
    public mutating func handleKey(_ key: String?) -> Bool {
        guard let key, !key.isEmpty else { return false }

        switch key {
        case "\u{7F}", "\u{08}":
            backspace(); return true
        case "\u{1B}[3~":
            deleteForward(); return true
        case "\u{01}":
            cursorHome(); return true
        case "\u{05}":
            cursorEnd(); return true
        case "\u{02}":
            cursorLeft(); return true
        case "\u{06}":
            cursorRight(); return true
        case "\u{0B}":
            killToEnd(); return true
        case "\u{15}":
            killToStart(); return true
        case "\u{17}":
            killWord(); return true
        default:
            if isLeftArrow(key) { cursorLeft(); return true }
            if isRightArrow(key) { cursorRight(); return true }
            if isHomeKey(key) { cursorHome(); return true }
            if isEndKey(key) { cursorEnd(); return true }
            if key.count == 1, let scalar = key.unicodeScalars.first {
                let code = scalar.value
                if code >= 32 && code != 127 {
                    insert(key)
                    return true
                }
            }
            return false
        }
    }

    public mutating func insert(_ s: String) {
        guard !s.isEmpty else { return }
        let chars = Array(text)
        let before = String(chars[0..<min(cursor, chars.count)])
        let after = cursor < chars.count ? String(chars[cursor...]) : ""
        text = before + s + after
        cursor += s.count
        clampCursor()
    }

    public mutating func backspace() {
        guard cursor > 0 else { return }
        var chars = Array(text)
        chars.remove(at: cursor - 1)
        text = String(chars)
        cursor -= 1
    }

    public mutating func deleteForward() {
        let chars = Array(text)
        guard cursor < chars.count else { return }
        var mutableChars = chars
        mutableChars.remove(at: cursor)
        text = String(mutableChars)
    }

    public mutating func killToEnd() {
        let chars = Array(text)
        text = String(chars[0..<min(cursor, chars.count)])
    }

    public mutating func killToStart() {
        let chars = Array(text)
        text = cursor < chars.count ? String(chars[cursor...]) : ""
        cursor = 0
    }

    public mutating func killWord() {
        guard cursor > 0 else { return }
        let chars = Array(text)
        let newPos = Self.wordBoundaryBackward(chars, cursor)
        let after = cursor < chars.count ? String(chars[cursor...]) : ""
        text = String(chars[0..<newPos]) + after
        cursor = newPos
    }

    public mutating func cursorLeft() {
        if cursor > 0 { cursor -= 1 }
    }

    public mutating func cursorRight() {
        if cursor < text.count { cursor += 1 }
    }

    public mutating func cursorHome() {
        cursor = 0
    }

    public mutating func cursorEnd() {
        cursor = text.count
    }

    public func render() -> String {
        guard !text.isEmpty else {
            return TuiText.dim(placeholder)
        }

        let chars = Array(text)
        let before = String(chars[0..<min(cursor, chars.count)])
        let cursorChar = cursor < chars.count ? String(chars[cursor]) : " "
        let after = cursor + 1 < chars.count ? String(chars[(cursor + 1)...]) : ""

        var buf = before
        if TuiColors.enabled { buf += Palette.inputCursorOn }
        buf += cursorChar
        if TuiColors.enabled { buf += Palette.inputCursorOff }
        buf += after
        return buf
    }

    private mutating func clampCursor() {
        if cursor < 0 { cursor = 0 }
        if cursor > text.count { cursor = text.count }
    }

    private static func wordBoundaryBackward(_ chars: [Character], _ cursor: Int) -> Int {
        var pos = cursor - 1
        while pos >= 0, !isAlnum(chars[pos]) { pos -= 1 }
        while pos >= 0, isAlnum(chars[pos]) { pos -= 1 }
        return pos + 1
    }

    private static func isAlnum(_ ch: Character) -> Bool {
        guard let ascii = ch.asciiValue else { return false }
        return (ascii >= 48 && ascii <= 57) || (ascii >= 65 && ascii <= 90) || (ascii >= 97 && ascii <= 122)
    }

    private func isLeftArrow(_ key: String) -> Bool {
        if key == "\u{1B}[D" || key == "\u{1B}OD" { return true }
        return key.hasPrefix("\u{1B}[") && key.hasSuffix("D") && key.count > 3
    }

    private func isRightArrow(_ key: String) -> Bool {
        if key == "\u{1B}[C" || key == "\u{1B}OC" { return true }
        return key.hasPrefix("\u{1B}[") && key.hasSuffix("C") && key.count > 3
    }

    private func isHomeKey(_ key: String) -> Bool {
        key == "\u{1B}[H" || key == "\u{1B}[1~" || key == "\u{1B}[7~" || key == "\u{1B}OH"
    }

    private func isEndKey(_ key: String) -> Bool {
        key == "\u{1B}[F" || key == "\u{1B}[4~" || key == "\u{1B}[8~" || key == "\u{1B}OF"
    }
}

import Testing
@testable import TryTerminal

@Suite struct InputFieldTests {
    @Test func insertPrintableCharacters() {
        var field = InputFieldState()
        let consumedA = field.handleKey("a")
        let consumedB = field.handleKey("b")
        let consumedC = field.handleKey("c")
        #expect(consumedA)
        #expect(consumedB)
        #expect(consumedC)
        #expect(field.text == "abc")
        #expect(field.cursor == 3)
    }

    @Test func backspaceRemovesPrecedingChar() {
        var field = InputFieldState(text: "abc", cursor: 3)
        let consumed = field.handleKey("\u{7F}")
        #expect(consumed)
        #expect(field.text == "ab")
        #expect(field.cursor == 2)
    }

    @Test func deleteForwardRemovesCharAtCursor() {
        var field = InputFieldState(text: "abc", cursor: 0)
        let consumed = field.handleKey("\u{1B}[3~")
        #expect(consumed)
        #expect(field.text == "bc")
        #expect(field.cursor == 0)
    }

    @Test func ctrlAMovesToHome() {
        var field = InputFieldState(text: "abc", cursor: 3)
        let consumed = field.handleKey("\u{01}")
        #expect(consumed)
        #expect(field.cursor == 0)
    }

    @Test func ctrlEMovesToEnd() {
        var field = InputFieldState(text: "abc", cursor: 0)
        let consumed = field.handleKey("\u{05}")
        #expect(consumed)
        #expect(field.cursor == 3)
    }

    @Test func ctrlBMovesCursorLeft() {
        var field = InputFieldState(text: "abc", cursor: 2)
        let consumed = field.handleKey("\u{02}")
        #expect(consumed)
        #expect(field.cursor == 1)
    }

    @Test func ctrlFMovesCursorRight() {
        var field = InputFieldState(text: "abc", cursor: 1)
        let consumed = field.handleKey("\u{06}")
        #expect(consumed)
        #expect(field.cursor == 2)
    }

    @Test func ctrlKKillsToEnd() {
        var field = InputFieldState(text: "abcdef", cursor: 3)
        let consumed = field.handleKey("\u{0B}")
        #expect(consumed)
        #expect(field.text == "abc")
    }

    @Test func ctrlUKillsToStart() {
        var field = InputFieldState(text: "abcdef", cursor: 3)
        let consumed = field.handleKey("\u{15}")
        #expect(consumed)
        #expect(field.text == "def")
        #expect(field.cursor == 0)
    }

    @Test func ctrlWKillsWordBackward() {
        var field = InputFieldState(text: "hello world", cursor: 11)
        let consumed = field.handleKey("\u{17}")
        #expect(consumed)
        #expect(field.text == "hello ")
        #expect(field.cursor == 6)
    }

    @Test func ctrlWSkipsTrailingSeparators() {
        var field = InputFieldState(text: "hello   ", cursor: 8)
        let consumed = field.handleKey("\u{17}")
        #expect(consumed)
        #expect(field.text == "")
    }

    @Test func leftArrowMovesCursorLeft() {
        var field = InputFieldState(text: "abc", cursor: 2)
        let consumed = field.handleKey("\u{1B}[D")
        #expect(consumed)
        #expect(field.cursor == 1)
    }

    @Test func rightArrowMovesCursorRight() {
        var field = InputFieldState(text: "abc", cursor: 1)
        let consumed = field.handleKey("\u{1B}[C")
        #expect(consumed)
        #expect(field.cursor == 2)
    }

    @Test func homeKeyVariantsMoveToStart() {
        for key in ["\u{1B}[H", "\u{1B}[1~", "\u{1B}[7~", "\u{1B}OH"] {
            var field = InputFieldState(text: "abc", cursor: 3)
            let consumed = field.handleKey(key)
            #expect(consumed, "expected \(key.debugDescription) to be consumed")
            #expect(field.cursor == 0)
        }
    }

    @Test func endKeyVariantsMoveToEnd() {
        for key in ["\u{1B}[F", "\u{1B}[4~", "\u{1B}[8~", "\u{1B}OF"] {
            var field = InputFieldState(text: "abc", cursor: 0)
            let consumed = field.handleKey(key)
            #expect(consumed, "expected \(key.debugDescription) to be consumed")
            #expect(field.cursor == 3)
        }
    }

    @Test func unhandledKeyReturnsFalse() {
        var field = InputFieldState(text: "abc", cursor: 0)
        let consumedEsc = field.handleKey("\u{1B}")
        let consumedNil = field.handleKey(nil)
        let consumedEmpty = field.handleKey("")
        #expect(!consumedEsc)
        #expect(!consumedNil)
        #expect(!consumedEmpty)
    }

    @Test func compositeSequenceTypeThenClear() {
        var field = InputFieldState()
        _ = field.handleKey("a")
        _ = field.handleKey("b")
        _ = field.handleKey("c")
        _ = field.handleKey("\u{17}") // Ctrl-W
        #expect(field.text.isEmpty)
    }

    @Test func cursorClampedToTextBounds() {
        let field = InputFieldState(text: "abc", cursor: 99)
        #expect(field.cursor == 3)
        let field2 = InputFieldState(text: "abc", cursor: -5)
        #expect(field2.cursor == 0)
    }
}

import Testing
@testable import TryTerminal

@Suite struct InputFieldTests {
    @Test func insertPrintableCharacters() {
        var field = InputFieldState()
        #expect(field.handleKey("a"))
        #expect(field.handleKey("b"))
        #expect(field.handleKey("c"))
        #expect(field.text == "abc")
        #expect(field.cursor == 3)
    }

    @Test func backspaceRemovesPrecedingChar() {
        var field = InputFieldState(text: "abc", cursor: 3)
        #expect(field.handleKey("\u{7F}"))
        #expect(field.text == "ab")
        #expect(field.cursor == 2)
    }

    @Test func deleteForwardRemovesCharAtCursor() {
        var field = InputFieldState(text: "abc", cursor: 0)
        #expect(field.handleKey("\u{1B}[3~"))
        #expect(field.text == "bc")
        #expect(field.cursor == 0)
    }

    @Test func ctrlAMovesToHome() {
        var field = InputFieldState(text: "abc", cursor: 3)
        #expect(field.handleKey("\u{01}"))
        #expect(field.cursor == 0)
    }

    @Test func ctrlEMovesToEnd() {
        var field = InputFieldState(text: "abc", cursor: 0)
        #expect(field.handleKey("\u{05}"))
        #expect(field.cursor == 3)
    }

    @Test func ctrlBMovesCursorLeft() {
        var field = InputFieldState(text: "abc", cursor: 2)
        #expect(field.handleKey("\u{02}"))
        #expect(field.cursor == 1)
    }

    @Test func ctrlFMovesCursorRight() {
        var field = InputFieldState(text: "abc", cursor: 1)
        #expect(field.handleKey("\u{06}"))
        #expect(field.cursor == 2)
    }

    @Test func ctrlKKillsToEnd() {
        var field = InputFieldState(text: "abcdef", cursor: 3)
        #expect(field.handleKey("\u{0B}"))
        #expect(field.text == "abc")
    }

    @Test func ctrlUKillsToStart() {
        var field = InputFieldState(text: "abcdef", cursor: 3)
        #expect(field.handleKey("\u{15}"))
        #expect(field.text == "def")
        #expect(field.cursor == 0)
    }

    @Test func ctrlWKillsWordBackward() {
        var field = InputFieldState(text: "hello world", cursor: 11)
        #expect(field.handleKey("\u{17}"))
        #expect(field.text == "hello ")
        #expect(field.cursor == 6)
    }

    @Test func ctrlWSkipsTrailingSeparators() {
        var field = InputFieldState(text: "hello   ", cursor: 8)
        #expect(field.handleKey("\u{17}"))
        #expect(field.text == "")
    }

    @Test func leftArrowMovesCursorLeft() {
        var field = InputFieldState(text: "abc", cursor: 2)
        #expect(field.handleKey("\u{1B}[D"))
        #expect(field.cursor == 1)
    }

    @Test func rightArrowMovesCursorRight() {
        var field = InputFieldState(text: "abc", cursor: 1)
        #expect(field.handleKey("\u{1B}[C"))
        #expect(field.cursor == 2)
    }

    @Test func homeKeyVariantsMoveToStart() {
        for key in ["\u{1B}[H", "\u{1B}[1~", "\u{1B}[7~", "\u{1B}OH"] {
            var field = InputFieldState(text: "abc", cursor: 3)
            #expect(field.handleKey(key), "expected \(key.debugDescription) to be consumed")
            #expect(field.cursor == 0)
        }
    }

    @Test func endKeyVariantsMoveToEnd() {
        for key in ["\u{1B}[F", "\u{1B}[4~", "\u{1B}[8~", "\u{1B}OF"] {
            var field = InputFieldState(text: "abc", cursor: 0)
            #expect(field.handleKey(key), "expected \(key.debugDescription) to be consumed")
            #expect(field.cursor == 3)
        }
    }

    @Test func unhandledKeyReturnsFalse() {
        var field = InputFieldState(text: "abc", cursor: 0)
        #expect(!field.handleKey("\u{1B}"))
        #expect(!field.handleKey(nil))
        #expect(!field.handleKey(""))
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

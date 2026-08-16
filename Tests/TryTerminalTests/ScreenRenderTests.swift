import Testing
@testable import TryTerminal

@Suite struct ScreenRenderTests {
    @Test func headerLineIsRenderedWithText() {
        let screen = Screen(width: 40, height: 10)
        screen.header.addLine { $0.write.write("Try Selector") }
        let output = screen.flush()
        #expect(output.contains("Try Selector"))
    }

    @Test func rendersHomeAtStartOfFrame() {
        let screen = Screen(width: 40, height: 10)
        let output = screen.flush()
        #expect(output.hasPrefix(ANSI.home))
    }

    @Test func hidesCursorWhenNoInputField() {
        let screen = Screen(width: 40, height: 10)
        let output = screen.flush()
        #expect(output.contains(ANSI.hide))
    }

    @Test func leftAndRightSegmentsBothAppear() {
        let screen = Screen(width: 40, height: 10)
        screen.body.addLine { line in
            line.write.write("left-text")
            line.right.write("right-text")
        }
        let output = screen.flush()
        #expect(output.contains("left-text"))
        #expect(output.contains("right-text"))
    }

    @Test func centerSegmentIsPositioned() {
        let screen = Screen(width: 40, height: 10)
        screen.body.addLine { line in
            line.center.write("centered")
        }
        let output = screen.flush()
        #expect(output.contains("centered"))
    }

    @Test func clearResetsAllSections() {
        let screen = Screen(width: 40, height: 10)
        screen.header.addLine { $0.write.write("h") }
        screen.body.addLine { $0.write.write("b") }
        _ = screen.flush()
        // flush() calls clear() internally - sections should be empty after.
        #expect(screen.header.lines.isEmpty)
        #expect(screen.body.lines.isEmpty)
    }

    @Test func longLeftTextIsTruncatedToFitWidth() {
        let screen = Screen(width: 20, height: 10)
        screen.body.addLine { line in
            line.write.write(String(repeating: "x", count: 100))
        }
        let output = screen.flush()
        // The truncated content line should not exceed the terminal width.
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        let contentLine = lines.first { $0.contains("x") } ?? ""
        #expect(Metrics.visibleWidth(String(contentLine)) <= 20)
    }
}

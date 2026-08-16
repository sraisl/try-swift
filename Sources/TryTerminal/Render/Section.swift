/// Port of lib/tui.rb's `Tui::Section`.
public final class Section {
    public private(set) var lines: [Line] = []

    public init() {}

    @discardableResult
    public func addLine(background: String? = nil, truncate: Bool = true, _ configure: ((Line) -> Void)? = nil) -> Line {
        let line = Line(background: background, truncate: truncate)
        lines.append(line)
        configure?(line)
        return line
    }

    public func divider(char: String = "\u{2500}", width: Int) {
        addLine { line in
            let span = max(width - 1, 1)
            line.write.write(String(repeating: char, count: span))
        }
    }

    public func clear() {
        lines.removeAll()
    }
}

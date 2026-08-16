/// Port of lib/tui.rb's `Tui::ANSI` module.
public enum ANSI {
    public static let clearEOL = "\u{1B}[K"
    public static let clearEOS = "\u{1B}[J"
    public static let clearScreen = "\u{1B}[2J"
    public static let home = "\u{1B}[H"
    public static let hide = "\u{1B}[?25l"
    public static let show = "\u{1B}[?25h"
    public static let cursorBlink = "\u{1B}[1 q"
    public static let cursorSteady = "\u{1B}[2 q"
    public static let cursorDefault = "\u{1B}[0 q"
    public static let altScreenOn = "\u{1B}[?1049h"
    public static let altScreenOff = "\u{1B}[?1049l"
    public static let reset = "\u{1B}[0m"
    public static let resetFG = "\u{1B}[39m"
    public static let resetBG = "\u{1B}[49m"
    public static let resetIntensity = "\u{1B}[22m"
    public static let bold = "\u{1B}[1m"
    public static let dim = "\u{1B}[2m"

    public static func fg(_ code: Int) -> String { "\u{1B}[38;5;\(code)m" }
    public static func bg(_ code: Int) -> String { "\u{1B}[48;5;\(code)m" }
    public static func moveCol(_ col: Int) -> String { "\u{1B}[\(col)G" }
    public static func sgr(_ codes: String...) -> String { "\u{1B}[\(codes.joined(separator: ";"))m" }
    public static func setTitle(_ title: String) -> String { "\u{1B}]2;\(title)\u{07}" }
}

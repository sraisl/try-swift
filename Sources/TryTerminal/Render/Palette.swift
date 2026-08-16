/// Port of lib/tui.rb's `Tui::Palette` module.
public enum Palette {
    public static let header = ANSI.sgr("1", "38;5;114")
    public static let accent = ANSI.sgr("1", "38;5;214")
    public static let highlight = "\u{1B}[1;33m"
    public static let muted = ANSI.fg(245)
    public static let match = ANSI.sgr("1", "38;5;226")
    public static let inputHint = ANSI.fg(244)
    public static let inputCursorOn = "\u{1B}[7m"
    public static let inputCursorOff = "\u{1B}[27m"

    public static let selectedBG = ANSI.bg(238)
    public static let selectedFG = ANSI.fg(255)
    public static let dangerBG = ANSI.bg(52)
}

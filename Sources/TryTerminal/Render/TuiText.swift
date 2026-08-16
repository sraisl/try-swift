/// Port of lib/tui.rb's `Tui` module-level color toggle and `Tui::Text`.
/// Set once at startup from CLI flags/env before any rendering happens, then
/// only read - `nonisolated(unsafe)` reflects that single-writer-at-startup
/// usage in this single-threaded CLI process.
public enum TuiColors {
    public nonisolated(unsafe) static var enabled = true

    public static func disable() { enabled = false }
    public static func enable() { enabled = true }
}

public enum TuiText {
    public static func bold(_ text: String) -> String {
        wrap(text, ANSI.bold, ANSI.resetIntensity)
    }

    public static func dim(_ text: String) -> String {
        wrap(text, Palette.muted, ANSI.resetFG)
    }

    public static func highlight(_ text: String) -> String {
        wrap(text, Palette.highlight, ANSI.resetFG + ANSI.resetIntensity)
    }

    public static func accent(_ text: String) -> String {
        wrap(text, Palette.accent, ANSI.resetFG + ANSI.resetIntensity)
    }

    private static func wrap(_ text: String, _ prefix: String, _ suffix: String) -> String {
        guard !text.isEmpty else { return "" }
        guard TuiColors.enabled else { return text }
        return prefix + text + suffix
    }
}

import Darwin
import Foundation

/// Mirrors Tui::Terminal.size: TRY_HEIGHT/TRY_WIDTH env override first
/// (critical for deterministic acceptance-test rendering), then
/// ioctl(TIOCGWINSZ) on stderr/stdout/stdin in that order, default 24x80.
public enum TerminalSize {
    public static func current(env: [String: String] = ProcessInfo.processInfo.environment) -> (rows: Int, cols: Int) {
        if let h = env["TRY_HEIGHT"].flatMap(Int.init), h > 0,
           let w = env["TRY_WIDTH"].flatMap(Int.init), w > 0 {
            return (h, w)
        }
        for fd in [STDERR_FILENO, STDOUT_FILENO, STDIN_FILENO] {
            var ws = winsize()
            if ioctl(fd, UInt(TIOCGWINSZ), &ws) == 0, ws.ws_row > 0, ws.ws_col > 0 {
                return (Int(ws.ws_row), Int(ws.ws_col))
            }
        }
        return (24, 80)
    }
}

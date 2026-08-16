import Darwin

/// Puts stdin into raw mode for the lifetime of this guard, restoring the
/// original termios settings on `restore()` or deinit. Uses `cfmakeraw`
/// directly (no `stty` subprocess needed, unlike the Ruby original which
/// shells out under its Spinel AOT compiler constraint).
public final class RawModeGuard {
    private let fd: Int32
    private let saved: termios
    private var restored = false

    public init?(fd: Int32 = STDIN_FILENO) {
        guard isatty(fd) != 0 else { return nil }
        var original = termios()
        guard tcgetattr(fd, &original) == 0 else { return nil }
        self.fd = fd
        self.saved = original

        var raw = original
        cfmakeraw(&raw)
        tcsetattr(fd, TCSANOW, &raw)
    }

    public func restore() {
        guard !restored else { return }
        var s = saved
        tcsetattr(fd, TCSANOW, &s)
        restored = true
    }

    deinit {
        restore()
    }
}

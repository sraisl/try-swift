import Darwin

/// Port of try.rb's `read_keypress`. Reads a single logical keypress,
/// consuming multi-byte ANSI escape sequences (CSI, SS3, X10 mouse) as one
/// unit. The first byte is a blocking read; escape-sequence lookahead bytes
/// are read non-blocking so a lone ESC (no follow-up) returns immediately
/// instead of hanging.
public struct KeyReader {
    private let fd: Int32

    public init(fd: Int32 = STDIN_FILENO) {
        self.fd = fd
    }

    public func readKeypress() -> String? {
        guard let first = blockingReadByte() else { return nil }

        guard first == 0x1B else {
            return String(UnicodeScalar(first))
        }

        guard let second = nonBlockingReadByte() else {
            return "\u{1B}"
        }

        if second == UInt8(ascii: "O") {
            // SS3: ESC O <byte>
            guard let third = nonBlockingReadByte() else {
                return "\u{1B}O"
            }
            return "\u{1B}O" + String(UnicodeScalar(third))
        }

        guard second == UInt8(ascii: "[") else {
            return "\u{1B}" + String(UnicodeScalar(second))
        }

        var sequence: [UInt8] = [0x1B, second]

        // X10 mouse: ESC [ M <button> <x> <y>
        if let third = nonBlockingReadByte() {
            sequence.append(third)
            if third == UInt8(ascii: "M") {
                for _ in 0..<3 {
                    if let b = nonBlockingReadByte() {
                        sequence.append(b)
                    }
                }
                return bytesToString(sequence)
            }

            // CSI: consume until a final byte in 0x40...0x7E
            if (0x40...0x7E).contains(third) {
                return bytesToString(sequence)
            }

            while let next = nonBlockingReadByte() {
                sequence.append(next)
                if (0x40...0x7E).contains(next) {
                    break
                }
            }
        }

        return bytesToString(sequence)
    }

    private func bytesToString(_ bytes: [UInt8]) -> String {
        String(bytes: bytes, encoding: .isoLatin1) ?? String(decoding: bytes, as: UTF8.self)
    }

    private func blockingReadByte() -> UInt8? {
        var byte: UInt8 = 0
        let n = read(fd, &byte, 1)
        return n == 1 ? byte : nil
    }

    private func nonBlockingReadByte() -> UInt8? {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)
        defer { _ = fcntl(fd, F_SETFL, flags) }

        var byte: UInt8 = 0
        let n = read(fd, &byte, 1)
        return n == 1 ? byte : nil
    }
}

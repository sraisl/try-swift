/// Port of try.rb's `parse_test_keys`. Detects token mode (comma-separated
/// or all-caps-hyphen strings, e.g. "CTRL-D,ENTER") vs raw character mode
/// (literal key sequences, e.g. "\e[Aabc"), used by the hidden `--and-keys`
/// test flag to script the TUI non-interactively.
public enum TestKeyParser {
    public static func parse(_ spec: String?) -> [String]? {
        guard let spec, !spec.isEmpty else { return nil }

        let useTokenMode = spec.contains(",") || spec.range(of: #"^[A-Z\-]+$"#, options: .regularExpression) != nil

        if useTokenMode {
            return parseTokenMode(spec)
        } else {
            return parseRawMode(spec)
        }
    }

    private static func parseTokenMode(_ spec: String) -> [String] {
        let tokens = spec.split(separator: ",", omittingEmptySubsequences: false).map {
            $0.trimmingCharacters(in: .whitespaces)
        }
        var keys: [String] = []

        for tok in tokens {
            let up = tok.uppercased()
            switch up {
            case "UP": keys.append("\u{1B}[A")
            case "DOWN": keys.append("\u{1B}[B")
            case "LEFT": keys.append("\u{1B}[D")
            case "RIGHT": keys.append("\u{1B}[C")
            case "ENTER": keys.append("\r")
            case "ESC": keys.append("\u{1B}")
            case "BACKSPACE": keys.append("\u{7F}")
            case "CTRL-A", "CTRLA": keys.append("\u{01}")
            case "CTRL-B", "CTRLB": keys.append("\u{02}")
            case "CTRL-D", "CTRLD": keys.append("\u{04}")
            case "CTRL-E", "CTRLE": keys.append("\u{05}")
            case "CTRL-F", "CTRLF": keys.append("\u{06}")
            case "CTRL-G", "CTRLG": keys.append("\u{07}")
            case "CTRL-H", "CTRLH": keys.append("\u{08}")
            case "CTRL-K", "CTRLK": keys.append("\u{0B}")
            case "CTRL-N", "CTRLN": keys.append("\u{0E}")
            case "CTRL-P", "CTRLP": keys.append("\u{10}")
            case "CTRL-R", "CTRLR": keys.append("\u{12}")
            case "CTRL-T", "CTRLT": keys.append("\u{14}")
            case "CTRL-U", "CTRLU": keys.append("\u{15}")
            case "CTRL-W", "CTRLW": keys.append("\u{17}")
            case "DELETE": keys.append("\u{1B}[3~")
            default:
                if up.hasPrefix("TYPE=") {
                    let value = String(tok.dropFirst(5))
                    for ch in value { keys.append(String(ch)) }
                } else if tok.count == 1 {
                    keys.append(tok)
                }
            }
        }
        return keys
    }

    private static func parseRawMode(_ spec: String) -> [String] {
        var keys: [String] = []
        let chars = Array(spec)
        var i = 0
        while i < chars.count {
            if chars[i] == "\u{1B}", i + 2 < chars.count, chars[i + 1] == "[" {
                keys.append(String(chars[i...(i + 2)]))
                i += 3
            } else {
                keys.append(String(chars[i]))
                i += 1
            }
        }
        return keys
    }
}

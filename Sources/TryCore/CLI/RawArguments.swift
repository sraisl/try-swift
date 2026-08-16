/// Mutating argv model, ported from try.rb's `extract_option_with_value!`
/// pattern: flags can appear anywhere in argv and are removed in place.
public struct RawArguments {
    public private(set) var tokens: [String]

    public init(_ args: [String]) {
        self.tokens = args
    }

    /// Mirrors `extract_option_with_value!(args, opt_name)`: scans from the
    /// end for `opt_name` or `opt_name=value`, removes it (and the following
    /// token if it wasn't `=`-form), returns the value. Last match wins
    /// because the scan starts from the end.
    public mutating func extractOption(_ name: String) -> String? {
        var found = -1
        var i = tokens.count - 1
        while i >= 0 {
            let a = tokens[i]
            if a == name || a.hasPrefix("\(name)=") {
                found = i
                break
            }
            i -= 1
        }
        guard found >= 0 else { return nil }

        let arg = tokens.remove(at: found)
        if let eq = arg.firstIndex(of: "=") {
            return String(arg[arg.index(after: eq)...])
        } else {
            guard found < tokens.count else { return nil }
            return tokens.remove(at: found)
        }
    }

    /// Removes the first occurrence of `name` anywhere in argv, returns
    /// whether it was present. Mirrors `ARGV.delete('--flag')` truthiness.
    @discardableResult
    public mutating func extractFlag(_ name: String) -> Bool {
        guard let idx = tokens.firstIndex(of: name) else { return false }
        tokens.remove(at: idx)
        return true
    }

    /// Mirrors `ARGV.include?(name)` without mutating.
    public func contains(_ name: String) -> Bool {
        tokens.contains(name)
    }

    public func containsAny(_ names: [String]) -> Bool {
        names.contains { tokens.contains($0) }
    }

    public mutating func shift() -> String? {
        guard !tokens.isEmpty else { return nil }
        return tokens.removeFirst()
    }

    public mutating func unshift(_ value: String) {
        tokens.insert(value, at: 0)
    }
}

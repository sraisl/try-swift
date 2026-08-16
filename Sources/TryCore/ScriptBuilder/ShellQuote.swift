public enum ShellQuote {
    /// Single-quotes `str`, escaping embedded `'` as `'"'"'`. Matches try.rb's `q(str)`.
    public static func posix(_ str: String) -> String {
        "'" + str.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }
}

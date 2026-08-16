import Foundation

public struct ParsedGitURI: Equatable {
    public let user: String
    public let repo: String
    public let host: String
}

/// Port of try.rb's `parse_git_uri`, checked in this exact order:
///   1. https?://github.com/user/repo
///   2. git@github.com:user/repo
///   3. https?://host/user/repo             (generic host, e.g. gitlab.com)
///   4. git@host:user/path/to/repo          (repo = basename of path)
///   5. ssh://user@host/user/path           (repo = basename of path)
///   6. user@host:path/to/repo              (SCP-style; repo = basename of path)
/// `.git` suffix is stripped from the whole URI up front (only a trailing
/// match, mirrors Ruby's `uri.sub(/\.git$/, '')`).
public enum GitURIParser {
    public static func isGitURI(_ input: String) -> Bool {
        parse(input) != nil
    }

    public static func parse(_ input: String) -> ParsedGitURI? {
        var uri = input
        if uri.hasSuffix(".git") {
            uri = String(uri.dropLast(4))
        }
        guard !uri.isEmpty else { return nil }

        if let m = firstMatch(#"^https?://github\.com/([^/]+)/([^/]+)"#, in: uri), m.count == 3 {
            return ParsedGitURI(user: m[1], repo: m[2], host: "github.com")
        }
        if let m = firstMatch(#"^git@github\.com:([^/]+)/([^/]+)"#, in: uri), m.count == 3 {
            return ParsedGitURI(user: m[1], repo: m[2], host: "github.com")
        }
        if let m = firstMatch(#"^https?://([^/]+)/([^/]+)/([^/]+)"#, in: uri), m.count == 4 {
            return ParsedGitURI(user: m[2], repo: m[3], host: m[1])
        }
        if let m = firstMatch(#"^git@([^:]+):([^/]+)/(.+)"#, in: uri), m.count == 4 {
            let repo = basename(m[3])
            return ParsedGitURI(user: m[2], repo: repo, host: m[1])
        }
        if let m = firstMatch(#"^ssh://[^@/]+@([^/]+)/([^/]+)/(.+)"#, in: uri), m.count == 4 {
            let repo = basename(m[3])
            return ParsedGitURI(user: m[2], repo: repo, host: m[1])
        }
        if let m = firstMatch(#"^([^@/:]+)@([^:]+):(.+)"#, in: uri), m.count == 4 {
            let repo = basename(m[3])
            return ParsedGitURI(user: m[1], repo: repo, host: m[2])
        }

        return nil
    }

    private static func basename(_ path: String) -> String {
        (path as NSString).lastPathComponent
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let result = regex.firstMatch(in: text, range: range) else { return nil }

        var groups: [String] = []
        for i in 0..<result.numberOfRanges {
            guard let r = Range(result.range(at: i), in: text) else { return nil }
            groups.append(String(text[r]))
        }
        return groups
    }
}

import Foundation

/// Port of try.rb's `is_git_uri?`. Note this is a looser heuristic than
/// `GitURIParser.parse` succeeding — it's what decides whether the first
/// token of a default-command invocation should be treated as a clone
/// target instead of a picker search term.
public enum GitURIHeuristic {
    public static func looksLikeGitURI(_ arg: String?) -> Bool {
        guard let arg else { return false }
        if firstMatch(#"^(https?://|git@)"#, in: arg) { return true }
        if arg.contains("github.com") { return true }
        if arg.contains("gitlab.com") { return true }
        if arg.hasSuffix(".git") { return true }
        return false
    }

    private static func firstMatch(_ pattern: String, in text: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, range: range) != nil
    }
}

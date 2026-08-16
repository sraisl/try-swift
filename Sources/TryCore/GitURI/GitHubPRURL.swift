import Foundation

public struct GitHubPRDetails: Equatable {
    public let owner: String
    public let repo: String
    public let prID: String
    /// Canonical base-repo clone URI (not the /pull/N URL).
    public let cloneURI: String
}

/// Port of try.rb's `github_pr_details`.
/// Matches: https?://(www.)?github.com/<owner>/<repo>/pull/<id>(/)?
public enum GitHubPRURL {
    private static let pattern = #"^https?://(?:www\.)?github\.com/([^/]+)/([^/]+)/pull/(\d+)/?$"#

    public static func parse(_ input: String) -> GitHubPRDetails? {
        let uri = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(uri.startIndex..<uri.endIndex, in: uri)
        guard let result = regex.firstMatch(in: uri, range: range), result.numberOfRanges == 4 else {
            return nil
        }

        func group(_ i: Int) -> String? {
            guard let r = Range(result.range(at: i), in: uri) else { return nil }
            return String(uri[r])
        }

        guard let owner = group(1), let repo = group(2), let prID = group(3) else { return nil }
        let cloneURI = "https://github.com/\(owner)/\(repo).git"
        return GitHubPRDetails(owner: owner, repo: repo, prID: prID, cloneURI: cloneURI)
    }
}

import Foundation

/// Port of try.rb's `generate_clone_directory_name`.
/// PR URLs take precedence over generic URI parsing (mirrors
/// `github_pr_details(git_uri) || parse_git_uri(git_uri)`).
public enum CloneNaming {
    public static func directoryName(gitURI: String, customName: String?, today: Date = Date()) -> String? {
        if let customName, !customName.isEmpty {
            return customName
        }

        let user: String
        let repo: String
        if let pr = GitHubPRURL.parse(gitURI) {
            user = pr.owner
            repo = pr.repo
        } else if let parsed = GitURIParser.parse(gitURI) {
            user = parsed.user
            repo = parsed.repo
        } else {
            return nil
        }

        let datePrefix = DatePrefix.today(today)
        return "\(datePrefix)-\(user)-\(repo)"
    }
}

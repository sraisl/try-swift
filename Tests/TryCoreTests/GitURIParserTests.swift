import Testing
@testable import TryCore

@Suite struct GitURIParserTests {
    @Test func githubHTTPS() {
        let r = GitURIParser.parse("https://github.com/tobi/try")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "github.com"))
    }

    @Test func githubHTTPSWithGitSuffix() {
        let r = GitURIParser.parse("https://github.com/tobi/try.git")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "github.com"))
    }

    @Test func githubSSHShort() {
        let r = GitURIParser.parse("git@github.com:tobi/try.git")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "github.com"))
    }

    @Test func genericHTTPSHost() {
        let r = GitURIParser.parse("https://gitlab.com/tobi/try")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "gitlab.com"))
    }

    @Test func genericSSHNestedPath() {
        let r = GitURIParser.parse("git@example.com:tobi/deep/path/try.git")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "example.com"))
    }

    @Test func sshURIWithPort() {
        let r = GitURIParser.parse("ssh://git@example.com/tobi/try.git")
        #expect(r == ParsedGitURI(user: "tobi", repo: "try", host: "example.com"))
    }

    @Test func scpStyle() {
        let r = GitURIParser.parse("user@host.com:path/to/repo.git")
        #expect(r == ParsedGitURI(user: "user", repo: "repo", host: "host.com"))
    }

    @Test func nonURIReturnsNil() {
        #expect(GitURIParser.parse("just a search term") == nil)
    }

    @Test func isGitURIConvenience() {
        #expect(GitURIParser.isGitURI("https://github.com/tobi/try"))
        #expect(!GitURIParser.isGitURI("hello world"))
    }
}

@Suite struct GitHubPRURLTests {
    @Test func parsesStandardPRURL() {
        let pr = GitHubPRURL.parse("https://github.com/tobi/try/pull/123")
        #expect(pr?.owner == "tobi")
        #expect(pr?.repo == "try")
        #expect(pr?.prID == "123")
        #expect(pr?.cloneURI == "https://github.com/tobi/try.git")
    }

    @Test func parsesWithWWWAndTrailingSlash() {
        let pr = GitHubPRURL.parse("https://www.github.com/tobi/try/pull/42/")
        #expect(pr?.prID == "42")
    }

    @Test func rejectsNonPRURL() {
        #expect(GitHubPRURL.parse("https://github.com/tobi/try") == nil)
        #expect(GitHubPRURL.parse("https://github.com/tobi/try/issues/1") == nil)
    }
}

@Suite struct GitURIHeuristicTests {
    @Test func detectsHTTPSAndSSHPrefixes() {
        #expect(GitURIHeuristic.looksLikeGitURI("https://example.com/x"))
        #expect(GitURIHeuristic.looksLikeGitURI("git@example.com:x/y"))
    }

    @Test func detectsKnownHosts() {
        #expect(GitURIHeuristic.looksLikeGitURI("github.com/tobi/try"))
        #expect(GitURIHeuristic.looksLikeGitURI("gitlab.com/tobi/try"))
    }

    @Test func detectsGitSuffix() {
        #expect(GitURIHeuristic.looksLikeGitURI("some/path/repo.git"))
    }

    @Test func rejectsPlainSearchTerms() {
        #expect(!GitURIHeuristic.looksLikeGitURI("redis-experiment"))
        #expect(!GitURIHeuristic.looksLikeGitURI(nil))
    }
}

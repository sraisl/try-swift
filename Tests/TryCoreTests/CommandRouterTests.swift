import Testing
@testable import TryCore

@Suite struct RawArgumentsTests {
    @Test func extractOptionRemovesFlagAndValue() {
        var args = RawArguments(["clone", "--path", "/custom", "url"])
        let value = args.extractOption("--path")
        #expect(value == "/custom")
        #expect(args.tokens == ["clone", "url"])
    }

    @Test func extractOptionSupportsEqualsForm() {
        var args = RawArguments(["clone", "--path=/custom", "url"])
        let value = args.extractOption("--path")
        #expect(value == "/custom")
        #expect(args.tokens == ["clone", "url"])
    }

    @Test func extractOptionScansFromEndLastMatchWins() {
        var args = RawArguments(["--path", "/first", "cmd", "--path", "/second"])
        let value = args.extractOption("--path")
        #expect(value == "/second")
        #expect(args.tokens == ["--path", "/first", "cmd"])
    }

    @Test func extractOptionReturnsNilWhenAbsent() {
        var args = RawArguments(["clone", "url"])
        #expect(args.extractOption("--path") == nil)
        #expect(args.tokens == ["clone", "url"])
    }

    @Test func extractFlagRemovesFirstOccurrence() {
        var args = RawArguments(["--and-exit", "clone", "--and-exit"])
        #expect(args.extractFlag("--and-exit"))
        #expect(args.tokens == ["clone", "--and-exit"])
    }
}

@Suite struct CommandRouterTests {
    @Test func helpAnywhereShortCircuits() {
        let (_, cmd) = CommandRouter.route(argv: ["clone", "--help"], env: [:])
        #expect(cmd == .help)
    }

    @Test func helpShortFlagWorks() {
        let (_, cmd) = CommandRouter.route(argv: ["-h"], env: [:])
        #expect(cmd == .help)
    }

    @Test func versionAnywhereShortCircuits() {
        let (_, cmd) = CommandRouter.route(argv: ["clone", "--version"], env: [:])
        #expect(cmd == .version)
    }

    @Test func noCommandGivesNoCommand() {
        let (_, cmd) = CommandRouter.route(argv: [], env: [:])
        #expect(cmd == .noCommand)
    }

    @Test func pathFlagAnywhereOverridesTriesPath() {
        let (opts, _) = CommandRouter.route(argv: ["--path", "/custom/tries", "query"], env: [:])
        #expect(opts.triesPath == "/custom/tries")
    }

    @Test func pathFallsBackToEnvThenDefault() {
        let (opts, _) = CommandRouter.route(argv: ["query"], env: ["TRY_PATH": "/env/tries"])
        #expect(opts.triesPath == "/env/tries")
    }

    @Test func cloneCommandRoutesWithRemainingArgs() {
        let (_, cmd) = CommandRouter.route(argv: ["clone", "https://github.com/tobi/try", "myname"], env: [:])
        #expect(cmd == .clone(remainingArgs: ["https://github.com/tobi/try", "myname"]))
    }

    @Test func execCloneSubcommandRoutes() {
        let (_, cmd) = CommandRouter.route(argv: ["exec", "clone", "https://github.com/tobi/try"], env: [:])
        #expect(cmd == .execClone(remainingArgs: ["https://github.com/tobi/try"]))
    }

    @Test func execWorktreeSubcommandRoutes() {
        let (_, cmd) = CommandRouter.route(argv: ["exec", "worktree", "dir", "name"], env: [:])
        #expect(cmd == .execWorktree(remainingArgs: ["dir", "name"]))
    }

    @Test func execCdSubcommandRoutesToDefault() {
        let (_, cmd) = CommandRouter.route(argv: ["exec", "cd", "query"], env: [:])
        #expect(cmd == .execDefault(remainingArgs: ["query"]))
    }

    @Test func execWithUnknownSubfallsThroughToDefault() {
        let (_, cmd) = CommandRouter.route(argv: ["exec", "some-query"], env: [:])
        #expect(cmd == .execDefault(remainingArgs: ["some-query"]))
    }

    @Test func worktreeCommandRoutes() {
        let (_, cmd) = CommandRouter.route(argv: ["worktree", "dir", "name"], env: [:])
        #expect(cmd == .worktree(remainingArgs: ["dir", "name"]))
    }

    @Test func unknownTokenFallsThroughToDefaultCdWithTokenReinserted() {
        let (_, cmd) = CommandRouter.route(argv: ["my-search-term"], env: [:])
        #expect(cmd == .defaultCd(remainingArgs: ["my-search-term"]))
    }

    @Test func andFlagsAreExtracted() {
        let (opts, cmd) = CommandRouter.route(
            argv: ["--and-type", "alpha", "--and-exit", "--and-confirm", "YES"], env: [:]
        )
        #expect(opts.andType == "alpha")
        #expect(opts.andExit)
        #expect(opts.andConfirm == "YES")
        #expect(cmd == .noCommand)
    }

    @Test func dotArgFallsThroughToDefaultCd() {
        let (_, cmd) = CommandRouter.route(argv: [".", "myname"], env: [:])
        #expect(cmd == .defaultCd(remainingArgs: [".", "myname"]))
    }
}

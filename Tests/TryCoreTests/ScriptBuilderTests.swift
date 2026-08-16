import Testing
@testable import TryCore

@Suite struct ShellQuoteTests {
    @Test func wrapsInSingleQuotes() {
        #expect(ShellQuote.posix("hello") == "'hello'")
    }

    @Test func escapesEmbeddedSingleQuote() {
        #expect(ShellQuote.posix("it's") == "'it'\"'\"'s'")
    }

    @Test func handlesEmptyString() {
        #expect(ShellQuote.posix("") == "''")
    }
}

@Suite struct ScriptBuilderTests {
    @Test func rendersWarningLineFirst() {
        var builder = ScriptBuilder()
        builder.add("echo hi")
        let output = builder.render()
        #expect(output.hasPrefix(ScriptBuilder.warningLine + "\n"))
    }

    @Test func singleCommandHasNoContinuation() {
        var builder = ScriptBuilder()
        builder.add("echo hi")
        let output = builder.render()
        #expect(output == "\(ScriptBuilder.warningLine)\necho hi\n")
    }

    @Test func multipleCommandsJoinedWithAndContinuation() {
        var builder = ScriptBuilder()
        builder.add("cmd1")
        builder.add("cmd2")
        builder.add("cmd3")
        let output = builder.render()
        #expect(output == "\(ScriptBuilder.warningLine)\ncmd1 && \\\n  cmd2 && \\\n  cmd3\n")
    }
}

@Suite struct ScriptRecipesTests {
    let env: [String: String] = [:]

    @Test func cdEmitsTouchEchoCd() {
        let cmds = ScriptRecipes.cd(path: "/tries/2026-08-16-foo", env: env)
        #expect(cmds == [
            "touch '/tries/2026-08-16-foo'",
            "echo '/tries/2026-08-16-foo'",
            "cd '/tries/2026-08-16-foo'",
        ])
    }

    @Test func mkdirCdPrependsMkdir() {
        let cmds = ScriptRecipes.mkdirCd(path: "/tries/x", env: env)
        #expect(cmds.first == "mkdir -p '/tries/x'")
        #expect(cmds.count == 4)
    }

    @Test func cloneEmitsMkdirEchoCloneAndCd() {
        let cmds = ScriptRecipes.clone(path: "/tries/x", uri: "https://github.com/tobi/try", env: env)
        #expect(cmds[0] == "mkdir -p '/tries/x'")
        #expect(cmds[1] == "echo 'Using git clone to create this trial from https://github.com/tobi/try.'")
        #expect(cmds[2] == "git clone 'https://github.com/tobi/try' '/tries/x'")
        #expect(cmds[3] == "touch '/tries/x'")
    }

    @Test func clonePREmitsFetchAndDetachedCheckout() {
        let cmds = ScriptRecipes.clonePR(path: "/tries/x", uri: "https://github.com/tobi/try.git", prID: "42", env: env)
        #expect(cmds[2] == "git clone 'https://github.com/tobi/try.git' '/tries/x'")
        #expect(cmds[3] == "git -C '/tries/x' fetch origin 'pull/42/head'")
        #expect(cmds[4] == "git -C '/tries/x' checkout --detach FETCH_HEAD")
    }

    @Test func worktreeWithRepoEmbedsRuntimeCheck() {
        let cmds = ScriptRecipes.worktree(path: "/tries/x", repo: "/repos/foo", currentDirectory: "/cwd", env: env)
        let script = cmds[2]
        #expect(script.contains("git -C '/repos/foo' rev-parse --is-inside-work-tree"))
        #expect(script.contains("worktree add --detach '/tries/x'"))
    }

    @Test func worktreeWithoutRepoUsesBareGitRevParse() {
        let cmds = ScriptRecipes.worktree(path: "/tries/x", repo: nil, currentDirectory: "/cwd", env: env)
        let script = cmds[2]
        #expect(script.contains("if git rev-parse --is-inside-work-tree"))
        #expect(!script.contains("-C"))
    }

    @Test func deleteEmitsTestDirAndRmRfPerEntry() {
        let cmds = ScriptRecipes.delete(
            paths: [(path: "/tries/a", basename: "a"), (path: "/tries/b", basename: "b")],
            basePath: "/tries", currentDirectory: "/cwd"
        )
        #expect(cmds[0] == "cd '/tries'")
        #expect(cmds[1] == "test -d 'a' && rm -rf 'a'")
        #expect(cmds[2] == "test -d 'b' && rm -rf 'b'")
        #expect(cmds[3] == "cd '/cwd' 2>/dev/null || cd '/tries'")
    }

    @Test func graduateUsesGitWorktreeMoveForWorktrees() {
        let cmds = ScriptRecipes.graduate(
            source: "/tries/x", dest: "/projects/x", basename: "x", basePath: "/tries", isWorktree: true, env: env
        )
        #expect(cmds[0] == "git worktree move '/tries/x' '/projects/x'")
        #expect(cmds[1] == "ln -s '/projects/x' '/tries/x'")
    }

    @Test func graduateUsesMvForPlainDirectories() {
        let cmds = ScriptRecipes.graduate(
            source: "/tries/x", dest: "/projects/x", basename: "x", basePath: "/tries", isWorktree: false, env: env
        )
        #expect(cmds[0] == "mv '/tries/x' '/projects/x'")
    }

    @Test func renameEmitsCdMvEchoCd() {
        let cmds = ScriptRecipes.rename(basePath: "/tries", oldName: "old", newName: "new", env: env)
        #expect(cmds[0] == "cd '/tries'")
        #expect(cmds[1] == "mv 'old' 'new'")
        #expect(cmds[2] == "echo '/tries/new'")
        #expect(cmds[3] == "cd '/tries/new'")
    }

    @Test func terminalRenameCommandsEmptyWithoutEnv() {
        #expect(ScriptRecipes.terminalRenameCommands(path: "/tries/2026-08-16-x", env: [:]).isEmpty)
    }

    @Test func terminalRenameCommandsStripsDatePrefixFromLabel() {
        let cmds = ScriptRecipes.terminalRenameCommands(
            path: "/tries/2026-08-16-x",
            env: ["CMUX_SOCKET_PATH": "/tmp/sock"]
        )
        #expect(cmds.count == 1)
        #expect(cmds[0].contains("cmux rename-tab 'try: x'"))
    }

    @Test func terminalRenameCommandsHerdrWithWorkspace() {
        let cmds = ScriptRecipes.terminalRenameCommands(
            path: "/tries/2026-08-16-x",
            env: ["HERDR_ENV": "1", "HERDR_PANE_ID": "abc:p1", "HERDR_WORKSPACE_ID": "ws1"]
        )
        #expect(cmds.count == 2)
        #expect(cmds[0].contains("herdr pane report-metadata 'abc:p1'"))
        #expect(cmds[1].contains("herdr workspace rename 'ws1'"))
    }
}

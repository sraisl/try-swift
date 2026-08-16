import Foundation

/// Port of try.rb's `script_*` and `terminal_rename_commands` functions.
/// Each function is pure — no I/O, no Process calls — returning the exact
/// shell command sequence to be joined by `ScriptBuilder`.
public enum ScriptRecipes {
    /// Mirrors `terminal_rename_commands(path)`: best-effort HERDR/CMUX
    /// terminal-tab-rename integration, kept last in any command sequence so
    /// a missing/broken optional CLI never blocks the directory change.
    public static func terminalRenameCommands(path: String, env: [String: String]) -> [String] {
        let basename = (path as NSString).lastPathComponent
        let name = basename.replacingOccurrences(
            of: #"^\d{4}-\d{2}-\d{2}-"#, with: "", options: .regularExpression
        )
        let label = "try: \(name)"

        if env["HERDR_ENV"] == "1", let paneID = env["HERDR_PANE_ID"], !paneID.isEmpty {
            var commands = [
                "command -v herdr >/dev/null 2>&1 && herdr pane report-metadata "
                    + "\(ShellQuote.posix(paneID)) --source try --title \(ShellQuote.posix(label)) "
                    + ">/dev/null 2>&1 || true"
            ]
            if paneID.hasSuffix(":p1"), let workspaceID = env["HERDR_WORKSPACE_ID"], !workspaceID.isEmpty {
                commands.append(
                    "command -v herdr >/dev/null 2>&1 && herdr workspace rename "
                        + "\(ShellQuote.posix(workspaceID)) \(ShellQuote.posix(label)) >/dev/null 2>&1 || true"
                )
            }
            return commands
        }

        let cmuxSocket = env["CMUX_SOCKET_PATH"], cmuxBundle = env["CMUX_BUNDLE_ID"]
        if (cmuxSocket != nil && !cmuxSocket!.isEmpty) || (cmuxBundle != nil && !cmuxBundle!.isEmpty) {
            return ["command -v cmux >/dev/null 2>&1 && cmux rename-tab \(ShellQuote.posix(label)) >/dev/null 2>&1 || true"]
        }

        return []
    }

    /// Mirrors `script_cd(path)`.
    public static func cd(path: String, env: [String: String]) -> [String] {
        [
            "touch \(ShellQuote.posix(path))",
            "echo \(ShellQuote.posix(path))",
            "cd \(ShellQuote.posix(path))",
        ] + terminalRenameCommands(path: path, env: env)
    }

    /// Mirrors `script_mkdir_cd(path)`.
    public static func mkdirCd(path: String, env: [String: String]) -> [String] {
        ["mkdir -p \(ShellQuote.posix(path))"] + cd(path: path, env: env)
    }

    /// Mirrors `script_clone(path, uri)`.
    public static func clone(path: String, uri: String, env: [String: String]) -> [String] {
        [
            "mkdir -p \(ShellQuote.posix(path))",
            "echo \(ShellQuote.posix("Using git clone to create this trial from \(uri)."))",
            "git clone '\(uri)' \(ShellQuote.posix(path))",
        ] + cd(path: path, env: env)
    }

    /// Mirrors `script_clone_pr(path, uri, pr_id)`.
    public static func clonePR(path: String, uri: String, prID: String, env: [String: String]) -> [String] {
        let ref = "pull/\(prID)/head"
        return [
            "mkdir -p \(ShellQuote.posix(path))",
            "echo \(ShellQuote.posix("Using git clone to create this trial from \(uri) PR #\(prID)."))",
            "git clone \(ShellQuote.posix(uri)) \(ShellQuote.posix(path))",
            "git -C \(ShellQuote.posix(path)) fetch origin \(ShellQuote.posix(ref))",
            "git -C \(ShellQuote.posix(path)) checkout --detach FETCH_HEAD",
        ] + cd(path: path, env: env)
    }

    /// Mirrors `script_worktree(path, repo = nil)`. The `git rev-parse
    /// --is-inside-work-tree` check is embedded in the emitted one-liner and
    /// evaluated later, by the calling shell, in its own cwd — never run by
    /// this binary itself.
    public static func worktree(path: String, repo: String?, currentDirectory: String, env: [String: String]) -> [String] {
        let worktreeCmd: String
        if let repo {
            let r = ShellQuote.posix(repo)
            worktreeCmd =
                "/usr/bin/env sh -c 'if git -C \(r) rev-parse --is-inside-work-tree >/dev/null 2>&1; then "
                + "repo=$(git -C \(r) rev-parse --show-toplevel); "
                + "git -C \"$repo\" worktree add --detach \(ShellQuote.posix(path)) >/dev/null 2>&1 || true; "
                + "fi; exit 0'"
        } else {
            worktreeCmd =
                "/usr/bin/env sh -c 'if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then "
                + "repo=$(git rev-parse --show-toplevel); "
                + "git -C \"$repo\" worktree add --detach \(ShellQuote.posix(path)) >/dev/null 2>&1 || true; "
                + "fi; exit 0'"
        }
        let src = repo ?? currentDirectory
        return [
            "mkdir -p \(ShellQuote.posix(path))",
            "echo \(ShellQuote.posix("Using git worktree to create this trial from \(src)."))",
            worktreeCmd,
        ] + cd(path: path, env: env)
    }

    /// Mirrors `script_delete(paths, base_path)`.
    public static func delete(
        paths: [(path: String, basename: String)], basePath: String, currentDirectory: String
    ) -> [String] {
        var cmds = ["cd \(ShellQuote.posix(basePath))"]
        for item in paths {
            cmds.append("test -d \(ShellQuote.posix(item.basename)) && rm -rf \(ShellQuote.posix(item.basename))")
        }
        cmds.append("cd \(ShellQuote.posix(currentDirectory)) 2>/dev/null || cd \(ShellQuote.posix(basePath))")
        return cmds
    }

    /// Mirrors `script_ascend(source, dest, basename, base_path)`.
    /// `isWorktree` corresponds to Ruby's `File.file?(File.join(source, '.git'))`
    /// (a `.git` *file*, not directory, indicates a worktree) — resolved by the
    /// caller since this function stays I/O-free.
    public static func graduate(
        source: String, dest: String, basename: String, basePath: String, isWorktree: Bool, env: [String: String]
    ) -> [String] {
        let symlinkPath = (basePath as NSString).appendingPathComponent(basename)
        var cmds: [String] = []
        if isWorktree {
            cmds.append("git worktree move \(ShellQuote.posix(source)) \(ShellQuote.posix(dest))")
        } else {
            cmds.append("mv \(ShellQuote.posix(source)) \(ShellQuote.posix(dest))")
        }
        cmds.append("ln -s \(ShellQuote.posix(dest)) \(ShellQuote.posix(symlinkPath))")
        cmds.append("echo \(ShellQuote.posix("Graduated: \(basename) \u{2192} \(dest)"))")
        return cmds + cd(path: dest, env: env)
    }

    /// Mirrors `script_rename(base_path, old_name, new_name)`.
    public static func rename(basePath: String, oldName: String, newName: String, env: [String: String]) -> [String] {
        let newPath = (basePath as NSString).appendingPathComponent(newName)
        return [
            "cd \(ShellQuote.posix(basePath))",
            "mv \(ShellQuote.posix(oldName)) \(ShellQuote.posix(newName))",
            "echo \(ShellQuote.posix(newPath))",
            "cd \(ShellQuote.posix(newPath))",
        ] + terminalRenameCommands(path: newPath, env: env)
    }
}

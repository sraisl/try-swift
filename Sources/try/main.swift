import Foundation
import TryCore
import TryTerminal
import TryGit

let environment = ProcessInfo.processInfo.environment
let arguments = Array(CommandLine.arguments.dropFirst())

let (options, command) = CommandRouter.route(argv: arguments, env: environment)

func printToStdErr(_ text: String) {
    FileHandle.standardError.write(text.data(using: .utf8)!)
}

func emitAndExit(_ commands: [String]) -> Never {
    var builder = ScriptBuilder()
    builder.add(contentsOf: commands)
    print(builder.render(), terminator: "")
    exit(0)
}

func binaryPath() -> String {
    (ProcessInfo.processInfo.arguments.first.map { URL(fileURLWithPath: $0).standardizedFileURL.path }) ?? "/usr/local/bin/try"
}

func runClone(remainingArgs: [String], triesPath: String) -> Never {
    var args = remainingArgs
    guard !args.isEmpty else {
        printToStdErr("Error: git URI required for clone command\n")
        printToStdErr("Usage: try clone <git-uri> [name]\n")
        exit(1)
    }
    let gitURI = args.removeFirst()
    let customName = args.isEmpty ? nil : args.removeFirst()

    guard let dirName = CloneNaming.directoryName(gitURI: gitURI, customName: customName) else {
        printToStdErr("Error: Unable to parse git URI: \(gitURI)\n")
        exit(1)
    }

    let path = (triesPath as NSString).appendingPathComponent(dirName)
    if let pr = GitHubPRURL.parse(gitURI) {
        emitAndExit(ScriptRecipes.clonePR(path: path, uri: pr.cloneURI, prID: pr.prID, env: environment))
    } else {
        emitAndExit(ScriptRecipes.clone(path: path, uri: gitURI, env: environment))
    }
}

func worktreePath(triesPath: String, repoDir: String, customName: String) -> String {
    let base: String
    if !customName.trimmingCharacters(in: .whitespaces).isEmpty {
        base = customName.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
    } else {
        let resolved = (try? FileManager.default.destinationOfSymbolicLink(atPath: repoDir)) ?? repoDir
        base = (resolved as NSString).lastPathComponent
    }
    let datePrefix = DatePrefix.today()
    let fs = SystemFileSystem()
    let resolvedBase = NameResolution.resolveUniqueNameWithVersioning(
        triesPath: triesPath, datePrefix: datePrefix, base: base, exists: fs.exists
    )
    return (triesPath as NSString).appendingPathComponent("\(datePrefix)-\(resolvedBase)")
}

func runWorktree(remainingArgs: [String], triesPath: String) -> Never {
    var args = remainingArgs
    let repo = args.isEmpty ? nil : args.removeFirst()
    let repoDir: String
    if let repo, repo != "dir" {
        repoDir = TryPaths.expandPath(repo)
    } else {
        repoDir = FileManager.default.currentDirectoryPath
    }
    let customName = args.joined(separator: " ")
    let fullPath = worktreePath(triesPath: triesPath, repoDir: repoDir, customName: customName)
    let repoForScript = repoDir == FileManager.default.currentDirectoryPath ? nil : repoDir
    emitAndExit(ScriptRecipes.worktree(path: fullPath, repo: repoForScript, currentDirectory: FileManager.default.currentDirectoryPath, env: environment))
}

func runInit(remainingArgs: [String], triesPath: String) -> Never {
    var args = remainingArgs
    let explicitPath: String? = (args.first?.hasPrefix("/") == true) ? TryPaths.expandPath(args.removeFirst()) : nil
    let defaultPath = triesPath
    let shell: Shell = ShellDetection.isFish(env: environment, parentProcessName: parentProcessName) ? .fish : .bash
    print(InitSnippet.render(shell: shell, binaryPath: binaryPath(), explicitPath: explicitPath, defaultPath: defaultPath), terminator: "")
    exit(0)
}

func runInstall(remainingArgs: [String], triesPath: String) -> Never {
    var args = remainingArgs
    let explicitPath: String? = (args.first?.hasPrefix("/") == true) ? TryPaths.expandPath(args.removeFirst()) : nil
    let defaultPath = triesPath

    guard let shell = ShellDetection.detectShell(env: environment, parentProcessName: parentProcessName) else {
        printToStdErr("Error: could not determine shell config file\n")
        printToStdErr("Your shell was detected as: unknown\n")
        printToStdErr("Run 'try init' and manually add the output to your shell config.\n")
        exit(1)
    }

    let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
    guard let rcFile = ShellDetection.shellRCFile(shell, env: environment, homeDirectory: homeDirectory, fileExists: { FileManager.default.fileExists(atPath: $0) }) else {
        printToStdErr("Error: could not determine shell config file\n")
        printToStdErr("Your shell was detected as: \(shell.rawValue)\n")
        printToStdErr("Run 'try init' and manually add the output to your shell config.\n")
        exit(1)
    }

    let snippet = InitSnippet.render(shell: shell, binaryPath: binaryPath(), explicitPath: explicitPath, defaultPath: defaultPath)
    let rcPath = TryPaths.expandPath(rcFile)

    let marker = "# try shell integration"
    if FileManager.default.fileExists(atPath: rcPath),
       let existing = try? String(contentsOfFile: rcPath, encoding: .utf8),
       existing.contains(marker) {
        printToStdErr("try is already installed in \(rcPath)\n")
        printToStdErr("To reinstall, remove the '# try shell integration' block first.\n")
        exit(0)
    }

    let block = "\n\(marker)\n\(snippet)"

    if FileManager.default.fileExists(atPath: rcPath), !FileManager.default.isWritableFile(atPath: rcPath) {
        printToStdErr("Warning: \(rcPath) is read-only, skipping.\n")
        printToStdErr("Run 'try init' and manually add the output to your shell config.\n")
        exit(1)
    }

    let rcDir = (rcPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: rcDir, withIntermediateDirectories: true)

    if let handle = FileHandle(forWritingAtPath: rcPath) {
        handle.seekToEndOfFile()
        handle.write(block.data(using: .utf8)!)
        handle.closeFile()
    } else {
        FileManager.default.createFile(atPath: rcPath, contents: block.data(using: .utf8))
    }

    printToStdErr("Added try shell integration to \(rcPath)\n")
    if shell == .pwsh {
        printToStdErr("Restart your shell or run: . $PROFILE\n")
    } else {
        printToStdErr("Restart your shell or run: source \(rcPath)\n")
    }
    exit(0)
}

func runDefaultCd(remainingArgs: [String], triesPath: String, options: GlobalOptions) -> Never {
    var args = remainingArgs

    if args.first == "clone" {
        runClone(remainingArgs: Array(args.dropFirst()), triesPath: triesPath)
    }

    if let first = args.first, first.hasPrefix(".") {
        let pathArg = args.removeFirst()
        let custom = args.joined(separator: " ")
        let repoDir = TryPaths.expandPath(pathArg)

        if pathArg == "." && custom.trimmingCharacters(in: .whitespaces).isEmpty {
            printToStdErr("Error: 'try .' requires a name argument\n")
            printToStdErr("Usage: try . <name>\n")
            exit(1)
        }

        let base: String
        if !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            base = custom.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        } else {
            base = (repoDir as NSString).lastPathComponent
        }
        let datePrefix = DatePrefix.today()
        let fs = SystemFileSystem()
        let resolvedBase = NameResolution.resolveUniqueNameWithVersioning(
            triesPath: triesPath, datePrefix: datePrefix, base: base, exists: fs.exists
        )
        let fullPath = (triesPath as NSString).appendingPathComponent("\(datePrefix)-\(resolvedBase)")

        let gitMarker = (repoDir as NSString).appendingPathComponent(".git")
        if FileManager.default.fileExists(atPath: gitMarker) {
            emitAndExit(ScriptRecipes.worktree(path: fullPath, repo: repoDir, currentDirectory: FileManager.default.currentDirectoryPath, env: environment))
        } else {
            emitAndExit(ScriptRecipes.mkdirCd(path: fullPath, env: environment))
        }
    }

    let searchTerm = args.joined(separator: " ")

    if GitURIHeuristic.looksLikeGitURI(args.first) {
        let parts = searchTerm.split(separator: " ", maxSplits: 1).map(String.init)
        let gitURI = parts.first ?? searchTerm
        let customName = parts.count > 1 ? parts[1] : nil

        guard let dirName = CloneNaming.directoryName(gitURI: gitURI, customName: customName) else {
            printToStdErr("Error: Unable to parse git URI: \(gitURI)\n")
            exit(1)
        }
        let fullPath = (triesPath as NSString).appendingPathComponent(dirName)
        if let pr = GitHubPRURL.parse(gitURI) {
            emitAndExit(ScriptRecipes.clonePR(path: fullPath, uri: pr.cloneURI, prID: pr.prID, env: environment))
        } else {
            emitAndExit(ScriptRecipes.clone(path: fullPath, uri: gitURI, env: environment))
        }
    }

    // Interactive picker not wired up yet (lands in Phase 5).
    printToStdErr("try: interactive picker not yet implemented in this build.\n")
    exit(1)
}

switch command {
case .help:
    printToStdErr(HelpText.globalHelp)
    exit(0)
case .version:
    printToStdErr("try \(HelpText.version)\n")
    exit(0)
case .noCommand:
    printToStdErr(HelpText.globalHelp)
    exit(2)
case .clone(let remainingArgs):
    runClone(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .initShell(let remainingArgs):
    runInit(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .install(let remainingArgs):
    runInstall(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .worktree(let remainingArgs):
    runWorktree(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .execClone(let remainingArgs):
    runClone(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .execWorktree(let remainingArgs):
    runWorktree(remainingArgs: remainingArgs, triesPath: options.triesPath)
case .execDefault(let remainingArgs):
    runDefaultCd(remainingArgs: remainingArgs, triesPath: options.triesPath, options: options)
case .defaultCd(let remainingArgs):
    runDefaultCd(remainingArgs: remainingArgs, triesPath: options.triesPath, options: options)
}

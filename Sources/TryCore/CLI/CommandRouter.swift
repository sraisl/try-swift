/// Global CLI flags, extracted before command dispatch (mirrors the top of
/// try.rb's main block, before `command = ARGV.shift`).
public struct GlobalOptions {
    public let triesPath: String
    public let disableColors: Bool
    public let andType: String?
    public let andExit: Bool
    public let andKeysRaw: String?
    public let andConfirm: String?

    public init(
        triesPath: String, disableColors: Bool, andType: String?, andExit: Bool,
        andKeysRaw: String?, andConfirm: String?
    ) {
        self.triesPath = triesPath
        self.disableColors = disableColors
        self.andType = andType
        self.andExit = andExit
        self.andKeysRaw = andKeysRaw
        self.andConfirm = andConfirm
    }
}

/// Mirrors the `case command` / `case sub` dispatch tree at the bottom of try.rb.
public enum ParsedCommand: Equatable {
    case help
    case version
    case clone(remainingArgs: [String])
    case initShell(remainingArgs: [String])
    case install(remainingArgs: [String])
    case worktree(remainingArgs: [String])
    case execClone(remainingArgs: [String])
    case execWorktree(remainingArgs: [String])
    case execDefault(remainingArgs: [String])
    /// No command given at all -> print help, exit 2 (distinct from `.help`,
    /// which exits 0 - mirrors upstream's `when nil` branch).
    case noCommand
    /// Any other token: default cd/search path, with the token itself
    /// unshifted back onto the args (mirrors `ARGV.unshift(command)`).
    case defaultCd(remainingArgs: [String])
}

public enum CommandRouter {
    /// Mirrors try.rb's top-level ARGV processing, in order:
    /// 1. `--no-colors`/`--no-expand-tokens` (color disabling)
    /// 2. `--help`/`-h` anywhere -> help, short-circuits everything else
    /// 3. `--version`/`-v` anywhere -> version, short-circuits everything else
    /// 4. `--path` extraction (falls back to TRY_PATH env, then ~/src/tries)
    /// 5. hidden `--and-*` test flags
    /// 6. command = first remaining token; dispatch per `ParsedCommand`
    public static func route(argv: [String], env: [String: String]) -> (GlobalOptions, ParsedCommand) {
        var args = RawArguments(argv)

        let disableColorsFlag1 = args.extractFlag("--no-colors")
        let disableColorsFlag2 = args.extractFlag("--no-expand-tokens")
        let noColorEnv = !(env["NO_COLOR"] ?? "").isEmpty
        let disableColors = disableColorsFlag1 || disableColorsFlag2 || noColorEnv

        if args.containsAny(["--help", "-h"]) {
            return (
                GlobalOptions(triesPath: "", disableColors: disableColors, andType: nil, andExit: false, andKeysRaw: nil, andConfirm: nil),
                .help
            )
        }
        if args.containsAny(["--version", "-v"]) {
            return (
                GlobalOptions(triesPath: "", disableColors: disableColors, andType: nil, andExit: false, andKeysRaw: nil, andConfirm: nil),
                .version
            )
        }

        let explicitPath = args.extractOption("--path")
        let triesPath = TryPaths.resolveTriesPath(explicitPath: explicitPath, env: env)

        let andType = args.extractOption("--and-type")
        let andExit = args.extractFlag("--and-exit")
        let andKeysRaw = args.extractOption("--and-keys")
        let andConfirm = args.extractOption("--and-confirm")

        let options = GlobalOptions(
            triesPath: triesPath, disableColors: disableColors, andType: andType,
            andExit: andExit, andKeysRaw: andKeysRaw, andConfirm: andConfirm
        )

        let command = args.shift()

        switch command {
        case nil:
            return (options, .noCommand)
        case "clone":
            return (options, .clone(remainingArgs: args.tokens))
        case "init":
            return (options, .initShell(remainingArgs: args.tokens))
        case "install":
            return (options, .install(remainingArgs: args.tokens))
        case "exec":
            var execArgs = args
            let sub = execArgs.tokens.first
            switch sub {
            case "clone":
                _ = execArgs.shift()
                return (options, .execClone(remainingArgs: execArgs.tokens))
            case "worktree":
                _ = execArgs.shift()
                return (options, .execWorktree(remainingArgs: execArgs.tokens))
            case "cd":
                _ = execArgs.shift()
                return (options, .execDefault(remainingArgs: execArgs.tokens))
            default:
                return (options, .execDefault(remainingArgs: execArgs.tokens))
            }
        case "worktree":
            return (options, .worktree(remainingArgs: args.tokens))
        case let .some(other):
            var remaining = args.tokens
            remaining.insert(other, at: 0)
            return (options, .defaultCd(remainingArgs: remaining))
        }
    }
}

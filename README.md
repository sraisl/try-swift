# try

A native macOS/Swift rewrite of [tobi/try](https://github.com/tobi/try) — keeps every throwaway
experiment directory under one root (`~/src/tries` by default), auto-named `YYYY-MM-DD-name`, with
an interactive fuzzy-search picker to jump to or create them instantly. Also supports `git clone`,
`git worktree`, GitHub PR checkout, and "graduating" a try into a real project directory.

This is a from-scratch Swift port aiming for 1:1 behavioral parity with the original Ruby tool,
built with zero external dependencies (no `swift-argument-parser`, no TUI library — raw
`termios`/ANSI on Darwin).

## Install

### Swift Package Manager

```bash
swift build -c release
```

The binary lands at `.build/release/try`. Copy it into your `PATH`, or:

```bash
make install
```

### Homebrew

```bash
brew install --build-from-source ./Formula/try.rb
```

## Shell setup

`try` is a normal subprocess and can't `cd` your shell directly, so it needs a small shell
function that captures its output and `eval`s it:

```bash
# bash/zsh (~/.bashrc or ~/.zshrc)
eval "$(try init ~/src/tries)"

# fish (~/.config/fish/config.fish)
eval (try init ~/src/tries | string collect)
```

Or let `try install` do this for you automatically:

```bash
try install
```

## Usage

```
try                                  # launch interactive picker
try <query>                          # picker pre-filtered by query
try clone <git-uri> [name]           # clone repo into a dated directory
try <git-uri>                        # shorthand for clone
try <github-pr-url>                  # clone + checkout a PR, detached HEAD
try .  [name]                        # create a dated git worktree from cwd (or plain mkdir)
try worktree dir [name]              # explicit worktree form
try init [path]                      # print the shell wrapper function
try install                          # install the wrapper into your shell rc file
```

### Keyboard (interactive picker)

| Key                        | Action                                   |
| -------------------------- | ---------------------------------------- |
| `↑`/`↓`, `Ctrl-P`/`Ctrl-N` | Navigate                                 |
| Enter                      | Select / create new                      |
| Ctrl-R                     | Rename                                   |
| Ctrl-G                     | Graduate (promote try to a real project) |
| Ctrl-D                     | Mark for deletion (batch)                |
| Ctrl-T                     | Create new try immediately               |
| Esc                        | Cancel                                   |

### Environment

- `TRY_PATH` — tries directory (default `~/src/tries`)
- `TRY_PROJECTS` — graduate destination (default: parent of `TRY_PATH`)

## Development

```bash
make build             # swift build -c release
make test               # swift test
make test-acceptance    # black-box tests against the built binary
```

Package layout:

- `Sources/TryCore` — pure logic (fuzzy matching, shell-script generation, git URI parsing,
  name resolution, CLI argument routing) with no terminal or process dependencies.
- `Sources/TryTerminal` — the TUI: raw-mode terminal handling, ANSI rendering, and the
  interactive picker's state machine.
- `Sources/TryGit` — reserved for future git introspection; the current port emits all git
  operations as shell commands (matching upstream), so this stays minimal.
- `Sources/try` — the executable entry point.
- `AcceptanceTests/` — black-box shell tests against the built binary, driven by hidden
  `--and-type`/`--and-exit`/`--and-keys`/`--and-confirm` flags that script the TUI
  non-interactively (mirrors upstream's own `spec/tests/*.sh` approach).

Open `Package.swift` directly in Xcode for development — no separate `.xcodeproj` needed.

## License

MIT. Based on [tobi/try](https://github.com/tobi/try), also MIT licensed.

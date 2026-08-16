/// Collects a sequence of shell commands and renders them as a single script
/// meant to be `eval`'d by the calling shell. Mirrors try.rb's `emit_script`.
public struct ScriptBuilder {
    public static let warningLine =
        "# if you can read this, you didn't launch try from an alias. run try --help."

    private var commands: [String] = []

    public init() {}

    public mutating func add(_ command: String) {
        commands.append(command)
    }

    public mutating func add(contentsOf newCommands: [String]) {
        commands.append(contentsOf: newCommands)
    }

    /// Joins commands with " && \\\n  " continuations, warning comment first.
    public func render() -> String {
        var out = Self.warningLine + "\n"
        for (i, cmd) in commands.enumerated() {
            out += (i == 0 ? cmd : "  \(cmd)")
            out += (i < commands.count - 1) ? " && \\\n" : "\n"
        }
        return out
    }
}

import Foundation

/// Port of try.rb's `detect_shell`, `shell_rc_file`, and `fish?`.
/// The `parentProcessName` closure exists so callers can inject a `ps`-based
/// lookup (the one legitimate Process-touching exception in TryCore, see
/// Sources/try/ParentProcessName.swift) without this module depending on
/// Foundation.Process directly.
public enum ShellDetection {
    public static func detectShell(env: [String: String], parentProcessName: () -> String?) -> Shell? {
        let shellEnv = env["SHELL"] ?? ""
        if shellEnv.contains("fish") { return .fish }
        if shellEnv.contains("zsh") { return .zsh }
        if shellEnv.contains("bash") { return .bash }

        if let psModulePath = env["PSModulePath"], !psModulePath.isEmpty {
            return .pwsh
        }

        let parent = parentProcessName() ?? ""
        if parent.contains("fish") { return .fish }
        if parent.contains("zsh") { return .zsh }
        if parent.contains("bash") { return .bash }
        if parent.range(of: "pwsh|powershell", options: [.regularExpression, .caseInsensitive]) != nil {
            return .pwsh
        }

        return nil
    }

    /// Mirrors `fish?`: checks $SHELL first, falls back to parent process name
    /// only when $SHELL is empty. Used by `try init` (which defaults to
    /// fish-or-bash, unlike `install`'s full 4-way detection).
    public static func isFish(env: [String: String], parentProcessName: () -> String?) -> Bool {
        var shell = env["SHELL"] ?? ""
        if shell.isEmpty {
            shell = parentProcessName() ?? ""
        }
        return shell.contains("fish")
    }

    public static func shellRCFile(_ shell: Shell, env: [String: String], homeDirectory: String, fileExists: (String) -> Bool) -> String? {
        switch shell {
        case .fish:
            return "~/.config/fish/config.fish"
        case .zsh:
            return "~/.zshrc"
        case .bash:
            let bashrc = (homeDirectory as NSString).appendingPathComponent(".bashrc")
            return fileExists(bashrc) ? "~/.bashrc" : "~/.bash_profile"
        case .pwsh:
            if let profile = env["PROFILE"], !profile.isEmpty {
                return profile
            }
            #if os(Windows)
            let userProfile = env["USERPROFILE"] ?? homeDirectory
            return (((userProfile as NSString).appendingPathComponent("Documents") as NSString)
                .appendingPathComponent("PowerShell") as NSString)
                .appendingPathComponent("Microsoft.PowerShell_profile.ps1")
            #else
            return (((homeDirectory as NSString).appendingPathComponent(".config") as NSString)
                .appendingPathComponent("powershell") as NSString)
                .appendingPathComponent("Microsoft.PowerShell_profile.ps1")
            #endif
        }
    }
}

import Foundation

/// Resolves TRY_PATH / TRY_PROJECTS from env + --path override, matching
/// try.rb's TrySelector::TRY_PATH default (~/src/tries) and TRY_PROJECTS
/// default (parent directory of TRY_PATH).
public enum TryPaths {
    public static func resolveTriesPath(explicitPath: String?, env: [String: String]) -> String {
        let raw = explicitPath ?? env["TRY_PATH"] ?? "~/src/tries"
        return expandPath(raw)
    }

    public static func resolveProjectsPath(triesPath: String, env: [String: String]) -> String {
        if let explicit = env["TRY_PROJECTS"] {
            return expandPath(explicit)
        }
        return (triesPath as NSString).deletingLastPathComponent
    }

    public static func expandPath(_ path: String) -> String {
        let expanded = (path as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return (expanded as NSString).standardizingPath
        }
        let cwd = FileManager.default.currentDirectoryPath
        return ((cwd as NSString).appendingPathComponent(expanded) as NSString).standardizingPath
    }
}

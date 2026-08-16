import Foundation

/// Directory-name collision resolution, ported 1:1 from try.rb's
/// `unique_dir_name` and `resolve_unique_name_with_versioning`.
///
/// `exists` is injected (rather than calling FileManager directly) so this
/// stays pure and unit-testable without touching disk.
public enum NameResolution {
    /// Mirrors `unique_dir_name(tries_path, dir_name)`: append "-2", "-3", ...
    /// until the candidate (joined under `triesPath`) doesn't exist.
    public static func uniqueDirName(
        triesPath: String, dirName: String, exists: (String) -> Bool
    ) -> String {
        var candidate = dirName
        var i = 2
        while exists((triesPath as NSString).appendingPathComponent(candidate)) {
            candidate = "\(dirName)-\(i)"
            i += 1
        }
        return candidate
    }

    /// Mirrors `resolve_unique_name_with_versioning(tries_path, date_prefix, base)`.
    ///
    /// NOTE the exact upstream return-value shape (easy to get wrong):
    /// - if `date_prefix-base` doesn't exist yet: returns `base` alone (NOT
    ///   prefixed with the date - the caller re-adds the prefix).
    /// - if `base` ends in digits: returns the bumped base alone (e.g. "foo3"),
    ///   again without the date prefix.
    /// - otherwise: returns `unique_dir_name` applied to the full
    ///   "date_prefix-base" name, with the date prefix stripped back off.
    public static func resolveUniqueNameWithVersioning(
        triesPath: String, datePrefix: String, base: String, exists: (String) -> Bool
    ) -> String {
        let initial = "\(datePrefix)-\(base)"
        guard exists((triesPath as NSString).appendingPathComponent(initial)) else {
            return base
        }

        if let trailingDigitsRange = base.range(of: #"\d+$"#, options: .regularExpression) {
            let stem = String(base[base.startIndex..<trailingDigitsRange.lowerBound])
            let n = Int(base[trailingDigitsRange]) ?? 0
            var candidateNum = n + 1
            while true {
                let candidateBase = "\(stem)\(candidateNum)"
                let candidateFull = (triesPath as NSString)
                    .appendingPathComponent("\(datePrefix)-\(candidateBase)")
                if !exists(candidateFull) {
                    return candidateBase
                }
                candidateNum += 1
            }
        }

        let fullUnique = uniqueDirName(triesPath: triesPath, dirName: initial, exists: exists)
        let prefixToStrip = "\(datePrefix)-"
        return fullUnique.hasPrefix(prefixToStrip) ? String(fullUnique.dropFirst(prefixToStrip.count)) : fullUnique
    }
}

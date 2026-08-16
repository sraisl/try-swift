import Foundation

/// Port of try.rb's `load_all_tries`.
public enum TryDirectoryLoader {
    static let datePrefixPattern = #"^\d{4}-\d{2}-\d{2}-"#

    /// Loads all try directories under `basePath`.
    /// - Skips dotfiles/dot-directories (leading `.`).
    /// - Only includes directories (or symlinks to directories).
    /// - baseScore = 3.0/sqrt(hoursSinceAccess+1) + (2.0 if name matches ^\d{4}-\d{2}-\d{2}-)
    public static func load(
        basePath: String, now: Date = Date(), fs: FileSystemProviding = SystemFileSystem()
    ) -> [TryEntry] {
        let names = fs.listDirectory(basePath)
        var entries: [TryEntry] = []
        entries.reserveCapacity(names.count)

        for name in names {
            if name.hasPrefix(".") { continue }

            let entryPath = (basePath as NSString).appendingPathComponent(name)
            let isSymlink = fs.isSymlink(entryPath)
            let resolvedPath = isSymlink ? fs.realpath(entryPath) : entryPath

            guard fs.isDirectory(isSymlink ? resolvedPath : entryPath) else { continue }

            let mtime = fs.modificationDate(entryPath)
            let ctime = fs.creationDate(entryPath)

            let hoursSinceAccess = max(now.timeIntervalSince(mtime), 0) / 3600.0
            var baseScore = 3.0 / (hoursSinceAccess + 1).squareRoot()
            if name.range(of: datePrefixPattern, options: .regularExpression) != nil {
                baseScore += 2.0
            }

            entries.append(
                TryEntry(
                    basename: name,
                    path: resolvedPath,
                    isSymlink: isSymlink,
                    mtime: mtime,
                    ctime: ctime,
                    baseScore: baseScore
                )
            )
        }

        return entries
    }
}

import Foundation

public struct TryEntry: Sendable, Equatable {
    /// Directory name as listed (symlink's own name if this entry is a symlink).
    public let basename: String
    /// Resolved path (realpath if symlink, else basePath/basename).
    public let path: String
    public let isSymlink: Bool
    public let mtime: Date
    public let ctime: Date
    /// Computed once at load time: recency score + date-prefix bonus.
    public let baseScore: Double

    public init(basename: String, path: String, isSymlink: Bool, mtime: Date, ctime: Date, baseScore: Double) {
        self.basename = basename
        self.path = path
        self.isSymlink = isSymlink
        self.mtime = mtime
        self.ctime = ctime
        self.baseScore = baseScore
    }
}

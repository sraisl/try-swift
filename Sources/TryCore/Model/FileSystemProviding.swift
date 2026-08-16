import Foundation

/// Abstraction over filesystem reads needed by TryDirectoryLoader, so
/// TryCoreTests can inject a fake filesystem instead of touching disk.
public protocol FileSystemProviding {
    /// Names of entries directly inside `path` (no leading-dot filtering here —
    /// that's the loader's job, mirroring Ruby's Dir.foreach + explicit skip).
    func listDirectory(_ path: String) -> [String]
    func isDirectory(_ path: String) -> Bool
    func isSymlink(_ path: String) -> Bool
    func realpath(_ path: String) -> String
    func modificationDate(_ path: String) -> Date
    func creationDate(_ path: String) -> Date
    func exists(_ path: String) -> Bool
}

public struct SystemFileSystem: FileSystemProviding {
    public init() {}

    public func listDirectory(_ path: String) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: path)) ?? []
    }

    public func isDirectory(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
        return exists && isDir.boolValue
    }

    public func isSymlink(_ path: String) -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.type] as? FileAttributeType) == .typeSymbolicLink
    }

    public func realpath(_ path: String) -> String {
        (try? FileManager.default.destinationOfSymbolicLink(atPath: path)).map { dest in
            dest.hasPrefix("/") ? dest : ((path as NSString).deletingLastPathComponent as NSString).appendingPathComponent(dest)
        } ?? path
    }

    public func modificationDate(_ path: String) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.modificationDate] as? Date) ?? Date(timeIntervalSince1970: 0)
    }

    public func creationDate(_ path: String) -> Date {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        return (attrs?[.creationDate] as? Date) ?? Date(timeIntervalSince1970: 0)
    }

    public func exists(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }
}

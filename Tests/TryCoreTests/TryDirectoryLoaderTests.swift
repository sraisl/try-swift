import Testing
import Foundation
@testable import TryCore

final class FakeFileSystem: FileSystemProviding {
    var directories: [String: [String]] = [:]
    var isDirByPath: [String: Bool] = [:]
    var symlinksByPath: Set<String> = []
    var realpathByPath: [String: String] = [:]
    var mtimeByPath: [String: Date] = [:]
    var ctimeByPath: [String: Date] = [:]
    var existsByPath: Set<String> = []

    func listDirectory(_ path: String) -> [String] { directories[path] ?? [] }
    func isDirectory(_ path: String) -> Bool { isDirByPath[path] ?? false }
    func isSymlink(_ path: String) -> Bool { symlinksByPath.contains(path) }
    func realpath(_ path: String) -> String { realpathByPath[path] ?? path }
    func modificationDate(_ path: String) -> Date { mtimeByPath[path] ?? Date(timeIntervalSince1970: 0) }
    func creationDate(_ path: String) -> Date { ctimeByPath[path] ?? Date(timeIntervalSince1970: 0) }
    func exists(_ path: String) -> Bool { existsByPath.contains(path) }
}

@Suite struct TryDirectoryLoaderTests {
    @Test func skipsDotfiles() {
        let fs = FakeFileSystem()
        fs.directories["/tries"] = [".git", "regular"]
        fs.isDirByPath["/tries/.git"] = true
        fs.isDirByPath["/tries/regular"] = true

        let entries = TryDirectoryLoader.load(basePath: "/tries", now: Date(), fs: fs)
        #expect(entries.map(\.basename) == ["regular"])
    }

    @Test func skipsNonDirectories() {
        let fs = FakeFileSystem()
        fs.directories["/tries"] = ["file.txt", "dir1"]
        fs.isDirByPath["/tries/file.txt"] = false
        fs.isDirByPath["/tries/dir1"] = true

        let entries = TryDirectoryLoader.load(basePath: "/tries", now: Date(), fs: fs)
        #expect(entries.map(\.basename) == ["dir1"])
    }

    @Test func datePrefixedNameGetsScoreBonus() {
        let fs = FakeFileSystem()
        fs.directories["/tries"] = ["2026-08-16-dated", "undated"]
        fs.isDirByPath["/tries/2026-08-16-dated"] = true
        fs.isDirByPath["/tries/undated"] = true
        let now = Date()
        fs.mtimeByPath["/tries/2026-08-16-dated"] = now
        fs.mtimeByPath["/tries/undated"] = now

        let entries = TryDirectoryLoader.load(basePath: "/tries", now: now, fs: fs)
        let dated = entries.first { $0.basename == "2026-08-16-dated" }!
        let undated = entries.first { $0.basename == "undated" }!
        #expect(dated.baseScore - undated.baseScore == 2.0)
    }

    @Test func symlinkResolvesRealpathButKeepsDisplayName() {
        let fs = FakeFileSystem()
        fs.directories["/tries"] = ["link"]
        fs.symlinksByPath.insert("/tries/link")
        fs.realpathByPath["/tries/link"] = "/real/target"
        fs.isDirByPath["/real/target"] = true

        let entries = TryDirectoryLoader.load(basePath: "/tries", now: Date(), fs: fs)
        #expect(entries.count == 1)
        #expect(entries[0].basename == "link")
        #expect(entries[0].path == "/real/target")
        #expect(entries[0].isSymlink)
    }

    @Test func recencyAffectsBaseScore() {
        let fs = FakeFileSystem()
        fs.directories["/tries"] = ["recent", "old"]
        fs.isDirByPath["/tries/recent"] = true
        fs.isDirByPath["/tries/old"] = true
        let now = Date()
        fs.mtimeByPath["/tries/recent"] = now
        fs.mtimeByPath["/tries/old"] = now.addingTimeInterval(-100 * 3600)

        let entries = TryDirectoryLoader.load(basePath: "/tries", now: now, fs: fs)
        let recent = entries.first { $0.basename == "recent" }!
        let old = entries.first { $0.basename == "old" }!
        #expect(recent.baseScore > old.baseScore)
    }
}

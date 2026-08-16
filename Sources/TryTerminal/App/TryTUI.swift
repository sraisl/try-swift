import Darwin
import Foundation
import TryCore

/// Port of try.rb's `TrySelector`. A stateful class driving a blocking
/// terminal loop, mirroring the original's imperative structure (including
/// nested sub-loops for the rename/graduate/delete-confirm dialogs) rather
/// than a purely functional reducer, since that's how the original actually
/// behaves and behavioral parity matters more than architectural purity here.
/// `@unchecked Sendable`: the only cross-thread access is the WinchWatcher
/// handler setting `needsRedraw = true` from a GCD queue - a single Bool
/// write with no other cross-thread mutation, safe in this single-process
/// CLI where the main loop treats it as level-triggered (not read-clear
/// atomically). Everything else runs single-threaded on the main loop.
public final class TryTUI: @unchecked Sendable {
    let basePath: String
    var searchField: InputFieldState
    var cursorPos = 0
    var scrollOffset = 0
    var selected: TUIAction?
    var allTries: [TryEntry]?
    var deleteStatus: String?
    var deleteMode = false
    var markedForDeletion: [String] = []
    var needsRedraw = false
    var terminalRestored = false

    var lastQuery: String?
    var cachedResults: [FuzzyMatch<TryEntry>]?

    let testRenderOnce: Bool
    let testNoCls: Bool
    var testKeys: [String]?
    let testHadKeys: Bool
    let testConfirm: String?

    let keyReader = KeyReader()
    var winchWatcher: WinchWatcher?
    let env: [String: String]

    // MARK: - Snapshot accessors used by the Render extension (same module).
    var searchFieldSnapshot: InputFieldState { searchField }
    var deleteStatusSnapshot: String? { deleteStatus }
    var deleteModeSnapshot: Bool { deleteMode }
    var markedForDeletionSnapshot: [String] { markedForDeletion }
    var markedForDeletionCountSnapshot: Int { markedForDeletion.count }
    var scrollOffsetSnapshot: Int { scrollOffset }
    var cursorPosSnapshot: Int { cursorPos }

    func clearDeleteStatus() { deleteStatus = nil }

    func adjustScrollOffset(maxVisible: Int, totalItems: Int) {
        if cursorPos < scrollOffset {
            scrollOffset = cursorPos
        } else if cursorPos >= scrollOffset + maxVisible {
            scrollOffset = cursorPos - maxVisible + 1
        }
        _ = totalItems
    }

    public init(
        searchTerm: String,
        basePath: String,
        initialInput: String?,
        testRenderOnce: Bool,
        testNoCls: Bool,
        testKeys: [String]?,
        testConfirm: String?,
        env: [String: String]
    ) {
        self.basePath = basePath
        let normalizedSearchTerm = searchTerm.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        let initialText = initialInput.map { $0.replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression) } ?? normalizedSearchTerm
        self.searchField = InputFieldState(placeholder: "", text: initialText)
        self.testRenderOnce = testRenderOnce
        self.testNoCls = testNoCls
        self.testKeys = testKeys
        self.testHadKeys = !(testKeys?.isEmpty ?? true)
        self.testConfirm = testConfirm
        self.env = env

        if !FileManager.default.fileExists(atPath: basePath) {
            try? FileManager.default.createDirectory(atPath: basePath, withIntermediateDirectories: true)
        }
    }

    public func run() -> TUIAction? {
        setupTerminal()
        defer { restoreTerminal() }

        if testRenderOnce && (testKeys?.isEmpty ?? true) {
            let tries = getTries()
            render(tries: tries)
            return nil
        }

        let hasTTY = isatty(STDIN_FILENO) != 0 && isatty(STDERR_FILENO) != 0
        if !hasTTY {
            guard !(testKeys?.isEmpty ?? true) else {
                FileHandle.standardError.write("Error: try requires an interactive terminal\n".data(using: .utf8)!)
                return nil
            }
            mainLoop()
        } else {
            guard let rawMode = RawModeGuard() else {
                mainLoop()
                return selected
            }
            mainLoop()
            rawMode.restore()
        }

        return selected
    }

    // MARK: - Terminal setup/teardown

    private func setupTerminal() {
        terminalRestored = false
        if !testNoCls {
            let text = ANSI.altScreenOn + ANSI.setTitle("try") + ANSI.cursorBlink
            writeStdErr(text)
        }
        winchWatcher = WinchWatcher { [weak self] in
            self?.needsRedraw = true
        }
    }

    private func restoreTerminal() {
        guard !terminalRestored else { return }
        terminalRestored = true
        if !testNoCls {
            writeStdErr(ANSI.reset)
            writeStdErr(ANSI.cursorDefault)
            writeStdErr(ANSI.altScreenOff)
        }
        winchWatcher?.cancel()
        winchWatcher = nil
    }

    private func writeStdErr(_ text: String) {
        FileHandle.standardError.write(text.data(using: .utf8)!)
    }

    // MARK: - Data loading

    private func loadAllTries() -> [TryEntry] {
        if let allTries { return allTries }
        let tries = TryDirectoryLoader.load(basePath: basePath)
        allTries = tries
        return tries
    }

    private func getTries() -> [FuzzyMatch<TryEntry>] {
        let tries = loadAllTries()

        if lastQuery == searchField.text, let cachedResults {
            return cachedResults
        }

        lastQuery = searchField.text
        let (rows, _) = TerminalSize.current(env: env)
        let maxResults = max(rows - 6, 3)

        let fuzzyEntries = tries.map { FuzzyEntry(data: $0, text: $0.basename, baseScore: $0.baseScore) }
        let matcher = FuzzyMatcher(entries: fuzzyEntries)
        let results = matcher.match(searchField.text, limit: maxResults)
        cachedResults = results
        return results
    }

    private func invalidateCache() {
        allTries = nil
        cachedResults = nil
        lastQuery = nil
    }

    // MARK: - Main loop

    private func mainLoop() {
        while true {
            let tries = getTries()
            let showCreateNew = !searchField.text.isEmpty
            let totalItems = tries.count + (showCreateNew ? 1 : 0)

            cursorPos = max(min(cursorPos, max(totalItems - 1, 0)), 0)

            render(tries: tries)

            guard let key = readKey() else { continue }

            let before = searchField.text
            if searchField.handleKey(key) {
                if searchField.text != before { cursorPos = 0 }
                continue
            }

            switch key {
            case "\r":
                if deleteMode, !markedForDeletion.isEmpty {
                    confirmBatchDelete(tries: tries)
                    if selected != nil { return }
                } else if cursorPos < tries.count {
                    handleSelection(tries[cursorPos].data)
                    if selected != nil { return }
                } else if showCreateNew {
                    handleCreateNew()
                    if selected != nil { return }
                }
            case "\u{1B}[A", "\u{10}":
                cursorPos = max(cursorPos - 1, 0)
            case "\u{1B}[B", "\u{0E}":
                cursorPos = min(cursorPos + 1, totalItems - 1)
            case "\u{04}":
                if cursorPos < tries.count {
                    let path = tries[cursorPos].data.path
                    if let idx = markedForDeletion.firstIndex(of: path) {
                        markedForDeletion.remove(at: idx)
                    } else {
                        markedForDeletion.append(path)
                        deleteMode = true
                    }
                    if markedForDeletion.isEmpty { deleteMode = false }
                }
            case "\u{14}":
                handleCreateNew()
                if selected != nil { return }
            case "\u{12}":
                if cursorPos < tries.count {
                    runRenameDialog(tries[cursorPos].data)
                    if selected != nil { return }
                }
            case "\u{07}":
                if cursorPos < tries.count {
                    runAscendDialog(tries[cursorPos].data)
                    if selected != nil { return }
                }
            case "\u{03}", "\u{1B}":
                if deleteMode {
                    markedForDeletion.removeAll()
                    deleteMode = false
                } else {
                    selected = .cancel
                    return
                }
            default:
                break
            }
        }
    }

    private func readKey() -> String? {
        if let testKeys, !testKeys.isEmpty {
            self.testKeys?.removeFirst()
            return testKeys.first ?? nil
        }
        if testHadKeys, let testKeys, testKeys.isEmpty {
            return "\u{1B}"
        }

        while true {
            if needsRedraw {
                needsRedraw = false
                if !testNoCls { clearScreen() }
                return nil
            }
            var pfd = pollfd(fd: STDIN_FILENO, events: Int16(POLLIN), revents: 0)
            let ready = poll(&pfd, 1, 100)
            if ready > 0 {
                return keyReader.readKeypress()
            }
        }
    }

    private func clearScreen() {
        writeStdErr("\u{1B}[2J\u{1B}[H")
    }

    private func showCursor() {
        writeStdErr(ANSI.show)
    }

    private func hideCursor() {
        writeStdErr(ANSI.hide)
    }

    // MARK: - Selection / creation

    private func handleSelection(_ entry: TryEntry) {
        selected = .cd(path: entry.path)
    }

    private func handleCreateNew() {
        let datePrefix = DatePrefix.today()

        if !searchField.text.isEmpty {
            let finalName = "\(datePrefix)-\(searchField.text)".replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
            let fullPath = (basePath as NSString).appendingPathComponent(finalName)
            selected = .mkdir(path: fullPath)
            return
        }

        if !testNoCls { clearScreen() }
        showCursor()
        writeStdErr("Enter new try name\n\n> \(datePrefix)-")

        let entry = readCookedLine()
        hideCursor()

        guard let entry, !entry.isEmpty else { return }

        let finalName = "\(datePrefix)-\(entry)".replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        let fullPath = (basePath as NSString).appendingPathComponent(finalName)
        selected = .mkdir(path: fullPath)
    }

    private func readCookedLine() -> String? {
        var line = ""
        while true {
            var byte: UInt8 = 0
            let n = read(STDIN_FILENO, &byte, 1)
            if n <= 0 { break }
            if byte == UInt8(ascii: "\n") { break }
            if byte == UInt8(ascii: "\r") { continue }
            line.append(Character(UnicodeScalar(byte)))
        }
        return line
    }

    // MARK: - Rename dialog

    private func runRenameDialog(_ entry: TryEntry) {
        deleteMode = false
        markedForDeletion.removeAll()

        let currentName = entry.basename
        var input = InputFieldState(placeholder: "", text: currentName)
        var renameError: String?

        while true {
            renderRenameDialog(currentName: currentName, buffer: input.text, cursor: input.cursor, error: renameError)

            guard let key = readKey() else { continue }
            let before = input.text
            if input.handleKey(key) {
                if input.text != before { renameError = nil }
                continue
            }

            switch key {
            case "\r":
                let result = finalizeRename(entry: entry, buffer: input.text)
                if case .success = result {
                    return
                } else if case .failure(let message) = result {
                    renameError = message
                }
            case "\u{1B}", "\u{03}":
                needsRedraw = true
                return
            default:
                break
            }
        }
    }

    private enum DialogResult {
        case success
        case failure(String)
    }

    private func finalizeRename(entry: TryEntry, buffer: String) -> DialogResult {
        let newName = buffer.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: #"\s+"#, with: "-", options: .regularExpression)
        let oldName = entry.basename

        if newName.isEmpty { return .failure("Name cannot be empty") }
        if newName.contains("/") { return .failure("Name cannot contain /") }
        if newName == oldName {
            needsRedraw = true
            return .success
        }
        let targetPath = (basePath as NSString).appendingPathComponent(newName)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: targetPath, isDirectory: &isDir), isDir.boolValue {
            return .failure("Directory exists: \(newName)")
        }

        selected = .rename(basePath: basePath, old: oldName, new: newName)
        needsRedraw = true
        return .success
    }

    // MARK: - Ascend/graduate dialog

    private func runAscendDialog(_ entry: TryEntry) {
        deleteMode = false
        markedForDeletion.removeAll()

        let currentName = entry.basename
        let projectName = currentName.replacingOccurrences(of: #"^\d{4}-\d{2}-\d{2}-"#, with: "", options: .regularExpression)
        let projectsDir = TryPaths.resolveProjectsPath(triesPath: basePath, env: env)

        var input = InputFieldState(placeholder: "", text: (projectsDir as NSString).appendingPathComponent(projectName))
        var ascendError: String?

        while true {
            renderAscendDialog(currentName: currentName, buffer: input.text, cursor: input.cursor, error: ascendError, projectsDir: projectsDir)

            guard let key = readKey() else { continue }
            let before = input.text
            if input.handleKey(key) {
                if input.text != before { ascendError = nil }
                continue
            }

            switch key {
            case "\r":
                let result = finalizeAscend(entry: entry, buffer: input.text)
                if case .success = result {
                    return
                } else if case .failure(let message) = result {
                    ascendError = message
                }
            case "\u{1B}", "\u{03}":
                needsRedraw = true
                return
            default:
                break
            }
        }
    }

    private func finalizeAscend(entry: TryEntry, buffer: String) -> DialogResult {
        let dest = TryPaths.expandPath(buffer.trimmingCharacters(in: .whitespaces))

        if dest.isEmpty { return .failure("Destination cannot be empty") }
        if FileManager.default.fileExists(atPath: dest) { return .failure("Destination already exists: \(dest)") }

        let parent = (dest as NSString).deletingLastPathComponent
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent, isDirectory: &isDir), isDir.boolValue else {
            return .failure("Parent directory does not exist: \(parent)")
        }

        selected = .ascend(source: entry.path, dest: dest, basename: entry.basename, basePath: basePath)
        needsRedraw = true
        return .success
    }

    // MARK: - Delete confirmation

    private func confirmBatchDelete(tries: [FuzzyMatch<TryEntry>]) {
        let markedItems = tries.map(\.data).filter { markedForDeletion.contains($0.path) }
        guard !markedItems.isEmpty else { return }

        var input = InputFieldState(placeholder: "", text: "")

        if let testKeys, !testKeys.isEmpty {
            var remaining = testKeys
            while !remaining.isEmpty {
                let ch = remaining.removeFirst()
                if ch == "\r" || ch == "\n" { break }
                _ = input.handleKey(ch)
            }
            self.testKeys = remaining
            processDeleteConfirmation(markedItems: markedItems, confirmation: input.text)
            return
        } else if let testConfirm {
            processDeleteConfirmation(markedItems: markedItems, confirmation: testConfirm)
            return
        } else if isatty(STDERR_FILENO) == 0 {
            let line = readCookedLine() ?? ""
            processDeleteConfirmation(markedItems: markedItems, confirmation: line)
            return
        }

        if !testNoCls { clearScreen() }
        while true {
            renderDeleteDialog(markedItems: markedItems, buffer: input.text, cursor: input.cursor)

            guard let key = readKey() else { continue }
            if input.handleKey(key) { continue }

            switch key {
            case "\r":
                processDeleteConfirmation(markedItems: markedItems, confirmation: input.text)
                needsRedraw = true
                return
            case "\u{1B}", "\u{03}":
                deleteStatus = "Delete cancelled"
                markedForDeletion.removeAll()
                deleteMode = false
                needsRedraw = true
                return
            default:
                break
            }
        }
    }

    private func processDeleteConfirmation(markedItems: [TryEntry], confirmation: String) {
        guard confirmation == "YES" else {
            deleteStatus = "Delete cancelled"
            markedForDeletion.removeAll()
            deleteMode = false
            return
        }

        guard let baseReal = try? FileManager.default.destinationOfSymbolicLink(atPath: basePath) else {
            let baseReal = (basePath as NSString).standardizingPath
            finishDelete(markedItems: markedItems, baseReal: baseReal)
            return
        }
        finishDelete(markedItems: markedItems, baseReal: baseReal.hasPrefix("/") ? baseReal : basePath)
    }

    private func finishDelete(markedItems: [TryEntry], baseReal: String) {
        var validatedPaths: [(path: String, basename: String)] = []
        for item in markedItems {
            let targetReal = (item.path as NSString).standardizingPath
            guard targetReal.hasPrefix(baseReal + "/") else {
                deleteStatus = "Error: Safety check failed: \(targetReal) is not inside \(baseReal)"
                return
            }
            validatedPaths.append((path: targetReal, basename: item.basename))
        }

        selected = .delete(paths: validatedPaths, basePath: baseReal)
        let names = validatedPaths.map(\.basename).joined(separator: ", ")
        deleteStatus = "Deleted: \(names)"
        invalidateCache()
        markedForDeletion.removeAll()
        deleteMode = false
    }
}

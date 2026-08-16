import Foundation
import TryCore

extension TryTUI {
    func render(tries: [FuzzyMatch<TryEntry>]) {
        let screen = Screen()
        let width = screen.width
        let height = screen.height

        var line = screen.header.addLine()
        line.write.write(Segment.emoji("\u{1F3E0}")).write(TuiText.accent(" Try Directory Selection"))
        line = screen.header.addLine()
        line.write.writeDim("").writeFill(char: "\u{2500}")
        line = screen.header.addLine()
        let prefix = "Search: "
        line.write.writeDim(prefix)
        let inputField = screen.input("", value: searchFieldSnapshot.text, cursor: searchFieldSnapshot.cursor)
        line.write.write(inputField.render())
        line.markHasInput(prefixWidth: Metrics.visibleWidth(prefix))
        line = screen.header.addLine()
        line.write.writeFill(char: "\u{2500}")

        line = screen.footer.addLine()
        line.write.writeFill(char: "\u{2500}")
        if let status = deleteStatusSnapshot {
            line = screen.footer.addLine()
            line.write.writeBold(status)
            clearDeleteStatus()
        } else if deleteModeSnapshot {
            line = screen.footer.addLine(background: Palette.dangerBG)
            line.write.writeBold(" DELETE MODE ")
            line.write.write(" \(markedForDeletionCountSnapshot) marked  |  Ctrl-D: Toggle  Enter: Confirm  Esc: Cancel")
        } else {
            line = screen.footer.addLine()
            line.center.writeDim("\u{2191}/\u{2193}: Navigate  Enter: Select  ^R: Rename  ^G: Graduate  ^D: Delete  Esc: Cancel")
        }

        let headerLines = screen.header.lines.count
        let footerLines = screen.footer.lines.count
        let maxVisible = max(height - headerLines - footerLines, 3)
        let showCreateNew = !searchFieldSnapshot.text.isEmpty
        let totalItems = tries.count + (showCreateNew ? 1 : 0)

        adjustScrollOffset(maxVisible: maxVisible, totalItems: totalItems)

        let visibleEnd = min(scrollOffsetSnapshot + maxVisible, totalItems)
        for idx in scrollOffsetSnapshot..<max(visibleEnd, scrollOffsetSnapshot) {
            if idx < tries.count {
                renderEntryLine(screen: screen, match: tries[idx], isSelected: idx == cursorPosSnapshot, width: width)
            } else {
                renderCreateLine(screen: screen, isSelected: idx == cursorPosSnapshot, width: width)
            }
        }

        screen.flush()
    }

    private func renderEntryLine(screen: Screen, match: FuzzyMatch<TryEntry>, isSelected: Bool, width: Int) {
        let entry = match.data
        let isMarked = markedForDeletionSnapshot.contains(entry.path)
        let background: String?
        if isMarked {
            background = Palette.dangerBG + (isSelected ? Palette.selectedFG : "")
        } else if isSelected {
            background = Palette.selectedBG + Palette.selectedFG
        } else {
            background = nil
        }

        let line = screen.body.addLine(background: background)
        line.write.write(isSelected ? TuiText.highlight("\u{2192} ") + selectedForeground() : "  ")

        let icon: Segment
        if isMarked {
            icon = Segment.emoji("\u{1F5D1}\u{FE0F}")
        } else if entry.isSymlink {
            icon = Segment.emoji("\u{1F517}")
        } else {
            icon = Segment.emoji("\u{1F4C1}")
        }
        line.write.write(icon).write(" ")

        let (plainName, renderedName) = formattedEntryName(entry: entry, positions: match.positions, selected: isSelected)
        let prefixWidth = 5
        let metaText = "\(RelativeTime.format(entry.mtime)), \(String(format: "%.1f", match.score))"

        let maxNameWidth = width - prefixWidth - 1
        var displayRendered = renderedName
        if plainName.count > maxNameWidth, maxNameWidth > 2 {
            displayRendered = truncateWithANSI(renderedName, maxLength: maxNameWidth - 1) + "\u{2026}"
        }

        line.write.write(displayRendered)
        line.right.write(isSelected ? metaText : TuiText.dim(metaText))
    }

    private func renderCreateLine(screen: Screen, isSelected: Bool, width: Int) {
        let background = isSelected ? Palette.selectedBG + Palette.selectedFG : nil
        let line = screen.body.addLine(background: background)
        line.write.write(isSelected ? TuiText.highlight("\u{2192} ") + selectedForeground() : "  ")
        let datePrefix = DatePrefix.today()
        let label: String
        if searchFieldSnapshot.text.isEmpty {
            label = "\u{1F4C2} Create new: \(datePrefix)-"
        } else {
            label = "\u{1F4C2} Create new: \(datePrefix)-\(searchFieldSnapshot.text)"
        }
        line.write.write(label)
    }

    private func formattedEntryName(entry: TryEntry, positions: [Int], selected: Bool) -> (plain: String, rendered: String) {
        let basename = entry.basename
        if let match = basename.range(of: #"^\d{4}-\d{2}-\d{2}-"#, options: .regularExpression) {
            let datePart = String(basename[basename.startIndex..<match.upperBound].dropLast())
            let namePart = String(basename[match.upperBound...])
            let dateLen = datePart.count + 1

            var rendered = selected ? datePart : TuiText.dim(datePart)
            let hyphen: String
            if positions.contains(10) {
                hyphen = TuiText.highlight("-")
            } else if selected {
                hyphen = "-"
            } else {
                hyphen = TuiText.dim("-")
            }
            rendered += hyphen
            if selected, positions.contains(10) { rendered += selectedForeground() }
            rendered += highlightWithPositions(text: namePart, positions: positions, offset: dateLen, selected: selected)
            return ("\(datePart)-\(namePart)", rendered)
        } else {
            return (basename, highlightWithPositions(text: basename, positions: positions, offset: 0, selected: selected))
        }
    }

    private func highlightWithPositions(text: String, positions: [Int], offset: Int, selected: Bool) -> String {
        let posSet = Set(positions)
        let chars = Array(text)
        var result = ""
        var i = 0
        while i < chars.count {
            if posSet.contains(i + offset) {
                let batchStart = i
                i += 1
                while i < chars.count, posSet.contains(i + offset) { i += 1 }
                result += TuiText.highlight(String(chars[batchStart..<i]))
                if selected { result += selectedForeground() }
            } else {
                result.append(chars[i])
                i += 1
            }
        }
        return result
    }

    private func selectedForeground() -> String {
        TuiColors.enabled ? Palette.selectedFG : ""
    }

    private func truncateWithANSI(_ text: String, maxLength: Int) -> String {
        var visibleCount = 0
        var result = ""
        var inANSI = false
        for ch in text {
            if ch == "\u{1B}" {
                inANSI = true
                result.append(ch)
            } else if inANSI {
                result.append(ch)
                if ch == "m" { inANSI = false }
            } else {
                if visibleCount >= maxLength { break }
                result.append(ch)
                visibleCount += 1
            }
        }
        return result
    }

    // MARK: - Dialog rendering

    func renderRenameDialog(currentName: String, buffer: String, cursor: Int, error: String?) {
        let screen = Screen()
        var line = screen.header.addLine()
        line.center.write(Segment.emoji("\u{270F}\u{FE0F}")).write(TuiText.accent("  Rename directory"))
        line = screen.header.addLine()
        line.write.writeFill(char: "\u{2500}")

        line = screen.body.addLine()
        line.write.write(Segment.emoji("\u{1F4C1}")).write(" \(currentName)")

        screen.body.addLine()
        screen.body.addLine()
        line = screen.body.addLine()
        let prefix = "New name: "
        line.center.writeDim(prefix)
        let field = screen.input("", value: buffer, cursor: cursor)
        line.center.write(field.render())
        let inputWidth = max(buffer.count, cursor + 1)
        let prefixWidth = Metrics.visibleWidth(prefix)
        let maxContent = screen.width - 1
        let centerStart = (maxContent - prefixWidth - inputWidth) / 2
        line.markHasInput(prefixWidth: centerStart + prefixWidth)

        if let error {
            screen.body.addLine()
            line = screen.body.addLine()
            line.center.writeBold(error)
        }

        line = screen.footer.addLine()
        line.write.writeFill(char: "\u{2500}")
        line = screen.footer.addLine()
        line.center.writeDim("Enter: Confirm  Esc: Cancel")

        screen.flush()
    }

    func renderAscendDialog(currentName: String, buffer: String, cursor: Int, error: String?, projectsDir: String) {
        let screen = Screen()
        var line = screen.header.addLine()
        line.center.write(Segment.emoji("\u{1F680}")).write(TuiText.accent("  Graduate try to project"))
        line = screen.header.addLine()
        line.write.writeFill(char: "\u{2500}")

        line = screen.body.addLine()
        line.write.write(Segment.emoji("\u{1F4C1}")).write(" \(currentName)")
        screen.body.addLine()

        let envHint = env["TRY_PROJECTS"] != nil ? "$TRY_PROJECTS" : "parent of $TRY_PATH"
        line = screen.body.addLine()
        line.center.writeDim("Destination (\(envHint): \(projectsDir))")

        line = screen.body.addLine()
        let prefix = "Move to: "
        line.center.writeDim(prefix)
        let field = screen.input("", value: buffer, cursor: cursor)
        line.center.write(field.render())
        let inputWidth = max(buffer.count, cursor + 1)
        let prefixWidth = Metrics.visibleWidth(prefix)
        let maxContent = screen.width - 1
        let centerStart = (maxContent - prefixWidth - inputWidth) / 2
        line.markHasInput(prefixWidth: centerStart + prefixWidth)

        screen.body.addLine()
        line = screen.body.addLine()
        line.center.writeDim("A symlink will be left in the tries directory")

        if let error {
            screen.body.addLine()
            line = screen.body.addLine()
            line.center.writeBold(error)
        }

        line = screen.footer.addLine()
        line.write.writeFill(char: "\u{2500}")
        line = screen.footer.addLine()
        line.center.writeDim("Enter: Confirm  Esc: Cancel")

        screen.flush()
    }

    func renderDeleteDialog(markedItems: [TryEntry], buffer: String, cursor: Int) {
        let screen = Screen()
        let count = markedItems.count
        var line = screen.header.addLine()
        line.center.write(Segment.emoji("\u{1F5D1}\u{FE0F}")).write(TuiText.accent("  Delete \(count) \(count == 1 ? "directory" : "directories")?"))
        line = screen.header.addLine()
        line.write.writeFill(char: "\u{2500}")

        for item in markedItems {
            line = screen.body.addLine(background: Palette.dangerBG)
            line.write.write(Segment.emoji("\u{1F5D1}\u{FE0F}")).write(" \(item.basename)")
        }

        screen.body.addLine()
        screen.body.addLine()
        line = screen.body.addLine()
        let prefix = "Type YES to confirm: "
        line.center.writeDim(prefix)
        let field = screen.input("", value: buffer, cursor: cursor)
        line.center.write(field.render())
        let inputWidth = max(buffer.count, cursor + 1)
        let prefixWidth = Metrics.visibleWidth(prefix)
        let maxContent = screen.width - 1
        let centerStart = (maxContent - prefixWidth - inputWidth) / 2
        line.markHasInput(prefixWidth: centerStart + prefixWidth)

        line = screen.footer.addLine()
        line.write.writeFill(char: "\u{2500}")
        line = screen.footer.addLine()
        line.center.writeDim("Enter: Confirm  Esc: Cancel")

        screen.flush()
    }
}

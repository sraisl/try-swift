import Foundation

/// One legitimate Process-touching exception to TryCore's "pure logic only"
/// rule: shell detection needs the parent process name as a fallback when
/// $SHELL/$PSModulePath are unset. Mirrors try.rb's
/// `` `ps c -p #{Process.ppid} -o 'ucomm='`.strip ``.
func parentProcessName() -> String? {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/bin/ps")
    task.arguments = ["c", "-p", "\(getppid())", "-o", "ucomm="]

    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = Pipe()

    do {
        try task.run()
        task.waitUntilExit()
    } catch {
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    guard let output = String(data: data, encoding: .utf8) else { return nil }
    let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

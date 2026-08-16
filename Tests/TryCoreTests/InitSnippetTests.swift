import Testing
import Foundation
@testable import TryCore

@Suite struct InitSnippetTests {
    @Test func bashSnippetContainsWrapperFunctionAndDefaultPath() {
        let out = InitSnippet.render(shell: .bash, binaryPath: "/usr/local/bin/try", explicitPath: nil, defaultPath: "/Users/x/src/tries")
        #expect(out.contains("try() {"))
        #expect(out.contains("'/usr/local/bin/try' exec --path \"${TRY_PATH:-/Users/x/src/tries}\" \"$@\" 2>/dev/tty"))
        #expect(out.contains("eval \"$out\""))
    }

    @Test func bashSnippetUsesExplicitPathWhenGiven() {
        let out = InitSnippet.render(shell: .bash, binaryPath: "/usr/local/bin/try", explicitPath: "/custom/path", defaultPath: "/default")
        #expect(out.contains("--path '/custom/path'"))
        #expect(!out.contains("/default"))
    }

    @Test func zshUsesSameSnippetAsBash() {
        let bash = InitSnippet.render(shell: .bash, binaryPath: "/bin/try", explicitPath: nil, defaultPath: "/d")
        let zsh = InitSnippet.render(shell: .zsh, binaryPath: "/bin/try", explicitPath: nil, defaultPath: "/d")
        #expect(bash == zsh)
    }

    @Test func fishSnippetUsesFishSyntax() {
        let out = InitSnippet.render(shell: .fish, binaryPath: "/bin/try", explicitPath: nil, defaultPath: "/d")
        #expect(out.contains("function try"))
        #expect(out.contains("string collect"))
        #expect(out.contains("$pipestatus[1]"))
    }

    @Test func pwshSnippetUsesPowerShellSyntax() {
        let out = InitSnippet.render(shell: .pwsh, binaryPath: "/bin/try", explicitPath: nil, defaultPath: "/d")
        #expect(out.contains("function try {"))
        #expect(out.contains("Invoke-Expression"))
        #expect(out.contains("$LASTEXITCODE"))
    }
}

@Suite struct CloneNamingTests {
    @Test func usesCustomNameWhenProvided() {
        let name = CloneNaming.directoryName(gitURI: "https://github.com/tobi/try", customName: "my-name")
        #expect(name == "my-name")
    }

    @Test func generatesDatedNameFromURI() {
        let today = fixedDate()
        let name = CloneNaming.directoryName(gitURI: "https://github.com/tobi/try", customName: nil, today: today)
        #expect(name == "2026-08-16-tobi-try")
    }

    @Test func prURLTakesPrecedenceOverGenericParsing() {
        let today = fixedDate()
        let name = CloneNaming.directoryName(gitURI: "https://github.com/tobi/try/pull/5", customName: nil, today: today)
        #expect(name == "2026-08-16-tobi-try")
    }

    @Test func returnsNilForUnparsableURI() {
        #expect(CloneNaming.directoryName(gitURI: "not a uri", customName: nil) == nil)
    }

    private func fixedDate() -> Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 16
        components.timeZone = TimeZone.current
        return Calendar(identifier: .gregorian).date(from: components)!
    }
}

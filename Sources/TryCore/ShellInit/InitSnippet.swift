import Foundation

public enum Shell: String {
    case fish, zsh, bash, pwsh
}

/// Port of try.rb's `init_snippet`. Adapted for a compiled native binary:
/// where upstream conditionally prefixes `ruby '<script>'` vs a bare
/// compiled-binary path, this always uses the bare binary path (there's no
/// interpreter indirection for a Swift executable).
public enum InitSnippet {
    public static func render(shell: Shell, binaryPath: String, explicitPath: String?, defaultPath: String) -> String {
        switch shell {
        case .fish:
            return fishSnippet(binaryPath: binaryPath, explicitPath: explicitPath, defaultPath: defaultPath)
        case .pwsh:
            return pwshSnippet(binaryPath: binaryPath, explicitPath: explicitPath, defaultPath: defaultPath)
        case .zsh, .bash:
            return shSnippet(binaryPath: binaryPath, explicitPath: explicitPath, defaultPath: defaultPath)
        }
    }

    private static func fishSnippet(binaryPath: String, explicitPath: String?, defaultPath: String) -> String {
        let pathArg: String
        if let explicitPath {
            pathArg = " --path '\(explicitPath)'"
        } else {
            pathArg = " --path (if set -q TRY_PATH; echo \"$TRY_PATH\"; else; echo '\(defaultPath)'; end)"
        }
        return """
            function try
              set -l out (\(ShellQuote.posix(binaryPath)) exec\(pathArg) $argv 2>/dev/tty | string collect)
              if test $pipestatus[1] -eq 0
                eval $out
              else
                echo $out
              end
            end

            """
    }

    private static func pwshSnippet(binaryPath: String, explicitPath: String?, defaultPath: String) -> String {
        let pathExpr: String
        if let explicitPath {
            pathExpr = "'\(explicitPath)'"
        } else {
            pathExpr = "$(if ($env:TRY_PATH) { $env:TRY_PATH } else { '\(defaultPath)' })"
        }
        return """
            function try {
              $tryPath = \(pathExpr)
              $tempErr = [System.IO.Path]::GetTempFileName()
              $out = & \(ShellQuote.posix(binaryPath)) exec --path $tryPath @args 2>$tempErr
              if ($LASTEXITCODE -eq 0) {
                $out | Invoke-Expression
              } else {
                Get-Content $tempErr | Write-Host
                $out | Write-Output
              }
              Remove-Item $tempErr -ErrorAction SilentlyContinue
            }

            """
    }

    private static func shSnippet(binaryPath: String, explicitPath: String?, defaultPath: String) -> String {
        let pathArg: String
        if let explicitPath {
            pathArg = " --path '\(explicitPath)'"
        } else {
            pathArg = " --path \"${TRY_PATH:-\(defaultPath)}\""
        }
        return """
            try() {
              local out
              out=$(\(ShellQuote.posix(binaryPath)) exec\(pathArg) "$@" 2>/dev/tty)
              if [ $? -eq 0 ]; then
                eval "$out"
              else
                echo "$out"
              fi
            }

            """
    }
}

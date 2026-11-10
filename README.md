# Invoke-NativeApplication

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mnaoumov)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Invoke-NativeApplication)](https://www.powershellgallery.com/packages/Invoke-NativeApplication)
[![GitHub release](https://img.shields.io/github/v/release/mnaoumov/Invoke-NativeApplication)](https://github.com/mnaoumov/Invoke-NativeApplication/releases)

A PowerShell module for invoking native applications with proper error messages and exit code handling.

Invocation of native applications in PowerShell seems too easy but actually it is not. For more explanation see: [Execution of external commands in PowerShell done right](https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/).

## Installation

```powershell
Install-Module -Name Invoke-NativeApplication
```

## Functions

### Invoke-NativeApplication

Runs a native application, captures STDERR, and throws if the exit code is non-zero.

```powershell
Invoke-NativeApplication { git status }
```

Alias: `exec`

#### Parameters

| Parameter          | Type          | Description                                                    |
|--------------------|---------------|----------------------------------------------------------------|
| `ScriptBlock`      | `ScriptBlock` | The script block containing the native application invocation. |
| `ArgumentList`     | `HashTable`   | A hashtable of arguments to splat into the script block.       |
| `AllowedExitCodes` | `int[]`       | Exit codes considered successful. Defaults to `@(0)`.          |
| `IgnoreExitCode`   | `switch`      | When specified, does not throw on non-zero exit codes.         |

Plus the [execution options](#execution-options) and the [out parameters](#out-parameters).

#### Examples

```powershell
# Throws if git returns a non-zero exit code
Invoke-NativeApplication { git status }

# Comma-separated list of allowed exit codes
Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes @(0, 1)

# Range of allowed exit codes
Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes (0..3)

# Combined ranges and individual codes
Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes ((0..3) + (8, 10) + (20..30))

# Capture all output without throwing, then filter for STDERR lines
$output = Invoke-NativeApplication { dotnet build } -IgnoreExitCode
$errors = $output | Where-Object { $_.IsError }
```

### Invoke-NativeApplicationSafe

Runs a native application, ignores the exit code, and returns only STDOUT lines (filters out STDERR).

```powershell
Invoke-NativeApplicationSafe { git branch }
```

Alias: `safeexec`

#### Parameters

| Parameter      | Type          | Description                                                    |
|----------------|---------------|----------------------------------------------------------------|
| `ScriptBlock`  | `ScriptBlock` | The script block containing the native application invocation. |
| `ArgumentList` | `HashTable`   | A hashtable of arguments to splat into the script block.       |

Plus the [execution options](#execution-options) and the [out parameters](#out-parameters) — the latter handy here, because they give access to the exit code and to the STDERR lines this function filters out of its return value.

```powershell
$branches = Invoke-NativeApplicationSafe { git branch } -ExitCodeVariable 'code' -StdErrVariable 'err'

if ($code -ne 0) {
    Write-Warning -Message ($err -join [System.Environment]::NewLine)
}
```

## Execution Options

Both functions take these options, which shape how the script block runs. Each is undone when the call ends, including when it throws.

| Parameter          | Type        | Description                                                                                                                         |
|--------------------|-------------|-------------------------------------------------------------------------------------------------------------------------------------|
| `WorkingDirectory` | `string`    | Directory the script block, and so the native application, runs in. The current location is restored afterwards.                   |
| `Environment`      | `HashTable` | Environment variable overrides for this call only. A `$null` value removes the variable. The previous values are restored.          |
| `LogPath`          | `string`    | Log file receiving every line as it is produced, STDERR lines prefixed with `[ERR] `. Overwritten unless `-AppendLog` is given.     |
| `AppendLog`        | `switch`    | Appends to the `-LogPath` file instead of overwriting it.                                                                           |
| `Priority`         | `string`    | `BelowNormal` or `Idle`. Windows only.                                                                                              |
| `Elevate`          | `switch`    | Runs the script block in an elevated PowerShell process, after a UAC prompt. Windows only. Changes nothing in an elevated session. |

```powershell
# Run in another directory, with CI set and NODE_OPTIONS removed for this call only, teeing the output into a log
Invoke-NativeApplication { npm test } -WorkingDirectory 'C:\repo' -Environment @{ CI = 'true'; NODE_OPTIONS = $null } -LogPath 'C:\logs\test.log'

# Keep the machine responsive during a long build
Invoke-NativeApplication { dotnet build } -Priority BelowNormal

# Stop a service from a non-elevated session
Invoke-NativeApplication { param($Name) sc.exe stop $Name } -ArgumentList @{ Name = 'Spooler' } -Elevate
```

Notes:

- `-Priority` lowers the PowerShell process itself for the duration of the call, because a process started by a `BelowNormal` or `Idle` process inherits its priority class. Higher classes are not inherited, so they are not offered.
- `-Elevate` hands the output lines and the exit code back once the elevated process ends, so the output is not streamed. Only the script block text and `-ArgumentList` reach the elevated process: variables the script block closes over do not, and complex arguments arrive deserialized. `-WorkingDirectory` defaults to the current location there, and `-Environment` and `-Priority` are applied in the elevated process. Variables set earlier in the session with `$env:` do not reach it, so pass them with `-Environment`.

### Timeouts, hidden windows and process trees

These need the launcher to own the creation of the process, which a script block does not give. Use [`headless-run`](https://github.com/mnaoumov/headless-run) inside the script block for them: it runs a program with no console window, terminates the whole process tree with a kill-on-close job, and enforces a timeout.

```powershell
Invoke-NativeApplication { headless-run --timeout 30m --below-normal -- dotnet test }
```

`headless-run` returns `124` when the timeout expires, so the call throws with that exit code.

## Out Parameters

Both functions can capture each piece of the invocation separately. Every out parameter takes the **name** of a variable (without the `$`, although a leading `$` is tolerated) and sets that variable in the caller's scope, following the convention of the built-in `-OutVariable` / `-ErrorVariable` common parameters.

| Parameter           | Captured value                                                                                  |
|---------------------|--------------------------------------------------------------------------------------------------|
| `StdOutVariable`    | STDOUT lines only, as an `OutputLine[]`.                                                          |
| `StdErrVariable`    | STDERR lines only, as an `OutputLine[]`.                                                          |
| `OutputVariable`    | All lines in their original interleaved order — the same sequence the function returns.           |
| `ExitCodeVariable`  | The exit code, or `$null` if the script block ran no native application.                          |
| `SuccessVariable`   | `$true` when the exit code is one of `AllowedExitCodes`. Not affected by `-IgnoreExitCode`.       |
| `DurationVariable`  | Execution time as a `TimeSpan`.                                                                   |
| `StartTimeVariable` | `DateTime` the execution started at.                                                              |
| `EndTimeVariable`   | `DateTime` the execution finished at.                                                             |
| `CommandVariable`   | The executed script block and its splatted arguments rendered as a string, suitable for logging.  |

```powershell
Invoke-NativeApplication { dotnet build } -IgnoreExitCode `
    -StdOutVariable 'out' `
    -StdErrVariable 'err' `
    -ExitCodeVariable 'code' `
    -DurationVariable 'duration' | Out-Null

"dotnet build exited with $code after $duration"
$err | ForEach-Object { Write-Warning -Message $_ }
```

The variables are set **before** the exit code exception is thrown, so a `try`/`catch` around the call can still inspect everything that was captured:

```powershell
try {
    Invoke-NativeApplication { dotnet build } -StdErrVariable 'err' -DurationVariable 'duration'
} catch {
    Write-Warning -Message ('Build failed after {0} with {1} error lines' -f $duration, $err.Count)
}
```

Notes:

- The variables land in the scope where the call is made — exactly like `-OutVariable`. A call inside a nested script block sets them inside that script block.
- When called from the PowerShell prompt, STDERR is normally left unredirected so that it keeps its default console formatting. Requesting `-StdErrVariable` or `-OutputVariable` forces the redirection even there, because the STDERR lines cannot be captured otherwise.

## Output Type: InvokeNativeApplication.OutputLine

Both functions return `InvokeNativeApplication.OutputLine` objects. These behave like strings (all `System.String` methods are available with tab-completion) but carry an additional `IsError` property indicating whether the line originated from STDERR.

```powershell
$result = Invoke-NativeApplication { git status }

# Use like a string
$result[0].Substring(0, 10)
$result[0].Contains("branch")
"First line: $($result[0])"

# Check error origin
$result | Where-Object { $_.IsError }

# Implicit conversion to string
[string]$firstLine = $result[0]
```

## Requirements

- PowerShell 3.0 or later

## Changelog

All notable changes to this project will be documented in the [CHANGELOG](./CHANGELOG.md).

## Support

<!-- markdownlint-disable MD033 -->

<a href="https://www.buymeacoffee.com/mnaoumov" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60" width="217"></a>

<!-- markdownlint-enable MD033 -->

### Filing an issue (for AI agents and humans)

Open issues through the [issue forms](https://github.com/mnaoumov/Invoke-NativeApplication/issues/new/choose), not as blank issues.

Filing from the CLI or the API (`gh issue create --body`, or an AI agent filing for you) skips the form, and `gh issue create --template` cannot load an issue form. In that case, open the matching form in [`.github/ISSUE_TEMPLATE/`](https://github.com/mnaoumov/Invoke-NativeApplication/tree/HEAD/.github/ISSUE_TEMPLATE), copy every field as a `### <label>` heading in the form's order, and fill in each one. Always state the version you used and your operating system.

## License

© [Michael Naumov](https://github.com/mnaoumov/)

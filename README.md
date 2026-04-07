# Invoke-NativeApplication

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-ffdd00?logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mnaoumov)
[![PowerShell Gallery](https://img.shields.io/powershellgallery/v/Invoke-NativeApplication)](https://www.powershellgallery.com/packages/Invoke-NativeApplication)
[![GitHub release](https://img.shields.io/github/v/release/mnaoumov/Invoke-NativeApplication)](https://github.com/mnaoumov/Invoke-NativeApplication/releases)

A PowerShell module for invoking native applications with proper error messages and exit code handling.

Invocation of native applications in PowerShell seems too easy but actually it is not. For more explanation see:

- https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/
- https://mnaoumov.wordpress.com/2015/03/31/execution-of-external-commands-native-applications-in-powershell-done-right-part-2/

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

## Support

<!-- markdownlint-disable MD033 -->

<a href="https://www.buymeacoffee.com/mnaoumov" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/v2/default-yellow.png" alt="Buy Me A Coffee" height="60" width="217"></a>

<!-- markdownlint-enable MD033 -->

## License

© [Michael Naumov](https://github.com/mnaoumov/)

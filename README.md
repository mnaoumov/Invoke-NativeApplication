# Invoke-NativeApplication

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

# Treat robocopy exit codes 0-3 as successful
Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes @(0, 1, 2, 3)

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

## Output Type: NativeApplicationOutput

Both functions return `NativeApplicationOutput` objects. These behave like strings (all `System.String` methods are available with tab-completion) but carry an additional `IsError` property indicating whether the line originated from STDERR.

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

## License

[MIT](LICENSE.md)

# Invoke-NativeApplication

A set of helper functions to invoke native applications in PowerShell with proper error messages and exit code handlers.

Invocation of native applications in PowerShell seems too easy but actually it is not.

For more explanation see https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/ and https://mnaoumov.wordpress.com/2015/03/31/execution-of-external-commands-native-applications-in-powershell-done-right-part-2/

## Installation

```powershell
Install-Module -Name Invoke-NativeApplication
```

## Usage

```powershell
Import-Module Invoke-NativeApplication

exec { .\some-application-that-writes-to-the-STDERR-and-returns-some-exit-code.exe }
safeexec { .\some-application-that-writes-to-the-STDERR-and-returns-some-exit-code.exe }
```

These functions will capture the STDERR stream properly and check the exit code after your application has exited.

- `exec` / `Invoke-NativeApplication` — runs the command and throws if the exit code is non-zero.
- `safeexec` / `Invoke-NativeApplicationSafe` — runs the command, ignores the exit code, and filters out error records from output.

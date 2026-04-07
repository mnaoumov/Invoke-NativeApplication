# Project: Invoke-NativeApplication

PowerShell module for invoking native applications with proper STDERR capture and exit code handling.

## L1. Project Structure

- `Invoke-NativeApplication.psd1` — module manifest
- `Invoke-NativeApplication.psm1` — module script (exports functions and aliases)
- `OutputLine.cs` — C# class `InvokeNativeApplication.OutputLine` (string-like wrapper with `IsError`)
- `Invoke-NativeApplication.format.ps1xml` — format file for string-like display
- `build.ps1` — dev script: installs dependencies via PSDepend and runs Pester tests
- `requirements.psd1` — dev dependencies (PSDepend format)
- `*.Tests.ps1` — Pester 5 test files (next to source, not in a separate directory)

## L2. Exported API

- `Invoke-NativeApplication` (alias `exec`) — run command, throw on bad exit code
- `Invoke-NativeApplicationSafe` (alias `safeexec`) — run command, ignore exit code, filter STDERR
- `InvokeNativeApplication.OutputLine` — output type with `IsError` property, delegates all `System.String` members

## L3. PowerShell Style

- Allman brace style throughout
- Follow G21 conventions

## L4. C# Style

- Target C# 5 syntax (no pattern matching, expression-bodied members, etc.) for PS 5.1 `Add-Type` compatibility
- Allman brace style, mandatory curly braces on all conditionals
- All public members must have XML doc comments

## L5. Testing

- Pester 5 via `pwsh` (not Windows PowerShell `powershell`)
- Run with `pwsh -NoProfile -File build.ps1`
- Wrap single-item results in `@()` to avoid scalar/char indexer issues

## L6. Publishing

- Target: PowerShell Gallery
- Minimum PowerShell version: 3.0

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
- Both functions take `-*Variable` out parameters (`StdOut`, `StdErr`, `Output`, `ExitCode`, `Success`, `Duration`, `StartTime`, `EndTime`, `Command`)

## L2a. Out Parameter Internals

- Out parameters take a variable **name** and set it in the caller's scope via `$PSCmdlet.SessionState.PSVariable.Set()`, mirroring the built-in `-OutVariable` convention
- `$PSCmdlet.SessionState` reaches the **immediate** caller only: a name forwarded from one module function to another lands in the module's scope, not the end user's. That is why `Invoke-NativeApplicationCore` fills a `-Capture` hashtable and each public function sets its own caller's variables from it
- The capture hashtable is filled in Core's `finally`, so it is populated even when the exit code check throws
- `$script:CaptureVariableParameters` maps each out parameter to its capture key — add new captures there, in both public `param()` blocks, and in the comment-based help

## L3. PowerShell Style

- K&R / One True Brace Style (opening brace on same line)
- Follow PowerShell conventions from global AGENTS.md

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

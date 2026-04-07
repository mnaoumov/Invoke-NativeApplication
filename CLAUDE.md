# Project: Invoke-NativeApplication

PowerShell utility for invoking native applications with proper STDERR capture and exit code handling.

## L1. Project Structure

- `exec.ps1` — main script (dot-sourced library, not a standalone script)
- Exports two functions: `Invoke-NativeApplication` (alias `exec`), `Invoke-NativeApplicationSafe` (alias `safeexec`)

## L2. PowerShell Style

- Allman brace style throughout
- Follow G21 conventions

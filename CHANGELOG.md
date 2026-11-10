# CHANGELOG

## 1.3.0 (2026-11-08)

This release has 1 new feature and 1 documentation change. 1 maintenance commit (tests, build, CI, refactoring, dependencies) is not listed.

### New

- add execution options: working directory, environment, log, priority, elevation (`-WorkingDirectory`, `-Environment`, `-LogPath` and `-AppendLog`, `-Priority`, `-Elevate`)

### Documentation

- add issue-filing instructions for AI agents

## 1.2.0 (2026-08-15)

This release has 1 fix.

### Fixed

- report the real fault line from build.ps1's trap

## 1.1.0 (2026-08-15)

This release has 1 new feature and 1 documentation change. 1 maintenance commit (tests, build, CI, refactoring, dependencies) is not listed.

### New

- capture stdout, stderr, exit code and timings via out parameters (`-StdOutVariable`, `-StdErrVariable`, `-OutputVariable`, `-ExitCodeVariable`, `-SuccessVariable`, `-DurationVariable`, `-StartTimeVariable`, `-EndTimeVariable`, `-CommandVariable`)

### Documentation

- migrate to AGENTS.md

## 1.0.1 (2026-04-09)

### Changes

- Convert PowerShell files from Allman to K&R/OTBS brace style

## 1.0.0 (2026-04-07)

First release of Invoke-NativeApplication as a proper PowerShell module.

### What's new

- Converted from dot-sourced script to installable PowerShell module
- New `InvokeNativeApplication.OutputLine` type — behaves like a string with full tab-completion, plus `IsError` property for STDERR detection
- Comment-based help with examples for all functions
- Format file for string-like console display
- Comprehensive Pester 5 test suite (53 tests)

### Functions

- `Invoke-NativeApplication` (alias: `exec`) — run a native app, throw on bad exit code
- `Invoke-NativeApplicationSafe` (alias: `safeexec`) — run a native app, ignore exit code, filter STDERR

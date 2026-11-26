# Project: Invoke-NativeApplication

PowerShell module for invoking native applications with proper STDERR capture and exit code handling.

## Filing an issue (for AI agents and humans)

Open issues through the [issue forms](https://github.com/mnaoumov/Invoke-NativeApplication/issues/new/choose), not as blank issues.

Filing from the CLI or the API (`gh issue create --body`, or an AI agent filing for you) skips the form, and `gh issue create --template` cannot load an issue form. In that case, open the matching form in [`.github/ISSUE_TEMPLATE/`](https://github.com/mnaoumov/Invoke-NativeApplication/tree/HEAD/.github/ISSUE_TEMPLATE), copy every field as a `### <label>` heading in the form's order, and fill in each one. Always state the version you used and your operating system.

## L1. Project Structure

- `Invoke-NativeApplication.psd1` — module manifest
- `Invoke-NativeApplication.psm1` — module script (exports functions and aliases)
- `Invoke-NativeApplication.Elevated.ps1` — the elevated half of `-Elevate`: reads a CliXml request, runs the script block through the module, writes a CliXml response (listed in the manifest `FileList`)
- `OutputLine.cs` — C# class `InvokeNativeApplication.OutputLine` (string-like wrapper with `IsError`)
- `Invoke-NativeApplication.format.ps1xml` — format file for string-like display
- `build.ps1` — dev script: installs dependencies via PSDepend and runs Pester tests
- `deploy.ps1` — release script: tests, version bump, changelog section, commit, tag, push, PowerShell Gallery, GitHub release
- `Changelog.ps1` — dev helper dot-sourced by `deploy.ps1`: renders a release's `CHANGELOG.md` section, grouped by Conventional Commits type, from its first-parent commits
- `CHANGELOG.md` — release history, newest first, one `## <version> (<yyyy-MM-dd>)` section per release; linked from the README `## Changelog` section
- `requirements.psd1` — dev dependencies (PSDepend format); pins `Target = 'CurrentUser'` so no admin rights are needed (PSDepend's `Target` *is* the `Install-Module -Scope` proxy — a `Parameters.Scope` entry is rejected with a warning and ignored)
- `*.Tests.ps1` — Pester 5 test files (next to source, not in a separate directory)

## L2. Exported API

- `Invoke-NativeApplication` (alias `exec`) — run command, throw on bad exit code
- `Invoke-NativeApplicationSafe` (alias `safeexec`) — run command, ignore exit code, filter STDERR
- `InvokeNativeApplication.OutputLine` — output type with `IsError` property, delegates all `System.String` members
- Both functions take `-*Variable` out parameters (`StdOut`, `StdErr`, `Output`, `ExitCode`, `Success`, `Duration`, `StartTime`, `EndTime`, `Command`)

- Both functions take the execution options `-WorkingDirectory`, `-Environment`, `-LogPath`, `-AppendLog`, `-Priority` (`BelowNormal`/`Idle`), `-Elevate` and `-Redact`, forwarded to the core through `$script:ExecutionOptionParameters`
- `-Redact` masks secret values with `$script:RedactionMask` (`***`) through `Hide-SecretValue`, in everything the module writes itself: the command text, the failure message and its STDERR tail, the retry warning and the log lines. The pipeline lines and the line captures stay unredacted, because they are the caller's own data. With `-Elevate` the masking happens on the caller's side, because the core there writes the log and builds the message
- Both functions take the retry options `-MaxRetries`, `-RetryTriggerErrorPattern` and `-RetryDelaySeconds`. `Invoke-NativeApplicationWithRetry` loops over the core with a fresh capture per attempt (the out parameters describe the last attempt), forces `AppendLog` after the first attempt, and with `-Elevate` in a non-elevated session hands the options to the elevated process instead, so there is one UAC prompt. The core builds `FailureMessage` even under `-IgnoreExitCode`, because the pattern matches it; the public functions pass `-CallSite`, since the extra layer shifts `Get-PSCallStack`
- Timeouts, hidden windows and process-tree kills are deliberately not options: they need the launcher to own process creation, so the README composes them with `headless-run` inside the script block

## L2b. Execution Option Internals

- The core applies the options around the script block and undoes them in reverse in its `finally`; with `-Elevate` in a non-elevated session it applies none locally and hands them to the elevated process instead
- `-Priority` lowers the PowerShell process itself, because Windows children of a BelowNormal or Idle process inherit its class
- Never put a `[ValidateSet]` (or any validation attribute) on a core parameter: Windows PowerShell's `GetNewClosure()` re-validates every attributed variable it copies, so an unset `$Priority` broke every 5.1 call. Validate on the public functions only
- A `$null` passed to a .NET `string` parameter arrives as `""`; remove an environment variable with `[NullString]::Value` (`Set-ProcessEnvironmentVariable`), in tests too
- Tests replace the UAC launch by mocking `Start-ElevatedHost` and `Test-IsElevated`, so the full CliXml round trip runs without a prompt

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
- Release with `pwsh -NoProfile -File deploy.ps1` (defaults to a minor bump); `-DryRun` reports the steps without changing anything
- Never bump `ModuleVersion` by hand — `deploy.ps1` owns it and produces the `chore: bump version to <version>` commit plus the `v<version>` tag
- Every release adds its `CHANGELOG.md` section: `deploy.ps1` writes it from the first-parent commits since the previous tag, commits it with the version bump, and creates the GitHub release with that section as its notes. To reword the generated section, edit `CHANGELOG.md` and then the release notes to match; never leave a release whose notes exist only on GitHub
- `deploy.ps1` refuses a release whose notes are not human-readable: before the version bump it classifies the rendered section (with `-PublishOnly`, the section already in `CHANGELOG.md`), and again before `gh release create`, through `Get-ReleaseNotesVerdict` in `Changelog.ps1`. Empty, a compare link alone, or bullets at least half raw `type(scope): subject` / commit-hash / `by @user in .../pull/n` lines fail; a bold `**scope:**` prefix is not raw. On a refusal, write what changed for the user into the `CHANGELOG.md` section and run again
- Only the manifest's `FileList` is published: `deploy.ps1` stages those files so the tests and dev scripts stay out of the package
- The Gallery API key comes from `-ApiKey`, `$env:PSGALLERY_API_KEY`, or an unlocked Bitwarden item named `PowerShell Gallery` — never from a chat transcript

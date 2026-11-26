$csPath = Join-Path -Path $PSScriptRoot -ChildPath 'OutputLine.cs'
Add-Type -Path $csPath

# Maps each out parameter to the key it reads from the capture hashtable filled by
# Invoke-NativeApplicationCore. Both public functions share this map.
$script:CaptureVariableParameters = @{
    StdOutVariable    = 'StdOut'
    StdErrVariable    = 'StdErr'
    OutputVariable    = 'Output'
    ExitCodeVariable  = 'ExitCode'
    SuccessVariable   = 'Success'
    DurationVariable  = 'Duration'
    StartTimeVariable = 'StartTime'
    EndTimeVariable   = 'EndTime'
    CommandVariable   = 'Command'
}

# Out parameters that require the output lines to be buffered.
$script:LineCaptureParameters = @('StdOutVariable', 'StdErrVariable', 'OutputVariable')

# Parameters shaping how the script block runs. Both public functions forward them to
# Invoke-NativeApplicationCore unchanged.
$script:ExecutionOptionParameters = @('WorkingDirectory', 'Environment', 'LogPath', 'AppendLog', 'Priority', 'Elevate', 'Redact')

# What a redacted secret value is replaced with.
$script:RedactionMask = '***'

# How many of the last STDERR lines the exception on a disallowed exit code carries.
$script:ExceptionStdErrLineLimit = 10

# The script the elevated host runs for -Elevate. It ships next to this module.
$script:ElevatedRunnerPath = Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-NativeApplication.Elevated.ps1'

<#
.SYNOPSIS
    Invokes a native application with proper STDERR handling and exit code validation.

.DESCRIPTION
    Executes a native application (external command) via a ScriptBlock, captures both
    STDOUT and STDERR streams, and validates the process exit code. Each output line is
    returned as a InvokeNativeApplication.OutputLine object that behaves like a string but carries
    an IsError property indicating whether it originated from STDERR.

    When called from the PowerShell prompt, STDERR is not redirected so that it displays
    with the default console formatting. When called from a script, STDERR is captured
    via 2>&1 redirection. Requesting -StdErrVariable or -OutputVariable forces the
    redirection even at the prompt, because the STDERR lines cannot be captured otherwise.

    Every out parameter takes the NAME of a variable (without the $ sign, although a
    leading $ is tolerated) and sets that variable in the caller's scope, following the
    convention of the built-in -OutVariable and -ErrorVariable common parameters. The
    variables are set even when the function throws on a disallowed exit code, so a
    caller that wraps the call in try/catch can still inspect what was captured.

    The exception thrown on a disallowed exit code names the command, the call site and
    the exit code on its first line. When STDERR passed through the pipeline (any call
    from a script, any call with -StdErrVariable or -OutputVariable, and -Elevate), the
    last 10 STDERR lines follow under a 'STDERR:' line, so a CI log shows why the
    program failed. With more than 10 lines the header reads
    'STDERR (last 10 of <n> lines):'.

    With -ErrorMessage, the caller's text comes first, on its own line, ahead of
    everything above.

    With -MaxRetries, a failed attempt runs the script block again, up to that many
    more times, after a warning and a -RetryDelaySeconds pause. An attempt fails when
    its exit code is not one of AllowedExitCodes or when the script block throws.
    -RetryTriggerErrorPattern limits the retries to failures whose text matches it.
    The output lines of every attempt reach the pipeline as they are produced; the out
    parameters describe the last attempt only.

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

.PARAMETER AllowedExitCodes
    An array of exit codes considered successful. Defaults to @(0).

.PARAMETER IgnoreExitCode
    When specified, the function does not throw on non-zero exit codes.

.PARAMETER ErrorMessage
    Caller text put first in the exception thrown on a disallowed exit code, on its own
    line, for example a hint at the likely cause. The command, call site, exit code and
    STDERR lines follow it as usual. It has no effect when nothing is thrown.

.PARAMETER MaxRetries
    How many more times to run the script block after a failed attempt. Defaults to 0,
    no retry. An attempt fails when its exit code is not one of AllowedExitCodes, even
    with -IgnoreExitCode, or when the script block throws. Each retry is announced with
    a warning. Only the last attempt's failure is thrown. With -LogPath, the attempts
    after the first append to the log. With -Elevate in a non-elevated session, the
    elevated process runs the attempts itself, so there is a single UAC prompt.

.PARAMETER RetryTriggerErrorPattern
    A regular expression limiting the retries to the failures it matches. It is
    matched against the failure text: the exception message (or, for a disallowed exit
    code, the message the exception would carry) followed by every STDERR line of the
    attempt. Giving it redirects STDERR even when called from the prompt, so the lines
    can be matched. Without -MaxRetries it has no effect.

.PARAMETER RetryDelaySeconds
    Pause before each retry, in seconds. Defaults to 1, as in psake's Exec.

.PARAMETER WorkingDirectory
    Directory the script block runs in. The current location is restored afterwards. A
    native application started from the script block inherits it as its working directory.

.PARAMETER Environment
    Environment variable overrides for the duration of the call, as a hashtable of name
    to value. A $null value removes the variable. The previous values are restored
    afterwards, so the overrides reach the native application without leaking into the
    session.

.PARAMETER LogPath
    Path of a log file receiving every output line as it is produced. STDERR lines are
    prefixed with '[ERR] '. The file is overwritten unless -AppendLog is specified.

.PARAMETER AppendLog
    Appends to the -LogPath file instead of overwriting it.

.PARAMETER Priority
    Runs the native application with a lower process priority: BelowNormal or Idle.
    Windows only. The PowerShell process itself is lowered for the duration of the call
    and restored afterwards, because a process started by a BelowNormal or Idle process
    inherits its priority class. Higher classes are not inherited, so they are not
    offered.

.PARAMETER Elevate
    Runs the script block in an elevated PowerShell process (UAC prompt), Windows only.
    The output lines and the exit code are handed back once the elevated process ends, so
    they are not streamed. Only the script block text and -ArgumentList travel to it:
    variables the script block closes over do not, and complex arguments arrive
    deserialized. When the session is already elevated, the switch changes nothing.

.PARAMETER Redact
    Secret values, such as tokens and passwords, replaced with '***' in everything the
    function itself writes: the command text (-CommandVariable, -Verbose and the
    exception message), the STDERR lines in the exception message, the retry warning
    and the -LogPath file. The native application still receives the values unchanged,
    and the lines returned to the pipeline and captured by -StdOutVariable,
    -StdErrVariable and -OutputVariable are left as they are. Matching is literal and
    case-sensitive; empty values are ignored.

.PARAMETER StdOutVariable
    Name of the variable receiving the STDOUT lines only, as an
    InvokeNativeApplication.OutputLine array.

.PARAMETER StdErrVariable
    Name of the variable receiving the STDERR lines only, as an
    InvokeNativeApplication.OutputLine array. Specifying it forces STDERR redirection
    even when called from the prompt.

.PARAMETER OutputVariable
    Name of the variable receiving all lines in their original interleaved order, as an
    InvokeNativeApplication.OutputLine array. This is the same sequence the function
    returns. Specifying it forces STDERR redirection even when called from the prompt.

.PARAMETER ExitCodeVariable
    Name of the variable receiving the exit code of the native application, or $null when
    the script block did not run a native application at all.

.PARAMETER SuccessVariable
    Name of the variable receiving $true when the exit code is one of AllowedExitCodes
    (or when there is no exit code at all), $false otherwise. Unlike the throwing
    behavior, it is not affected by -IgnoreExitCode.

.PARAMETER DurationVariable
    Name of the variable receiving the execution time as a TimeSpan.

.PARAMETER StartTimeVariable
    Name of the variable receiving the DateTime the execution started at.

.PARAMETER EndTimeVariable
    Name of the variable receiving the DateTime the execution finished at.

.PARAMETER CommandVariable
    Name of the variable receiving the executed script block and its splatted arguments
    rendered as a string, suitable for logging.

.EXAMPLE
    Invoke-NativeApplication { git status }

    Runs 'git status' and throws if git returns a non-zero exit code.

.EXAMPLE
    Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes @(0, 1)

    Treats exit codes 0 and 1 as successful.

.EXAMPLE
    Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes (0..3)

    Treats exit codes 0 through 3 as successful using the range operator.

.EXAMPLE
    Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes ((0..3) + (8, 10) + (20..30))

    Combines ranges with individual codes. Treats 0-3, 8, 10, and 20-30 as successful.

.EXAMPLE
    Invoke-NativeApplication { svn update } -ErrorMessage 'Is the SVN client installed?'

    On a failure, the exception message opens with 'Is the SVN client installed?'.

.EXAMPLE
    Invoke-NativeApplication { npm ci } -MaxRetries 2 -RetryTriggerErrorPattern 'ETIMEDOUT|ECONNRESET' -RetryDelaySeconds 5

    Runs 'npm ci' up to three times, retrying only on a network error, 5 seconds apart.

.EXAMPLE
    $output = Invoke-NativeApplication { dotnet build } -IgnoreExitCode
    $errors = $output | Where-Object { $_.IsError }

    Captures all output including errors without throwing, then filters
    for lines that came from STDERR.

.EXAMPLE
    Invoke-NativeApplication { dotnet build } -IgnoreExitCode -StdOutVariable 'out' -StdErrVariable 'err' -ExitCodeVariable 'code' | Out-Null
    if ($code -ne 0) { $err }

    Captures the streams separately into $out and $err and the exit code into $code.

.EXAMPLE
    try {
        Invoke-NativeApplication { dotnet build } -StdErrVariable 'err' -DurationVariable 'duration'
    } catch {
        Write-Warning -Message ('Build failed after {0} with {1} error lines' -f $duration, $err.Count)
    }

    The out variables are set before the exit code exception is thrown, so they are
    available in the catch block.

.EXAMPLE
    Invoke-NativeApplication { npm test } -WorkingDirectory 'C:\repo' -Environment @{ CI = 'true'; NODE_OPTIONS = $null } -LogPath 'C:\logs\test.log'

    Runs the tests in C:\repo with CI set and NODE_OPTIONS removed for this call only,
    and tees every line into C:\logs\test.log.

.EXAMPLE
    Invoke-NativeApplication { dotnet build } -Priority BelowNormal

    Builds at below-normal priority, so the machine stays responsive.

.EXAMPLE
    Invoke-NativeApplication { param($Name) sc.exe stop $Name } -ArgumentList @{ Name = 'Spooler' } -Elevate

    Stops a service from a non-elevated session, after a UAC prompt.

.EXAMPLE
    Invoke-NativeApplication { param($Token) git push "https://x-access-token:$Token@github.com/owner/repo.git" } -ArgumentList @{ Token = $env:GH_TOKEN } -Redact $env:GH_TOKEN -LogPath 'push.log'

    Pushes with a token that shows as '***' in the exception message and the log.

.OUTPUTS
    InvokeNativeApplication.OutputLine
    One object per output line. Each behaves like a string but carries
    an IsError property indicating whether it originated from STDERR.

.NOTES
    Alias: exec

.LINK
    https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/

.LINK
    https://mnaoumov.wordpress.com/2015/03/31/execution-of-external-commands-native-applications-in-powershell-done-right-part-2/
#>
function Invoke-NativeApplication {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position=1)][HashTable] $ArgumentList,
        [Parameter()][int[]] $AllowedExitCodes = @(0),
        [Parameter()][switch] $IgnoreExitCode,
        [Parameter()][ValidateNotNullOrEmpty()][string] $ErrorMessage,
        [Parameter()][ValidateRange(0, 2147483647)][int] $MaxRetries = 0,
        [Parameter()][ValidateScript({ Test-RegexPattern -Pattern $_ })][string] $RetryTriggerErrorPattern,
        [Parameter()][ValidateRange(0, 2147483)][double] $RetryDelaySeconds = 1,
        [Parameter()][string] $WorkingDirectory,
        [Parameter()][HashTable] $Environment,
        [Parameter()][string] $LogPath,
        [Parameter()][switch] $AppendLog,
        [Parameter()][ValidateSet('BelowNormal', 'Idle')][string] $Priority,
        [Parameter()][switch] $Elevate,
        [Parameter()][AllowEmptyCollection()][AllowEmptyString()][string[]] $Redact,
        [Parameter()][string] $StdOutVariable,
        [Parameter()][string] $StdErrVariable,
        [Parameter()][string] $OutputVariable,
        [Parameter()][string] $ExitCodeVariable,
        [Parameter()][string] $SuccessVariable,
        [Parameter()][string] $DurationVariable,
        [Parameter()][string] $StartTimeVariable,
        [Parameter()][string] $EndTimeVariable,
        [Parameter()][string] $CommandVariable
    )

    $capture = @{}
    $coreParameters = Get-CoreParameter -BoundParameters $PSBoundParameters -MaxRetries $MaxRetries -RetryTriggerErrorPattern $RetryTriggerErrorPattern
    $coreParameters['ScriptBlock'] = $ScriptBlock
    $coreParameters['ArgumentList'] = $ArgumentList
    $coreParameters['AllowedExitCodes'] = $AllowedExitCodes
    $coreParameters['IgnoreExitCode'] = [bool] $IgnoreExitCode
    $coreParameters['ErrorMessage'] = $ErrorMessage
    $coreParameters['CallSite'] = (Get-PSCallStack -ErrorAction SilentlyContinue)[1].Location

    try {
        Invoke-NativeApplicationWithRetry -CoreParameters $coreParameters -Capture $capture `
            -MaxRetries $MaxRetries -RetryTriggerErrorPattern $RetryTriggerErrorPattern -RetryDelaySeconds $RetryDelaySeconds
    } finally {
        Set-CaptureVariable -SessionState $PSCmdlet.SessionState -BoundParameters $PSBoundParameters -Capture $capture
    }
}

<#
.SYNOPSIS
    Invokes a native application, ignoring exit codes and filtering out STDERR lines.

.DESCRIPTION
    A convenience wrapper around Invoke-NativeApplication that always ignores the exit
    code and returns only STDOUT lines (lines where IsError is false). Useful when you
    want to silently capture the successful output of a command without error noise.

    It supports the same out parameters, so the exit code and the STDERR lines it filters
    out of the return value are still available, and the same execution options
    (-WorkingDirectory, -Environment, -LogPath, -AppendLog, -Priority, -Elevate). See
    Invoke-NativeApplication for their description. The -LogPath file receives the STDERR
    lines too, although they are filtered out of the return value.

    It takes -Redact as well, which keeps secret values out of the command text and the
    log; see Invoke-NativeApplication.

    It retries like Invoke-NativeApplication too (-MaxRetries, -RetryTriggerErrorPattern,
    -RetryDelaySeconds). An attempt fails on a non-zero exit code or a throwing script
    block. After the last attempt, a throw is passed on and an exit code is not.

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

.PARAMETER MaxRetries
    How many more times to run the script block after a failed attempt: a non-zero exit
    code, or a script block that throws. Defaults to 0. See Invoke-NativeApplication.

.PARAMETER RetryTriggerErrorPattern
    A regular expression limiting the retries to the failures it matches, matched
    against the failure text and every STDERR line of the attempt. See
    Invoke-NativeApplication.

.PARAMETER RetryDelaySeconds
    Pause before each retry, in seconds. Defaults to 1.

.PARAMETER StdOutVariable
    Name of the variable receiving the STDOUT lines only. Same as the returned lines.

.PARAMETER StdErrVariable
    Name of the variable receiving the STDERR lines only, i.e. the lines filtered out of
    the return value.

.PARAMETER OutputVariable
    Name of the variable receiving all lines in their original interleaved order.

.PARAMETER ExitCodeVariable
    Name of the variable receiving the exit code of the native application, or $null when
    the script block did not run a native application at all.

.PARAMETER SuccessVariable
    Name of the variable receiving $true when the exit code is 0 (or when there is no exit
    code at all), $false otherwise.

.PARAMETER DurationVariable
    Name of the variable receiving the execution time as a TimeSpan.

.PARAMETER StartTimeVariable
    Name of the variable receiving the DateTime the execution started at.

.PARAMETER EndTimeVariable
    Name of the variable receiving the DateTime the execution finished at.

.PARAMETER CommandVariable
    Name of the variable receiving the executed script block and its splatted arguments
    rendered as a string, suitable for logging.

.EXAMPLE
    $branches = Invoke-NativeApplicationSafe { git branch }

    Gets the list of git branches, ignoring any STDERR output and exit code.

.EXAMPLE
    $branches = Invoke-NativeApplicationSafe { git branch } -ExitCodeVariable 'code' -StdErrVariable 'err'
    if ($code -ne 0) { Write-Warning -Message ($err -join [System.Environment]::NewLine) }

    Keeps the filtered output as the return value while still inspecting the exit code
    and the discarded STDERR lines.

.OUTPUTS
    InvokeNativeApplication.OutputLine
    One object per STDOUT line. Each behaves like a string with IsError
    always set to False (STDERR lines are filtered out).

.NOTES
    Alias: safeexec
#>
function Invoke-NativeApplicationSafe {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position=1)][HashTable] $ArgumentList,
        [Parameter()][ValidateRange(0, 2147483647)][int] $MaxRetries = 0,
        [Parameter()][ValidateScript({ Test-RegexPattern -Pattern $_ })][string] $RetryTriggerErrorPattern,
        [Parameter()][ValidateRange(0, 2147483)][double] $RetryDelaySeconds = 1,
        [Parameter()][string] $WorkingDirectory,
        [Parameter()][HashTable] $Environment,
        [Parameter()][string] $LogPath,
        [Parameter()][switch] $AppendLog,
        [Parameter()][ValidateSet('BelowNormal', 'Idle')][string] $Priority,
        [Parameter()][switch] $Elevate,
        [Parameter()][AllowEmptyCollection()][AllowEmptyString()][string[]] $Redact,
        [Parameter()][string] $StdOutVariable,
        [Parameter()][string] $StdErrVariable,
        [Parameter()][string] $OutputVariable,
        [Parameter()][string] $ExitCodeVariable,
        [Parameter()][string] $SuccessVariable,
        [Parameter()][string] $DurationVariable,
        [Parameter()][string] $StartTimeVariable,
        [Parameter()][string] $EndTimeVariable,
        [Parameter()][string] $CommandVariable
    )

    $capture = @{}
    $coreParameters = Get-CoreParameter -BoundParameters $PSBoundParameters -MaxRetries $MaxRetries -RetryTriggerErrorPattern $RetryTriggerErrorPattern
    $coreParameters['ScriptBlock'] = $ScriptBlock
    $coreParameters['ArgumentList'] = $ArgumentList
    $coreParameters['AllowedExitCodes'] = @(0)
    $coreParameters['IgnoreExitCode'] = $true
    $coreParameters['CallSite'] = (Get-PSCallStack -ErrorAction SilentlyContinue)[1].Location

    try {
        Invoke-NativeApplicationWithRetry -CoreParameters $coreParameters -Capture $capture `
            -MaxRetries $MaxRetries -RetryTriggerErrorPattern $RetryTriggerErrorPattern -RetryDelaySeconds $RetryDelaySeconds |
            Where-Object -FilterScript { -not $_.IsError }
    } finally {
        Set-CaptureVariable -SessionState $PSCmdlet.SessionState -BoundParameters $PSBoundParameters -Capture $capture
    }
}

<#
.SYNOPSIS
    Shared implementation behind Invoke-NativeApplication and Invoke-NativeApplicationSafe.

.DESCRIPTION
    Runs the script block, streams the output lines and fills the Capture hashtable. The
    hashtable is filled in a finally block, so it is populated even when the script block
    itself throws or when the exit code check throws.

    The capture is deliberately passed as a hashtable rather than as variable names,
    because $PSCmdlet.SessionState.PSVariable.Set() reaches the immediate caller only. A
    name forwarded from a public function would land in the module's scope instead of the
    end user's one.

.PARAMETER Capture
    Hashtable filled with the captured data. Owned by the calling public function.

.PARAMETER CaptureLines
    When specified, the output lines are buffered so that they can be captured. Without
    it the lines are only streamed to the pipeline.

.PARAMETER CaptureStdErr
    When specified, STDERR is redirected even when called from the prompt, so that the
    STDERR lines can be captured.

.NOTES
    The execution options are applied around the script block and undone in reverse
    order in the finally block: working directory, environment, priority. With -Elevate
    in a non-elevated session they are not applied here at all, but handed to the
    elevated process, which applies them around its own run.
#>
function Invoke-NativeApplicationCore {
    [CmdletBinding()]
    param(
        [Parameter()][ScriptBlock] $ScriptBlock,
        [Parameter()][HashTable] $ArgumentList,
        [Parameter()][int[]] $AllowedExitCodes = @(0),
        [Parameter()][switch] $IgnoreExitCode,
        [Parameter()][string] $ErrorMessage,
        [Parameter()][string] $CallSite,
        # The retry options reach the core only to be handed to the elevated process; a
        # non-elevated retry loop lives in Invoke-NativeApplicationWithRetry.
        [Parameter()][int] $MaxRetries,
        [Parameter()][string] $RetryTriggerErrorPattern,
        [Parameter()][double] $RetryDelaySeconds,
        [Parameter()][string] $WorkingDirectory,
        [Parameter()][HashTable] $Environment,
        [Parameter()][string] $LogPath,
        [Parameter()][switch] $AppendLog,
        # No ValidateSet here: Windows PowerShell's GetNewClosure() below re-validates every
        # attributed variable it copies, and an unset Priority would fail it.
        [Parameter()][string] $Priority,
        [Parameter()][switch] $Elevate,
        # No validation attribute either, for the same GetNewClosure() reason.
        [Parameter()][string[]] $Redact,
        [Parameter(Mandatory=$true)][HashTable] $Capture,
        [Parameter()][switch] $CaptureLines,
        [Parameter()][switch] $CaptureStdErr
    )

    if (($Priority -or $Elevate) -and (-not (Test-IsWindows))) {
        throw 'The -Priority and -Elevate parameters are supported on Windows only.'
    }

    $useElevation = $Elevate -and (-not (Test-IsElevated))

    if ($WorkingDirectory) {
        $WorkingDirectory = (Resolve-Path -LiteralPath $WorkingDirectory -ErrorAction Stop).ProviderPath
    } elseif ($useElevation) {
        # An elevated process starts in the system directory, so pass the caller's location on.
        $WorkingDirectory = (Get-Location -PSProvider FileSystem).ProviderPath
    }

    $backupErrorActionPreference = $ErrorActionPreference
    $command = $ScriptBlock.ToString().Trim()

    if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
        $command = '{0} with parameters {1}' -f $command, ([PSCustomObject] $ArgumentList)
    }

    $command = Hide-SecretValue -Text $command -Secret $Redact

    $startTime = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = $null
    $failureMessage = $null
    $capturedOutput = $null

    if ($CaptureLines) {
        $capturedOutput = New-Object -TypeName System.Collections.ArrayList
    }

    # The last STDERR lines, kept whatever is captured, for the exit code exception message.
    $stdErrTail = New-Object -TypeName System.Collections.Generic.Queue[string]
    $stdErrLineCount = 0

    $locationPushed = $false
    $savedEnvironment = $null
    $savedPriority = $null
    $logWriter = $null
    $elevatedResult = @{}

    $ErrorActionPreference = "Continue"
    try {
        if ($LogPath) {
            $logWriter = New-LogWriter -Path $LogPath -Append:$AppendLog
        }

        if (-not $useElevation) {
            if ($WorkingDirectory) {
                Push-Location -LiteralPath $WorkingDirectory -StackName 'Invoke-NativeApplication' -ErrorAction Stop
                $locationPushed = $true
            }

            if ($null -ne $Environment) {
                $savedEnvironment = Set-EnvironmentOverride -Environment $Environment
            }

            if ($Priority) {
                $savedPriority = Get-CurrentProcessPriority
                Set-CurrentProcessPriority -PriorityClass ([System.Diagnostics.ProcessPriorityClass] $Priority)
            }
        }

        Write-Verbose -Message ('Executing native application {0}' -f $command)
        if ($useElevation) {
            $elevatedOptions = @{
                ScriptBlock      = $ScriptBlock
                ArgumentList     = $ArgumentList
                WorkingDirectory = $WorkingDirectory
                Environment      = $Environment
                Priority         = $Priority
                Result           = $elevatedResult
            }

            if ($MaxRetries -gt 0) {
                $elevatedOptions['AllowedExitCodes'] = $AllowedExitCodes
                $elevatedOptions['MaxRetries'] = $MaxRetries
                $elevatedOptions['RetryTriggerErrorPattern'] = $RetryTriggerErrorPattern
                $elevatedOptions['RetryDelaySeconds'] = $RetryDelaySeconds
            }

            # No closure here: a closure is bound to a new dynamic module, which cannot see
            # this module's private functions.
            $wrapperScriptBlock = { Invoke-ElevatedScriptBlock @elevatedOptions }
        } elseif ($CaptureStdErr -or (-not (Test-CalledFromPrompt))) {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList 2>&1 }.GetNewClosure()
        } else {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList }.GetNewClosure()
        }

        & $wrapperScriptBlock | ForEach-Object -Process {
            if ($useElevation) {
                # Invoke-ElevatedScriptBlock already hands back OutputLine objects.
                $outputLine = $_
            } else {
                $isError = $_ -is [System.Management.Automation.ErrorRecord]

                if ($isError) {
                    $message = $_.Exception.Message
                } else {
                    $message = "$_"
                }

                $outputLine = New-Object -TypeName InvokeNativeApplication.OutputLine -ArgumentList $message, $isError
            }

            if ($null -ne $capturedOutput) {
                $null = $capturedOutput.Add($outputLine)
            }

            if ($outputLine.IsError) {
                $stdErrLineCount++
                $stdErrTail.Enqueue((Hide-SecretValue -Text $outputLine.ToString() -Secret $Redact))

                if ($stdErrTail.Count -gt $script:ExceptionStdErrLineLimit) {
                    $null = $stdErrTail.Dequeue()
                }
            }

            if ($null -ne $logWriter) {
                $logLine = Hide-SecretValue -Text $outputLine.ToString() -Secret $Redact

                if ($outputLine.IsError) {
                    $logWriter.WriteLine('[ERR] ' + $logLine)
                } else {
                    $logWriter.WriteLine($logLine)
                }
            }

            $outputLine
        }

        if ($useElevation) {
            $exitCode = $elevatedResult['ExitCode']

            if ($null -ne $exitCode) {
                $global:LASTEXITCODE = $exitCode
            }
        } elseif (Test-Path -Path Variable:LASTEXITCODE) {
            $exitCode = $LASTEXITCODE
        }

        if (($null -ne $exitCode) -and ($AllowedExitCodes -notcontains $exitCode)) {
            if (-not $CallSite) {
                $CallSite = (Get-PSCallStack -ErrorAction SilentlyContinue)[2].Location
            }

            $message = 'Native application {0} failed at {1} with exit code {2}' -f $command, $CallSite, $exitCode

            # The caller's own text leads, as psake's Exec -ErrorMessage and Invoke-Build's
            # exec -ErrorMessage put it.
            if ($ErrorMessage) {
                $message = (Hide-SecretValue -Text $ErrorMessage -Secret $Redact) + [Environment]::NewLine + $message
            }

            # Built even with -IgnoreExitCode, because -RetryTriggerErrorPattern matches it.
            $failureMessage = $message + (Format-StdErrTail -Lines $stdErrTail.ToArray() -TotalCount $stdErrLineCount)

            if (-not $IgnoreExitCode) {
                throw $failureMessage
            }
        }
    } finally {
        $stopwatch.Stop()

        if ($null -ne $savedPriority) {
            Set-CurrentProcessPriority -PriorityClass $savedPriority
        }

        if ($null -ne $savedEnvironment) {
            Restore-EnvironmentOverride -SavedEnvironment $savedEnvironment
        }

        if ($locationPushed) {
            Pop-Location -StackName 'Invoke-NativeApplication'
        }

        if ($null -ne $logWriter) {
            $logWriter.Dispose()
        }

        $ErrorActionPreference = $backupErrorActionPreference

        $Capture['Command'] = $command
        $Capture['StartTime'] = $startTime
        $Capture['EndTime'] = $startTime + $stopwatch.Elapsed
        $Capture['Duration'] = $stopwatch.Elapsed
        $Capture['ExitCode'] = $exitCode
        $Capture['Success'] = ($null -eq $exitCode) -or ($AllowedExitCodes -contains $exitCode)
        $Capture['FailureMessage'] = $failureMessage

        if ($null -ne $capturedOutput) {
            $Capture['Output'] = $capturedOutput.ToArray()
            $Capture['StdOut'] = @($capturedOutput | Where-Object -FilterScript { -not $_.IsError })
            $Capture['StdErr'] = @($capturedOutput | Where-Object -FilterScript { $_.IsError })
        }
    }
}

<#
.SYNOPSIS
    Formats the STDERR section appended to the exit code exception message.
.DESCRIPTION
    Returns an empty string when there was no STDERR, so the message stays one line.
    Otherwise returns a newline, a 'STDERR:' header (naming the cap when lines were
    dropped) and the lines, each on its own line. The idea of carrying STDERR in the
    error comes from psake's Exec and Invoke-Build's exec -StdErr.
#>
function Format-StdErrTail {
    param(
        [Parameter()][AllowEmptyCollection()][string[]] $Lines,
        [Parameter()][int] $TotalCount
    )

    if (($null -eq $Lines) -or ($Lines.Count -eq 0)) {
        return ''
    }

    if ($TotalCount -gt $Lines.Count) {
        $header = 'STDERR (last {0} of {1} lines):' -f $Lines.Count, $TotalCount
    } else {
        $header = 'STDERR:'
    }

    return [Environment]::NewLine + $header + [Environment]::NewLine + ($Lines -join [Environment]::NewLine)
}

<#
.SYNOPSIS
    Replaces every occurrence of each secret value in a text with the redaction mask.
.DESCRIPTION
    The longest values go first, so a secret containing another one is masked whole.
    Matching is ordinal and case-sensitive. Empty and $null values are skipped, since
    they would match everywhere.
#>
function Hide-SecretValue {
    param(
        [Parameter()][AllowNull()][AllowEmptyString()][string] $Text,
        [Parameter()][AllowNull()][AllowEmptyCollection()][string[]] $Secret
    )

    if ([string]::IsNullOrEmpty($Text) -or ($null -eq $Secret)) {
        return $Text
    }

    $values = @($Secret | Where-Object -FilterScript { -not [string]::IsNullOrEmpty($_) } | Sort-Object -Property Length -Descending)

    foreach ($value in $values) {
        $Text = $Text.Replace($value, $script:RedactionMask)
    }

    return $Text
}

<#
.SYNOPSIS
    Runs Invoke-NativeApplicationCore, re-running it after a failed attempt as psake's
    Exec -maxRetries does.

.DESCRIPTION
    The retry loop follows psake's Exec (https://github.com/psake/psake,
    src/public/Execute.ps1, MIT): a failed attempt is retried while retries are left and,
    with a pattern, while the failure text matches it, after a pause. Unlike Exec, a
    disallowed exit code counts as a failure even with -IgnoreExitCode, the pause is
    configurable, and the Capture hashtable holds the last attempt only.

    With -Elevate in a non-elevated session the attempts are left to the elevated
    process, so the user sees one UAC prompt rather than one per attempt.
#>
function Invoke-NativeApplicationWithRetry {
    param(
        [Parameter()][HashTable] $CoreParameters,
        [Parameter(Mandatory=$true)][HashTable] $Capture,
        [Parameter()][int] $MaxRetries,
        [Parameter()][string] $RetryTriggerErrorPattern,
        [Parameter()][double] $RetryDelaySeconds
    )

    if (($MaxRetries -gt 0) -and $CoreParameters['Elevate'] -and (Test-IsWindows) -and (-not (Test-IsElevated))) {
        $CoreParameters['MaxRetries'] = $MaxRetries
        $CoreParameters['RetryTriggerErrorPattern'] = $RetryTriggerErrorPattern
        $CoreParameters['RetryDelaySeconds'] = $RetryDelaySeconds
        $MaxRetries = 0
    }

    if ($MaxRetries -le 0) {
        Invoke-NativeApplicationCore @CoreParameters -Capture $Capture
        return
    }

    $attempt = 1

    while ($true) {
        $attemptCapture = @{}
        $failureRecord = $null

        try {
            Invoke-NativeApplicationCore @CoreParameters -Capture $attemptCapture
        } catch [System.Management.Automation.PipelineStoppedException] {
            throw
        } catch {
            $failureRecord = $_
        } finally {
            $Capture.Clear()

            foreach ($key in $attemptCapture.Keys) {
                $Capture[$key] = $attemptCapture[$key]
            }
        }

        if ($null -ne $failureRecord) {
            $failureText = $failureRecord.Exception.Message
        } elseif ($attemptCapture['Success']) {
            return
        } else {
            $failureText = $attemptCapture['FailureMessage']
        }

        $retry = $attempt -le $MaxRetries

        if ($retry -and $RetryTriggerErrorPattern) {
            $matchText = $failureText

            if ($null -ne $attemptCapture['StdErr']) {
                $matchText = $matchText + [Environment]::NewLine + (@($attemptCapture['StdErr']) -join [Environment]::NewLine)
            }

            $retry = [regex]::IsMatch($matchText, $RetryTriggerErrorPattern)
        }

        if (-not $retry) {
            if ($null -ne $failureRecord) {
                throw $failureRecord
            }

            return
        }

        # The command text can span lines, so the warning names the cause alone.
        if (($null -eq $failureRecord) -or ($null -ne $attemptCapture['FailureMessage'])) {
            $cause = ' with exit code {0}' -f $attemptCapture['ExitCode']
        } else {
            $cause = ': ' + @((Hide-SecretValue -Text "$failureText" -Secret $CoreParameters['Redact']) -split '\r?\n')[0]
        }

        Write-Warning -Message ('Attempt {0} of {1} failed{2}. Retrying in {3} s.' -f $attempt, ($MaxRetries + 1), $cause, $RetryDelaySeconds)

        if ($RetryDelaySeconds -gt 0) {
            Start-Sleep -Milliseconds ([int] ($RetryDelaySeconds * 1000))
        }

        # A later attempt adds to the log instead of overwriting the earlier attempts.
        if ($CoreParameters['LogPath']) {
            $CoreParameters['AppendLog'] = $true
        }

        $attempt++
    }
}

<#
.SYNOPSIS
    Builds the Invoke-NativeApplicationCore parameters a public function shares: the
    execution options and the capture switches.
#>
function Get-CoreParameter {
    param(
        [Parameter()][HashTable] $BoundParameters,
        [Parameter()][int] $MaxRetries,
        [Parameter()][string] $RetryTriggerErrorPattern
    )

    $coreParameters = Get-ExecutionOption -BoundParameters $BoundParameters

    # A retry pattern is matched against every STDERR line, so they must pass through
    # the pipeline and be buffered.
    $matchStdErr = ($MaxRetries -gt 0) -and (-not [string]::IsNullOrEmpty($RetryTriggerErrorPattern))

    $coreParameters['CaptureLines'] = $matchStdErr -or (Test-CaptureRequested -BoundParameters $BoundParameters -ParameterName $script:LineCaptureParameters)
    $coreParameters['CaptureStdErr'] = $matchStdErr -or (Test-CaptureRequested -BoundParameters $BoundParameters -ParameterName @('StdErrVariable', 'OutputVariable'))

    return $coreParameters
}

<#
.SYNOPSIS
    Validates a -RetryTriggerErrorPattern value, throwing a readable error for an invalid
    regular expression.
#>
function Test-RegexPattern {
    param(
        [Parameter()][string] $Pattern
    )

    try {
        $null = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList $Pattern
    } catch {
        throw ('Invalid regular expression {0}: {1}' -f $Pattern, $_.Exception.InnerException.Message)
    }

    return $true
}

<#
.SYNOPSIS
    Tells whether any of the given out parameters was passed a non-empty variable name.
#>
function Test-CaptureRequested {
    param(
        [Parameter()][HashTable] $BoundParameters,
        [Parameter()][string[]] $ParameterName
    )

    foreach ($name in $ParameterName) {
        if ($BoundParameters.ContainsKey($name) -and (-not [string]::IsNullOrEmpty($BoundParameters[$name]))) {
            return $true
        }
    }

    return $false
}

<#
.SYNOPSIS
    Sets the requested out variables in the caller's scope.

.DESCRIPTION
    $PSCmdlet.SessionState of the public function refers to the session state of its
    caller, which is what makes the variables land in the end user's scope.
#>
function Set-CaptureVariable {
    param(
        [Parameter()][System.Management.Automation.SessionState] $SessionState,
        [Parameter()][HashTable] $BoundParameters,
        [Parameter()][HashTable] $Capture
    )

    foreach ($parameterName in $script:CaptureVariableParameters.Keys) {
        if (-not (Test-CaptureRequested -BoundParameters $BoundParameters -ParameterName $parameterName)) {
            continue
        }

        $variableName = ([string] $BoundParameters[$parameterName]).TrimStart('$')
        $captureKey = $script:CaptureVariableParameters[$parameterName]

        if ($Capture.ContainsKey($captureKey)) {
            $value = $Capture[$captureKey]
        } else {
            $value = $null
        }

        $SessionState.PSVariable.Set($variableName, $value)
    }
}

<#
.SYNOPSIS
    Picks the execution options out of a public function's bound parameters, for splatting
    into Invoke-NativeApplicationCore.
#>
function Get-ExecutionOption {
    param(
        [Parameter()][HashTable] $BoundParameters
    )

    $options = @{}

    foreach ($name in $script:ExecutionOptionParameters) {
        if ($BoundParameters.ContainsKey($name)) {
            $options[$name] = $BoundParameters[$name]
        }
    }

    return $options
}

function Test-IsWindows {
    return [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

function Test-IsElevated {
    $principal = New-Object -TypeName System.Security.Principal.WindowsPrincipal -ArgumentList ([System.Security.Principal.WindowsIdentity]::GetCurrent())
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    Reads the priority class of the PowerShell process itself.
.DESCRIPTION
    A separate function so tests can mock it: the live class can be changed at any
    moment by something outside, such as a job object or a scheduler.
#>
function Get-CurrentProcessPriority {
    return [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
}

<#
.SYNOPSIS
    Sets the priority class of the PowerShell process itself, which its Windows
    children inherit.
#>
function Set-CurrentProcessPriority {
    param(
        [Parameter()][System.Diagnostics.ProcessPriorityClass] $PriorityClass
    )

    [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass = $PriorityClass
}

<#
.SYNOPSIS
    Opens the -LogPath file for writing, as UTF-8 without a BOM, flushing every line.
#>
function New-LogWriter {
    param(
        [Parameter()][string] $Path,
        [Parameter()][switch] $Append
    )

    $fullPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    $encoding = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false
    $writer = New-Object -TypeName System.IO.StreamWriter -ArgumentList $fullPath, ([bool] $Append), $encoding
    $writer.AutoFlush = $true
    return $writer
}

<#
.SYNOPSIS
    Applies environment variable overrides to the process and returns the previous values.
#>
function Set-EnvironmentOverride {
    param(
        [Parameter()][HashTable] $Environment
    )

    $saved = @{}

    foreach ($name in $Environment.Keys) {
        $saved[[string] $name] = [System.Environment]::GetEnvironmentVariable([string] $name)
    }

    foreach ($name in $Environment.Keys) {
        $value = $Environment[$name]

        Set-ProcessEnvironmentVariable -Name ([string] $name) -Value $value
    }

    return $saved
}

function Restore-EnvironmentOverride {
    param(
        [Parameter()][HashTable] $SavedEnvironment
    )

    foreach ($name in $SavedEnvironment.Keys) {
        Set-ProcessEnvironmentVariable -Name $name -Value $SavedEnvironment[$name]
    }
}

<#
.SYNOPSIS
    Sets a process environment variable, or removes it for a $null value.

.DESCRIPTION
    PowerShell turns a $null passed to a .NET string parameter into an empty string, which
    would leave an empty variable behind instead of removing it. [NullString]::Value is
    passed through as a real null.
#>
function Set-ProcessEnvironmentVariable {
    param(
        [Parameter()][string] $Name,
        [Parameter()][AllowNull()][object] $Value
    )

    if ($null -eq $Value) {
        [System.Environment]::SetEnvironmentVariable($Name, [NullString]::Value)
    } else {
        [System.Environment]::SetEnvironmentVariable($Name, [string] $Value)
    }
}

<#
.SYNOPSIS
    Runs a script block in an elevated PowerShell process and emits its output lines.

.DESCRIPTION
    The request (script block text, arguments and execution options) goes to the elevated
    process as a CliXml file, and the response (output lines, exit code, error) comes
    back the same way, because an elevated process can share neither the console nor the
    pipes of a non-elevated one. The elevated process runs the same PowerShell edition as
    the caller, from $PSHOME, and loads this module from the same directory.

.PARAMETER Result
    Hashtable receiving the ExitCode of the native application.
#>
function Invoke-ElevatedScriptBlock {
    param(
        [Parameter()][ScriptBlock] $ScriptBlock,
        [Parameter()][HashTable] $ArgumentList,
        [Parameter()][string] $WorkingDirectory,
        [Parameter()][HashTable] $Environment,
        [Parameter()][string] $Priority,
        [Parameter()][int[]] $AllowedExitCodes,
        [Parameter()][int] $MaxRetries,
        [Parameter()][string] $RetryTriggerErrorPattern,
        [Parameter()][double] $RetryDelaySeconds,
        [Parameter()][HashTable] $Result
    )

    $exchangeDirectory = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('Invoke-NativeApplication-' + [System.Guid]::NewGuid().ToString('N'))
    $null = New-Item -Path $exchangeDirectory -ItemType Directory -ErrorAction Stop

    try {
        $requestPath = Join-Path -Path $exchangeDirectory -ChildPath 'request.xml'
        $responsePath = Join-Path -Path $exchangeDirectory -ChildPath 'response.xml'

        $request = New-Object -TypeName PSObject -Property @{
            ScriptBlock      = $ScriptBlock.ToString()
            ArgumentList     = $ArgumentList
            WorkingDirectory = $WorkingDirectory
            Environment      = $Environment
            Priority         = $Priority
            AllowedExitCodes = $AllowedExitCodes
            MaxRetries       = $MaxRetries
            RetryTriggerErrorPattern = $RetryTriggerErrorPattern
            RetryDelaySeconds = $RetryDelaySeconds
        }
        Export-Clixml -InputObject $request -LiteralPath $requestPath -ErrorAction Stop

        if ($PSVersionTable.PSEdition -eq 'Core') {
            $hostPath = Join-Path -Path $PSHOME -ChildPath 'pwsh.exe'
        } else {
            $hostPath = Join-Path -Path $PSHOME -ChildPath 'powershell.exe'
        }

        $argumentString = '-NoProfile -NonInteractive -File "{0}" -RequestPath "{1}" -ResponsePath "{2}"' -f $script:ElevatedRunnerPath, $requestPath, $responsePath
        $hostExitCode = Start-ElevatedHost -FilePath $hostPath -ArgumentString $argumentString

        if (-not (Test-Path -LiteralPath $responsePath)) {
            throw ('The elevated PowerShell process exited with code {0} without a response.' -f $hostExitCode)
        }

        $response = Import-Clixml -LiteralPath $responsePath -ErrorAction Stop

        if ($response.Error) {
            throw ('The elevated PowerShell process failed: {0}' -f $response.Error)
        }

        $Result['ExitCode'] = $response.ExitCode

        foreach ($line in @($response.Lines)) {
            if ($null -ne $line) {
                New-Object -TypeName InvokeNativeApplication.OutputLine -ArgumentList ([string] $line.Text), ([bool] $line.IsError)
            }
        }
    } finally {
        Remove-Item -LiteralPath $exchangeDirectory -Recurse -Force -ErrorAction SilentlyContinue
    }
}

<#
.SYNOPSIS
    Starts a process elevated (UAC prompt), waits for it and returns its exit code.

.DESCRIPTION
    Kept as its own function so the tests can replace the elevation with a plain launch.
#>
function Start-ElevatedHost {
    param(
        [Parameter()][string] $FilePath,
        [Parameter()][string] $ArgumentString
    )

    $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentString -Verb RunAs -WindowStyle Hidden -Wait -PassThru -ErrorAction Stop
    return $process.ExitCode
}

function Test-CalledFromPrompt {
    foreach ($frame in Get-PSCallStack) {
        if ($frame.Command -eq "prompt") {
            return $true
        }
    }

    return $false
}

Set-Alias -Name exec -Value Invoke-NativeApplication
Set-Alias -Name safeexec -Value Invoke-NativeApplicationSafe

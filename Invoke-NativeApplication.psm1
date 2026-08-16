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

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

.PARAMETER AllowedExitCodes
    An array of exit codes considered successful. Defaults to @(0).

.PARAMETER IgnoreExitCode
    When specified, the function does not throw on non-zero exit codes.

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

    try {
        Invoke-NativeApplicationCore `
            -ScriptBlock $ScriptBlock `
            -ArgumentList $ArgumentList `
            -AllowedExitCodes $AllowedExitCodes `
            -IgnoreExitCode:$IgnoreExitCode `
            -Capture $capture `
            -CaptureLines:(Test-CaptureRequested -BoundParameters $PSBoundParameters -ParameterName $script:LineCaptureParameters) `
            -CaptureStdErr:(Test-CaptureRequested -BoundParameters $PSBoundParameters -ParameterName @('StdErrVariable', 'OutputVariable'))
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
    out of the return value are still available. See Invoke-NativeApplication for their
    description.

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

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

    try {
        Invoke-NativeApplicationCore `
            -ScriptBlock $ScriptBlock `
            -ArgumentList $ArgumentList `
            -AllowedExitCodes @(0) `
            -IgnoreExitCode `
            -Capture $capture `
            -CaptureLines:(Test-CaptureRequested -BoundParameters $PSBoundParameters -ParameterName $script:LineCaptureParameters) `
            -CaptureStdErr:(Test-CaptureRequested -BoundParameters $PSBoundParameters -ParameterName @('StdErrVariable', 'OutputVariable')) |
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
#>
function Invoke-NativeApplicationCore {
    [CmdletBinding()]
    param(
        [Parameter()][ScriptBlock] $ScriptBlock,
        [Parameter()][HashTable] $ArgumentList,
        [Parameter()][int[]] $AllowedExitCodes = @(0),
        [Parameter()][switch] $IgnoreExitCode,
        [Parameter(Mandatory=$true)][HashTable] $Capture,
        [Parameter()][switch] $CaptureLines,
        [Parameter()][switch] $CaptureStdErr
    )

    $backupErrorActionPreference = $ErrorActionPreference
    $command = $ScriptBlock.ToString().Trim()

    if (($null -ne $ArgumentList) -and ($ArgumentList.Count -gt 0)) {
        $command = '{0} with parameters {1}' -f $command, ([PSCustomObject] $ArgumentList)
    }

    $startTime = Get-Date
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $exitCode = $null
    $capturedOutput = $null

    if ($CaptureLines) {
        $capturedOutput = New-Object -TypeName System.Collections.ArrayList
    }

    $ErrorActionPreference = "Continue"
    try {
        Write-Verbose -Message ('Executing native application {0}' -f $command)
        if ($CaptureStdErr -or (-not (Test-CalledFromPrompt))) {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList 2>&1 }.GetNewClosure()
        } else {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList }.GetNewClosure()
        }

        & $wrapperScriptBlock | ForEach-Object -Process {
            $isError = $_ -is [System.Management.Automation.ErrorRecord]

            if ($isError) {
                $message = $_.Exception.Message
            } else {
                $message = "$_"
            }

            $outputLine = New-Object -TypeName InvokeNativeApplication.OutputLine -ArgumentList $message, $isError

            if ($null -ne $capturedOutput) {
                $null = $capturedOutput.Add($outputLine)
            }

            $outputLine
        }

        if (Test-Path -Path Variable:LASTEXITCODE) {
            $exitCode = $LASTEXITCODE
        }

        if ((-not $IgnoreExitCode) -and ($null -ne $exitCode) -and ($AllowedExitCodes -notcontains $exitCode)) {
            throw ('Native application {0} failed at {1} with exit code {2}' -f
                $command, (Get-PSCallStack -ErrorAction SilentlyContinue)[2].Location, $exitCode)
        }
    } finally {
        $stopwatch.Stop()
        $ErrorActionPreference = $backupErrorActionPreference

        $Capture['Command'] = $command
        $Capture['StartTime'] = $startTime
        $Capture['EndTime'] = $startTime + $stopwatch.Elapsed
        $Capture['Duration'] = $stopwatch.Elapsed
        $Capture['ExitCode'] = $exitCode
        $Capture['Success'] = ($null -eq $exitCode) -or ($AllowedExitCodes -contains $exitCode)

        if ($null -ne $capturedOutput) {
            $Capture['Output'] = $capturedOutput.ToArray()
            $Capture['StdOut'] = @($capturedOutput | Where-Object -FilterScript { -not $_.IsError })
            $Capture['StdErr'] = @($capturedOutput | Where-Object -FilterScript { $_.IsError })
        }
    }
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

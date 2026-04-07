$csPath = Join-Path -Path $PSScriptRoot -ChildPath 'NativeApplicationOutput.cs'
Add-Type -Path $csPath

<#
.SYNOPSIS
    Invokes a native application with proper STDERR handling and exit code validation.

.DESCRIPTION
    Executes a native application (external command) via a ScriptBlock, captures both
    STDOUT and STDERR streams, and validates the process exit code. Each output line is
    returned as a NativeApplicationOutput object that behaves like a string but carries
    an IsError property indicating whether it originated from STDERR.

    When called from the PowerShell prompt, STDERR is not redirected so that it displays
    with the default console formatting. When called from a script, STDERR is captured
    via 2>&1 redirection.

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

.PARAMETER AllowedExitCodes
    An array of exit codes considered successful. Defaults to @(0).

.PARAMETER IgnoreExitCode
    When specified, the function does not throw on non-zero exit codes.

.EXAMPLE
    Invoke-NativeApplication { git status }

    Runs 'git status' and throws if git returns a non-zero exit code.

.EXAMPLE
    Invoke-NativeApplication { robocopy source dest /MIR } -AllowedExitCodes @(0, 1, 2, 3)

    Runs robocopy and treats exit codes 0-3 as successful (robocopy uses
    non-zero exit codes for informational purposes).

.EXAMPLE
    $output = Invoke-NativeApplication { dotnet build } -IgnoreExitCode
    $errors = $output | Where-Object { $_.IsError }

    Captures all output including errors without throwing, then filters
    for lines that came from STDERR.

.OUTPUTS
    NativeApplicationOutput
    A string-like object with an additional IsError property.

.LINK
    https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/

.LINK
    https://mnaoumov.wordpress.com/2015/03/31/execution-of-external-commands-native-applications-in-powershell-done-right-part-2/
#>
function Invoke-NativeApplication
{
    param
    (
        [Parameter(Position=0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position=1)][HashTable] $ArgumentList,
        [Parameter()][int[]] $AllowedExitCodes = @(0),
        [Parameter()][switch] $IgnoreExitCode
    )

    $backupErrorActionPreference = $ErrorActionPreference

    $ErrorActionPreference = "Continue"
    try
    {
        Write-Verbose ('Executing native application {0} with parameters: {1}' -f $ScriptBlock, ([PSCustomObject] $ArgumentList))
        if (Test-CalledFromPrompt)
        {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList }.GetNewClosure()
        }
        else
        {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList 2>&1 }.GetNewClosure()
        }

        & $wrapperScriptBlock | ForEach-Object -Process {
            $isError = $_ -is [System.Management.Automation.ErrorRecord]

            if ($isError)
            {
                $message = $_.Exception.Message
            }
            else
            {
                $message = "$_"
            }

            New-Object -TypeName NativeApplicationOutput -ArgumentList $message, $isError
        }

        if ((-not $IgnoreExitCode) -and (Test-Path -Path Variable:LASTEXITCODE) -and ($AllowedExitCodes -notcontains $LASTEXITCODE))
        {
            throw ('Native application {0} with parameters {1} failed at {2} with exit code {3}' -f
                $ScriptBlock, ([PSCustomObject] $ArgumentList), (Get-PSCallStack -ErrorAction SilentlyContinue)[1].Location, $LASTEXITCODE)
        }
    }
    finally
    {
        $ErrorActionPreference = $backupErrorActionPreference
    }
}

<#
.SYNOPSIS
    Invokes a native application, ignoring exit codes and filtering out STDERR lines.

.DESCRIPTION
    A convenience wrapper around Invoke-NativeApplication that always ignores the exit
    code and returns only STDOUT lines (lines where IsError is false). Useful when you
    want to silently capture the successful output of a command without error noise.

.PARAMETER ScriptBlock
    The script block containing the native application invocation.

.PARAMETER ArgumentList
    A hashtable of arguments to splat into the script block.

.EXAMPLE
    $branches = Invoke-NativeApplicationSafe { git branch }

    Gets the list of git branches, ignoring any STDERR output and exit code.

.OUTPUTS
    NativeApplicationOutput
    A string-like object with an additional IsError property (always False).
#>
function Invoke-NativeApplicationSafe
{
    param
    (
        [Parameter(Position=0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position=1)][HashTable] $ArgumentList
    )

    Invoke-NativeApplication -ScriptBlock:$ScriptBlock -IgnoreExitCode -ArgumentList:$ArgumentList |
        Where-Object -FilterScript { -not $_.IsError }
}

function Test-CalledFromPrompt
{
    foreach ($frame in Get-PSCallStack)
    {
        if ($frame.Command -eq "prompt")
        {
            return $true
        }
    }

    return $false
}

Set-Alias -Name exec -Value Invoke-NativeApplication
Set-Alias -Name safeexec -Value Invoke-NativeApplicationSafe

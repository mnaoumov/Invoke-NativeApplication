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
        Write-Verbose 'Executing native application with parameters: {0}' -f  [PSCustomObject] $ArgumentList
        if (Test-CalledFromPrompt)
        {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList }
        }
        else
        {
            $wrapperScriptBlock = { & $ScriptBlock @ArgumentList 2>&1 }
        }

        & $wrapperScriptBlock | ForEach-Object -Process `
            {
                $isError = $_ -is [System.Management.Automation.ErrorRecord]
                "$_" | Add-Member -Name IsError -MemberType NoteProperty -Value $isError -PassThru
            }
        if ((-not $IgnoreExitCode) -and (Test-Path -Path Variable:LASTEXITCODE) -and ($AllowedExitCodes -notcontains $LASTEXITCODE))
        {
            throw "Native application with parameters {0} failed with exit code $LASTEXITCODE" -f [PSCustomObject] $ArgumentList
        }
    }
    finally
    {
        $ErrorActionPreference = $backupErrorActionPreference
    }
}

function Invoke-NativeApplicationSafe
{
    param
    (
        [ScriptBlock] $ScriptBlock
    )

    Invoke-NativeApplication -ScriptBlock $ScriptBlock -IgnoreExitCode | `
        Where-Object -FilterScript { -not $_.IsError }
}

function Test-CalledFromPrompt
{
    (Get-PSCallStack)[-2].Command -eq "prompt"
}

Set-Alias -Name exec -Value Invoke-NativeApplication
Set-Alias -Name safeexec -Value Invoke-NativeApplicationSafe

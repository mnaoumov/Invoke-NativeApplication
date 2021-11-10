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
            throw ('Native application {0} with parameters {1} failed at {2} with exit code {3}' -f
                $ScriptBlock, ([PSCustomObject] $ArgumentList), (Get-PSCallStack -ErrorAction:SilentlyContinue)[1].Location, $LASTEXITCODE)
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
        [Parameter(Position=0)][ScriptBlock] $ScriptBlock,
        [Parameter(Position=1)][HashTable] $ArgumentList
    )

    Invoke-NativeApplication -ScriptBlock:$ScriptBlock -IgnoreExitCode -ArgumentList:$ArgumentList| `
        Where-Object -FilterScript { -not $_.IsError }
}

function Test-CalledFromPrompt
{
    (Get-PSCallStack)[-2].Command -eq "prompt"
}

Set-Alias -Name exec -Value Invoke-NativeApplication
Set-Alias -Name safeexec -Value Invoke-NativeApplicationSafe

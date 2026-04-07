[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
trap { throw $Error[0] }

$requiredPesterVersion = '5.7.1'

$pester = Get-Module -Name Pester -ListAvailable |
    Where-Object -FilterScript { $_.Version -ge [version]$requiredPesterVersion } |
    Sort-Object -Property Version -Descending |
    Select-Object -First 1

if (-not $pester)
{
    Write-Host "Installing Pester $requiredPesterVersion..."
    Install-Module -Name Pester -MinimumVersion $requiredPesterVersion -Force -Scope CurrentUser -SkipPublisherCheck
}

Write-Host 'Running tests...'
$result = Invoke-Pester -Path $PSScriptRoot -Output Detailed -PassThru

if ($result.FailedCount -gt 0)
{
    throw "$($result.FailedCount) test(s) failed."
}

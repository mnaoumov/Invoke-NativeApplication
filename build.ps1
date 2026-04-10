[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
trap { throw $Error[0] }

# Bootstrap PSDepend
if (-not (Get-Module -Name PSDepend -ListAvailable)) {
    Write-Host 'Installing PSDepend...'
    Install-Module -Name PSDepend -Force -Scope CurrentUser
}

# Install dependencies from requirements.psd1
Write-Host 'Installing dependencies...'
Invoke-PSDepend -Path "$PSScriptRoot/requirements.psd1" -Install -Import -Force

# Run tests
Write-Host 'Running tests...'
$result = Invoke-Pester -Path $PSScriptRoot -Output Detailed -PassThru

if ($result.FailedCount -gt 0) {
    throw "$($result.FailedCount) test(s) failed."
}

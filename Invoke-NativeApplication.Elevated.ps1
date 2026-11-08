<#
.SYNOPSIS
    The elevated half of Invoke-NativeApplication -Elevate. Not meant to be run directly.

.DESCRIPTION
    Reads the request the non-elevated caller exported as CliXml, runs its script block
    through Invoke-NativeApplication with the same execution options, and exports the
    output lines, the exit code and any error as CliXml for the caller to replay. The
    response is written in every case, so the caller can tell a failure from a missing
    process.

.PARAMETER RequestPath
    CliXml file holding the script block text, ArgumentList, WorkingDirectory,
    Environment and Priority.

.PARAMETER ResponsePath
    CliXml file receiving Lines (Text and IsError each), ExitCode and Error.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string] $RequestPath,
    [Parameter(Mandatory = $true)][string] $ResponsePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$response = New-Object -TypeName PSObject -Property @{
    Lines    = @()
    ExitCode = $null
    Error    = $null
}

try {
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Invoke-NativeApplication.psd1') -Force

    $request = Import-Clixml -LiteralPath $RequestPath
    $parameters = @{
        ScriptBlock      = [ScriptBlock]::Create($request.ScriptBlock)
        IgnoreExitCode   = $true
        OutputVariable   = 'output'
        ExitCodeVariable = 'exitCode'
    }

    if ($null -ne $request.ArgumentList) {
        $parameters['ArgumentList'] = $request.ArgumentList
    }

    if ($request.WorkingDirectory) {
        $parameters['WorkingDirectory'] = $request.WorkingDirectory
    }

    if ($null -ne $request.Environment) {
        $parameters['Environment'] = $request.Environment
    }

    if ($request.Priority) {
        $parameters['Priority'] = $request.Priority
    }

    $output = @()
    $exitCode = $null
    Invoke-NativeApplication @parameters | Out-Null

    $response.Lines = @($output | ForEach-Object -Process {
        New-Object -TypeName PSObject -Property @{
            Text    = $_.ToString()
            IsError = $_.IsError
        }
    })
    $response.ExitCode = $exitCode
} catch {
    $response.Error = $_.Exception.Message
} finally {
    Export-Clixml -InputObject $response -LiteralPath $ResponsePath
}

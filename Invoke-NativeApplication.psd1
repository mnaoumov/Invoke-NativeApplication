@{
    RootModule        = 'Invoke-NativeApplication.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '2e0ffa09-0307-4400-a36f-f276425c3bd3'
    Author            = 'Michael Naumov'
    Copyright         = '(c) Michael Naumov. All rights reserved.'
    Description       = 'A set of helper functions to invoke native applications in PowerShell with proper error messages and exit code handlers'
    PowerShellVersion = '3.0'

    FormatsToProcess  = @('Invoke-NativeApplication.format.ps1xml')

    FileList          = @(
        'Invoke-NativeApplication.format.ps1xml'
        'Invoke-NativeApplication.psd1'
        'Invoke-NativeApplication.psm1'
        'NativeApplicationOutput.cs'
    )

    FunctionsToExport = @(
        'Invoke-NativeApplication'
        'Invoke-NativeApplicationSafe'
    )
    CmdletsToExport   = @()
    AliasesToExport   = @(
        'exec'
        'safeexec'
    )

    PrivateData = @{
        PSData = @{
            Tags       = @('native', 'application', 'exec', 'stderr', 'exitcode')
            LicenseUri = 'https://github.com/mnaoumov/Invoke-NativeApplication/blob/master/LICENSE.md'
            ProjectUri = 'https://github.com/mnaoumov/Invoke-NativeApplication'
        }
    }
}

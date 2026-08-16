<#
.SYNOPSIS
    Releases the module: runs the tests, bumps the version, tags, pushes, publishes to the
    PowerShell Gallery and creates the GitHub release.

.DESCRIPTION
    The single entry point for cutting a release. Every step is idempotent-ish in the sense
    that the skip switches let a partially failed run be resumed without redoing the parts
    that already landed.

    Steps, in order:
      1. Verify the working tree is clean and the current branch is the default one.
      2. Run the test suite via build.ps1 (skip with -SkipTests).
      3. Bump ModuleVersion in the manifest.
      4. Commit the bump as 'chore: bump version to <version>' and tag it 'v<version>'.
      5. Push the commit and the tag.
      6. Publish to the PowerShell Gallery (skip with -SkipGallery).
      7. Create the GitHub release with generated notes (skip with -SkipGitHubRelease).

    Only the files listed in the manifest's FileList are published, so the tests, this script
    and build.ps1 stay out of the published package.

.PARAMETER BumpType
    Which version part to increase. Defaults to Minor. Ignored when -Version is given.

.PARAMETER Version
    Explicit version to release, e.g. '2.0.0'. Overrides -BumpType.

.PARAMETER ApiKey
    The PowerShell Gallery API key. When omitted it is read from the PSGALLERY_API_KEY
    environment variable, and failing that from Bitwarden (see -BitwardenItemName), which
    must already be unlocked.

.PARAMETER BitwardenItemName
    Name of the Bitwarden item holding the PowerShell Gallery API key as its password.

.PARAMETER PublishOnly
    Publishes the version already in the manifest instead of bumping to a new one: no version
    change, no commit, no tag, no push. For resuming a run that already pushed its bump but
    could not reach the PowerShell Gallery, e.g. because no API key was available at the time.

.PARAMETER SkipTests
    Skips build.ps1. Only for resuming a run whose tests already passed.

.PARAMETER SkipGallery
    Skips publishing to the PowerShell Gallery.

.PARAMETER SkipGitHubRelease
    Skips creating the GitHub release.

.PARAMETER DryRun
    Reports every step without changing the manifest, committing, pushing or publishing.

.EXAMPLE
    ./deploy.ps1 -DryRun

    Shows what a minor release would do.

.EXAMPLE
    ./deploy.ps1

    Releases the next minor version.

.EXAMPLE
    ./deploy.ps1 -BumpType Patch

    Releases the next patch version.

.EXAMPLE
    ./deploy.ps1 -Version 2.0.0 -SkipTests

    Releases an explicit version without re-running the tests.

.EXAMPLE
    ./deploy.ps1 -PublishOnly -SkipTests

    Publishes the already committed, tagged and pushed version to the PowerShell Gallery.
#>

[CmdletBinding()]
param(
    [Parameter()][ValidateSet('Major', 'Minor', 'Patch')][string] $BumpType = 'Minor',
    [Parameter()][string] $Version,
    [Parameter()][string] $ApiKey,
    [Parameter()][string] $BitwardenItemName = 'PowerShell Gallery',
    [Parameter()][switch] $PublishOnly,
    [Parameter()][switch] $SkipTests,
    [Parameter()][switch] $SkipGallery,
    [Parameter()][switch] $SkipGitHubRelease,
    [Parameter()][switch] $DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
trap {
    # $Error[0] reports the real fault line; a different exception there means it is stale.
    if ($Error.Count -gt 0 -and [object]::ReferenceEquals($Error[0].Exception, $_.Exception)) {
        throw $Error[0]
    }
    throw $_
}

$script:ModuleName = 'Invoke-NativeApplication'
$script:ManifestPath = Join-Path -Path $PSScriptRoot -ChildPath "$script:ModuleName.psd1"
$script:DefaultBranch = 'main'
$script:Repository = 'mnaoumov/Invoke-NativeApplication'

function Write-Step {
    param(
        [Parameter()][string] $Message
    )

    Write-Host -Object ''
    Write-Host -Object ('==> {0}' -f $Message) -ForegroundColor Cyan
}

function Write-Skipped {
    param(
        [Parameter()][string] $Message
    )

    Write-Host -Object ('    skipped: {0}' -f $Message) -ForegroundColor DarkGray
}

function Assert-ReleasableRepository {
    exec { git -C $PSScriptRoot status --porcelain } -StdOutVariable 'statusLines' | Out-Null

    if (@($statusLines).Count -gt 0) {
        throw ('The working tree is not clean. Commit or stash first:{0}{1}' -f
            [System.Environment]::NewLine, ($statusLines -join [System.Environment]::NewLine))
    }

    exec { git -C $PSScriptRoot rev-parse --abbrev-ref HEAD } -StdOutVariable 'branchLines' | Out-Null
    $branch = ($branchLines -join '').Trim()

    if ($branch -ne $script:DefaultBranch) {
        throw ('Releases are cut from ''{0}'', but the current branch is ''{1}''.' -f $script:DefaultBranch, $branch)
    }

    Write-Host -Object ('    clean working tree on ''{0}''' -f $branch)
}

function Assert-TagExists {
    param(
        [Parameter()][string] $TagName
    )

    safeexec { git -C $PSScriptRoot rev-parse --verify --quiet ('refs/tags/' + $TagName) } -SuccessVariable 'isTagFound' | Out-Null

    if (-not $isTagFound) {
        throw ('-PublishOnly expects {0} to be already committed, tagged and pushed, but the tag does not exist.' -f $TagName)
    }
}

function Test-GitHubReleaseExists {
    param(
        [Parameter()][string] $TagName
    )

    safeexec { gh release view $TagName --repo $script:Repository } -SuccessVariable 'isReleaseFound' | Out-Null

    return [bool] $isReleaseFound
}

function Get-CurrentVersion {
    $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
    return [System.Version] $manifest.ModuleVersion
}

function Get-NextVersion {
    param(
        [Parameter()][System.Version] $CurrentVersion,
        [Parameter()][string] $Part
    )

    $build = [System.Math]::Max($CurrentVersion.Build, 0)

    if ($Part -eq 'Major') {
        return New-Object -TypeName System.Version -ArgumentList ($CurrentVersion.Major + 1), 0, 0
    }

    if ($Part -eq 'Minor') {
        return New-Object -TypeName System.Version -ArgumentList $CurrentVersion.Major, ($CurrentVersion.Minor + 1), 0
    }

    return New-Object -TypeName System.Version -ArgumentList $CurrentVersion.Major, $CurrentVersion.Minor, ($build + 1)
}

function Update-ModuleVersion {
    param(
        [Parameter()][System.Version] $NewVersion
    )

    $content = Get-Content -Path $script:ManifestPath -Raw
    $pattern = '(?m)^(\s*ModuleVersion\s*=\s*'')[^'']*('')'
    $updatedContent = [regex]::Replace($content, $pattern, ('${1}' + $NewVersion + '${2}'))

    if ($updatedContent -eq $content) {
        throw ('Could not find a ModuleVersion entry to update in {0}' -f $script:ManifestPath)
    }

    Set-Content -Path $script:ManifestPath -Value $updatedContent -NoNewline -Encoding utf8
    Test-ModuleManifest -Path $script:ManifestPath | Out-Null
}

function Get-BitwardenApiKey {
    param(
        [Parameter()][string] $ItemName
    )

    if (-not (Get-Command -Name bw -ErrorAction SilentlyContinue)) {
        return $null
    }

    safeexec { bw status } -StdOutVariable 'statusLines' -SuccessVariable 'isStatusOk' | Out-Null

    if (-not $isStatusOk) {
        return $null
    }

    $status = ($statusLines -join '') | ConvertFrom-Json

    if ($status.status -ne 'unlocked') {
        Write-Warning -Message ('Bitwarden is {0}. Unlock it with `bw unlock` in an interactive shell to read the API key from there.' -f $status.status)
        return $null
    }

    safeexec { bw get password $ItemName } -StdOutVariable 'passwordLines' -SuccessVariable 'isPasswordOk' | Out-Null

    if (-not $isPasswordOk) {
        Write-Warning -Message ('Bitwarden has no item named ''{0}''.' -f $ItemName)
        return $null
    }

    return ($passwordLines -join '').Trim()
}

function Get-GalleryApiKey {
    param(
        [Parameter()][string] $ProvidedApiKey,
        [Parameter()][string] $ItemName
    )

    if (-not [string]::IsNullOrWhiteSpace($ProvidedApiKey)) {
        Write-Host -Object '    API key taken from -ApiKey'
        return $ProvidedApiKey
    }

    if (-not [string]::IsNullOrWhiteSpace($env:PSGALLERY_API_KEY)) {
        Write-Host -Object '    API key taken from $env:PSGALLERY_API_KEY'
        return $env:PSGALLERY_API_KEY
    }

    $bitwardenApiKey = Get-BitwardenApiKey -ItemName $ItemName

    if (-not [string]::IsNullOrWhiteSpace($bitwardenApiKey)) {
        Write-Host -Object ('    API key taken from the Bitwarden item ''{0}''' -f $ItemName)
        return $bitwardenApiKey
    }

    $lines = @(
        'No PowerShell Gallery API key available. Provide one of:'
        '  - $env:PSGALLERY_API_KEY set in the shell running this script'
        ('  - an unlocked Bitwarden vault holding the key as the password of the item ''{0}''' -f $ItemName)
        '  - the -ApiKey parameter'
        'Never paste the key into a chat session - it would end up in the transcript.'
    )

    throw ($lines -join [System.Environment]::NewLine)
}

function Publish-ToGallery {
    param(
        [Parameter()][string] $GalleryApiKey
    )

    # Publish-Module ships the whole folder, so stage only the manifest's FileList to keep the
    # tests, build.ps1 and this script out of the published package. The staging folder must be
    # named after the module.
    $manifest = Import-PowerShellDataFile -Path $script:ManifestPath
    $stagingRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ('deploy-' + [System.Guid]::NewGuid().ToString('N'))
    $stagingPath = Join-Path -Path $stagingRoot -ChildPath $script:ModuleName

    New-Item -Path $stagingPath -ItemType Directory -Force | Out-Null

    try {
        foreach ($fileName in $manifest.FileList) {
            Copy-Item -Path (Join-Path -Path $PSScriptRoot -ChildPath $fileName) -Destination (Join-Path -Path $stagingPath -ChildPath $fileName)
        }

        Write-Host -Object ('    publishing {0} file(s): {1}' -f @($manifest.FileList).Count, (@($manifest.FileList) -join ', '))
        Publish-Module -Path $stagingPath -NuGetApiKey $GalleryApiKey -Repository PSGallery
    } finally {
        Remove-Item -Path $stagingRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Import-Module -Name $script:ManifestPath -Force

$currentVersion = Get-CurrentVersion

if ($PublishOnly) {
    if (-not [string]::IsNullOrWhiteSpace($Version)) {
        throw '-PublishOnly publishes the version already in the manifest, so it cannot be combined with -Version.'
    }

    $newVersion = $currentVersion
} elseif ([string]::IsNullOrWhiteSpace($Version)) {
    $newVersion = Get-NextVersion -CurrentVersion $currentVersion -Part $BumpType
} else {
    $newVersion = [System.Version] $Version
}

if ((-not $PublishOnly) -and ($newVersion -le $currentVersion)) {
    throw ('The new version {0} is not greater than the current version {1}.' -f $newVersion, $currentVersion)
}

$tagName = 'v{0}' -f $newVersion

if ($PublishOnly) {
    Write-Host -Object ('Publishing the already released {0} {1}{2}' -f $script:ModuleName, $newVersion, $(if ($DryRun) { ' (dry run)' } else { '' })) -ForegroundColor Green
} else {
    Write-Host -Object ('Releasing {0} {1} -> {2}{3}' -f $script:ModuleName, $currentVersion, $newVersion, $(if ($DryRun) { ' (dry run)' } else { '' })) -ForegroundColor Green
}

Write-Step -Message 'Checking the repository'
Assert-ReleasableRepository

Write-Step -Message 'Running the tests'
if ($SkipTests) {
    Write-Skipped -Message '-SkipTests'
} else {
    & (Join-Path -Path $PSScriptRoot -ChildPath 'build.ps1')
}

# Resolve the API key before touching the repository, so a missing key fails the run before it
# has committed, tagged or pushed anything.
$galleryApiKey = $null

Write-Step -Message 'Resolving the PowerShell Gallery API key'
if ($SkipGallery) {
    Write-Skipped -Message '-SkipGallery'
} else {
    $galleryApiKey = Get-GalleryApiKey -ProvidedApiKey $ApiKey -ItemName $BitwardenItemName
}

Write-Step -Message ('Bumping the manifest to {0}' -f $newVersion)
if ($PublishOnly) {
    Write-Skipped -Message '-PublishOnly'
} elseif ($DryRun) {
    Write-Skipped -Message '-DryRun'
} else {
    Update-ModuleVersion -NewVersion $newVersion
}

Write-Step -Message ('Committing and tagging {0}' -f $tagName)
if ($PublishOnly) {
    Assert-TagExists -TagName $tagName
    Write-Skipped -Message '-PublishOnly'
} elseif ($DryRun) {
    Write-Skipped -Message '-DryRun'
} else {
    $commitMessage = 'chore: bump version to {0}' -f $newVersion
    exec { git -C $PSScriptRoot add -- $script:ManifestPath }
    exec { git -C $PSScriptRoot commit -m $commitMessage }
    exec { git -C $PSScriptRoot tag -a $tagName -m $tagName }
}

Write-Step -Message 'Pushing'
if ($PublishOnly) {
    Write-Skipped -Message '-PublishOnly'
} elseif ($DryRun) {
    Write-Skipped -Message '-DryRun'
} else {
    exec { git -C $PSScriptRoot push }
    exec { git -C $PSScriptRoot push origin $tagName }
}

Write-Step -Message 'Publishing to the PowerShell Gallery'
if ($SkipGallery) {
    Write-Skipped -Message '-SkipGallery'
} elseif ($DryRun) {
    Write-Skipped -Message '-DryRun'
} else {
    Publish-ToGallery -GalleryApiKey $galleryApiKey
}

Write-Step -Message 'Creating the GitHub release'
if ($SkipGitHubRelease) {
    Write-Skipped -Message '-SkipGitHubRelease'
} elseif ($DryRun) {
    Write-Skipped -Message '-DryRun'
} elseif (Test-GitHubReleaseExists -TagName $tagName) {
    Write-Skipped -Message ('the {0} release already exists' -f $tagName)
} else {
    exec { gh release create $tagName --title $tagName --generate-notes --repo $script:Repository }
}

Write-Host -Object ''
Write-Host -Object ('{0} {1} released' -f $script:ModuleName, $newVersion) -ForegroundColor Green

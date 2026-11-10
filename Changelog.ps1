<#
.SYNOPSIS
    Builds the CHANGELOG.md section of a release from its first-parent commits. Dot-sourced by deploy.ps1.

.DESCRIPTION
    The section is laid out like the rest of CHANGELOG.md. It opens with a one-line summary. Then it lists the entries
    under '### Breaking changes', '### New', '### Fixed', '### Improved', '### Documentation' and '### Other changes',
    sorted by their Conventional Commits type. Maintenance commits (build, chore, ci, refactor, style, test) are counted
    rather than listed, unless they are marked breaking.
#>

$script:ChangelogSections = @(
    @{ Key = 'breaking'; Heading = 'Breaking changes'; Singular = 'breaking change'; Plural = 'breaking changes' }
    @{ Key = 'feat'; Heading = 'New'; Singular = 'new feature'; Plural = 'new features' }
    @{ Key = 'fix'; Heading = 'Fixed'; Singular = 'fix'; Plural = 'fixes' }
    @{ Key = 'perf'; Heading = 'Improved'; Singular = 'improvement'; Plural = 'improvements' }
    @{ Key = 'docs'; Heading = 'Documentation'; Singular = 'documentation change'; Plural = 'documentation changes' }
    @{ Key = 'other'; Heading = 'Other changes'; Singular = 'other change'; Plural = 'other changes' }
)

$script:MaintenanceCommitTypes = @('build', 'chore', 'ci', 'refactor', 'style', 'test')

$script:ConventionalSubjectPattern = '^(?<type>[a-zA-Z]+)(?:\((?<scope>[^()]*)\))?(?<breaking>!)?:\s+(?<description>\S.*)$'

function ConvertTo-ChangelogSection {
    <#
    .SYNOPSIS
        Renders the body of a changelog section, without its '## <version>' heading.

    .PARAMETER Commit
        The release's first-parent commits, each a hashtable with a Subject and a Body.
    #>
    param(
        [Parameter()][AllowEmptyCollection()][hashtable[]] $Commit = @()
    )

    $entriesBySection = @{}
    $maintenanceCount = 0

    foreach ($item in $Commit) {
        $subject = ([string] $item.Subject).Trim()
        $isBreakingFooter = ([string] $item.Body) -match '(?m)^BREAKING[ -]CHANGE:'
        $match = [regex]::Match($subject, $script:ConventionalSubjectPattern)

        if ($match.Success) {
            $type = $match.Groups['type'].Value.ToLowerInvariant()
            $scope = $match.Groups['scope'].Value
            $text = $match.Groups['description'].Value

            if ($scope) {
                $text = '**{0}:** {1}' -f $scope, $text
            }

            if ($match.Groups['breaking'].Success -or $isBreakingFooter) {
                $key = 'breaking'
            } elseif ($script:MaintenanceCommitTypes -contains $type) {
                $maintenanceCount++
                continue
            } elseif (@('feat', 'fix', 'perf', 'docs') -contains $type) {
                $key = $type
            } else {
                $key = 'other'
            }
        } else {
            $text = $subject
            $key = $(if ($isBreakingFooter) { 'breaking' } else { 'other' })
        }

        if (-not $entriesBySection.ContainsKey($key)) {
            $entriesBySection[$key] = New-Object -TypeName System.Collections.Generic.List[string]
        }

        if (-not $entriesBySection[$key].Contains($text)) {
            $entriesBySection[$key].Add($text)
        }
    }

    $phrases = @()
    $blocks = @()

    foreach ($section in $script:ChangelogSections) {
        if (-not $entriesBySection.ContainsKey($section.Key)) {
            continue
        }

        $entries = $entriesBySection[$section.Key]
        $phrases += ('{0} {1}' -f $entries.Count, $(if ($entries.Count -eq 1) { $section.Singular } else { $section.Plural }))
        $blocks += ('### {0}' -f $section.Heading)
        $blocks += (($entries | ForEach-Object -Process { '- ' + $_ }) -join "`n")
    }

    $maintenance = ''

    if ($maintenanceCount -eq 1) {
        $maintenance = ' 1 maintenance commit (tests, build, CI, refactoring, dependencies) is not listed.'
    } elseif ($maintenanceCount -gt 1) {
        $maintenance = ' {0} maintenance commits (tests, build, CI, refactoring, dependencies) are not listed.' -f $maintenanceCount
    }

    if ($phrases.Count -eq 0) {
        $summary = $(if ($maintenanceCount -eq 0) { 'This release has no changes.' } else { 'This release has maintenance changes only.' + $maintenance })
    } elseif ($phrases.Count -eq 1) {
        $summary = 'This release has {0}.{1}' -f $phrases[0], $maintenance
    } else {
        $summary = 'This release has {0} and {1}.{2}' -f ($phrases[0..($phrases.Count - 2)] -join ', '), $phrases[-1], $maintenance
    }

    return ((@($summary) + $blocks) -join "`n`n")
}

function Add-ChangelogSection {
    <#
    .SYNOPSIS
        Returns the CHANGELOG.md content with a new section inserted above the newest one.

    .PARAMETER Content
        The current CHANGELOG.md content.

    .PARAMETER Heading
        The section heading text, without the '## ' prefix, e.g. '1.4.0 (2026-11-09)'.

    .PARAMETER Body
        The section body from ConvertTo-ChangelogSection.
    #>
    param(
        [Parameter()][string] $Content,
        [Parameter()][string] $Heading,
        [Parameter()][string] $Body
    )

    $normalized = $Content -replace "`r`n", "`n"
    $section = "## $Heading`n`n$Body`n"
    $firstSection = [regex]::Match($normalized, '(?m)^## ')

    if ($firstSection.Success) {
        return $normalized.Substring(0, $firstSection.Index) + $section + "`n" + $normalized.Substring($firstSection.Index)
    }

    return $normalized.TrimEnd("`n") + "`n`n" + $section
}

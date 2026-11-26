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

$script:NotesConventionalTypes = 'feat|fix|perf|refactor|chore|docs|test|tests|build|ci|style|revert'

$script:RawNotesBulletPatterns = @(
    # '- feat(scope): subject', '- abc1234 fix: subject'. Never a bold prefix: this file writes the scope as
    # '- **scope:** subject', and 'deps', 'test' and 'build' are common scopes there.
    ('(?i)^[-*+]\s+(?:\[?[0-9a-f]{7,40}\]?(?:\([^)]*\))?\s+)?(?:' + $script:NotesConventionalTypes + ')(?:\([^)]*\))?!?:\s')
    # Conventional-changelog output: '* **scope:** subject ([abc1234](.../commit/abc1234))'
    '(?i)\(\[?[0-9a-f]{7,40}\]?(?:\([^)]*/commit/[^)]*\))?\)\s*$'
    # GitHub's generated "What's Changed": '* subject by @user in https://github.com/o/r/pull/1'
    '(?i)\sby @\S+ in https://github\.com/\S+/pull/\d+\s*$'
)

$script:NotesBoilerplatePattern = '(?i)^(?:\*\*(?:Full Changelog|npm)\*\*\s*:\s*\S+|<?https?://\S+>?)$'
$script:NotesHeadingPattern = '^#{1,6}\s'
$script:NotesBulletPattern = '^[-*+]\s+'

function Get-ReleaseNotesVerdict {
    <#
    .SYNOPSIS
        Classifies a changelog section or release body as 'readable', 'empty', 'compare-link-only' or 'raw-commit-list'.

    .DESCRIPTION
        Headings, '**Full Changelog**:' and '**npm**:' lines and bare URLs carry no reader-facing text, so a body of only
        those is 'empty', or 'compare-link-only' when one of them is a compare link. A body whose bullets are at least half
        commit subjects (a Conventional Commits prefix, a commit hash, GitHub's generated 'by @user in .../pull/n') is a
        'raw-commit-list', however it is grouped. A bold '**scope:**' prefix is not raw.

    .PARAMETER Text
        The section body or release notes.
    #>
    param(
        [Parameter()][AllowEmptyString()][AllowNull()][string] $Text
    )

    $lines = @(([string] $Text) -split '\r?\n' | ForEach-Object -Process { $_.Trim() } | Where-Object -FilterScript { $_ -ne '' })
    $content = @($lines | Where-Object -FilterScript { ($_ -notmatch $script:NotesHeadingPattern) -and ($_ -notmatch $script:NotesBoilerplatePattern) })

    if ($content.Count -eq 0) {
        if (@($lines | Where-Object -FilterScript { $_.Contains('/compare/') }).Count -gt 0) {
            return 'compare-link-only'
        }

        return 'empty'
    }

    $bullets = @($content | Where-Object -FilterScript { $_ -match $script:NotesBulletPattern })
    $rawBullets = @($bullets | Where-Object -FilterScript {
            $line = $_
            @($script:RawNotesBulletPatterns | Where-Object -FilterScript { $line -match $_ }).Count -gt 0
        })

    if (($bullets.Count -gt 0) -and ($rawBullets.Count * 2 -ge $bullets.Count)) {
        return 'raw-commit-list'
    }

    return 'readable'
}

function Assert-ReadableReleaseNotes {
    <#
    .SYNOPSIS
        Throws unless Get-ReleaseNotesVerdict calls the text 'readable'.

    .PARAMETER Text
        The section body or release notes.

    .PARAMETER Label
        What the text is, for the error message, e.g. 'The 1.4.0 CHANGELOG.md section'.
    #>
    param(
        [Parameter()][AllowEmptyString()][AllowNull()][string] $Text,
        [Parameter()][string] $Label = 'The release notes'
    )

    $verdict = Get-ReleaseNotesVerdict -Text $Text

    if ($verdict -eq 'readable') {
        return
    }

    $reasons = @{
        'empty' = 'are empty'
        'compare-link-only' = 'are only a compare link'
        'raw-commit-list' = 'are mostly raw commit subjects or hashes'
    }

    throw ('{0} {1} ({2}). Every release needs human-readable notes: write what changed for the user in CHANGELOG.md, then run the release again.' -f $Label, $reasons[$verdict], $verdict)
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

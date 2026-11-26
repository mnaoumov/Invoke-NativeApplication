BeforeAll {
    . (Join-Path -Path $PSScriptRoot -ChildPath 'Changelog.ps1')
}

Describe 'ConvertTo-ChangelogSection' {
    It 'groups entries by type and counts maintenance commits' {
        $commits = @(
            @{ Subject = 'feat: add execution options'; Body = '' }
            @{ Subject = 'docs: add issue-filing instructions'; Body = '' }
            @{ Subject = 'build: pin the dev dependency scope'; Body = '' }
            @{ Subject = 'fix(trap): report the real fault line'; Body = '' }
        )

        $expected = @(
            'This release has 1 new feature, 1 fix and 1 documentation change. 1 maintenance commit (tests, build, CI, refactoring, dependencies) is not listed.'
            ''
            '### New'
            ''
            '- add execution options'
            ''
            '### Fixed'
            ''
            '- **trap:** report the real fault line'
            ''
            '### Documentation'
            ''
            '- add issue-filing instructions'
        ) -join "`n"

        ConvertTo-ChangelogSection -Commit $commits | Should -Be $expected
    }

    It 'lists a breaking maintenance commit under breaking changes' {
        $commits = @(
            @{ Subject = 'refactor!: drop PowerShell 2 support'; Body = '' }
            @{ Subject = 'chore: tidy'; Body = "details`n`nBREAKING CHANGE: removes X" }
        )

        $result = ConvertTo-ChangelogSection -Commit $commits

        $result | Should -Match '^This release has 2 breaking changes\.'
        $result | Should -Match '(?m)^- drop PowerShell 2 support$'
        $result | Should -Match '(?m)^- tidy$'
    }

    It 'files a non-conventional subject under other changes' {
        ConvertTo-ChangelogSection -Commit @(@{ Subject = 'Merge pull request #7'; Body = '' }) |
            Should -Be "This release has 1 other change.`n`n### Other changes`n`n- Merge pull request #7"
    }

    It 'says when only maintenance commits remain' {
        ConvertTo-ChangelogSection -Commit @(@{ Subject = 'test: cover more'; Body = '' }, @{ Subject = 'ci: cache'; Body = '' }) |
            Should -Be 'This release has maintenance changes only. 2 maintenance commits (tests, build, CI, refactoring, dependencies) are not listed.'
    }

    It 'says when there are no commits' {
        ConvertTo-ChangelogSection -Commit @() | Should -Be 'This release has no changes.'
    }

    It 'lists a repeated entry once' {
        $commits = @(
            @{ Subject = 'feat: add X'; Body = '' }
            @{ Subject = 'feat: add X'; Body = '' }
        )

        ConvertTo-ChangelogSection -Commit $commits | Should -Be "This release has 1 new feature.`n`n### New`n`n- add X"
    }
}

Describe 'Add-ChangelogSection' {
    It 'inserts the section above the newest one' {
        $content = "# CHANGELOG`r`n`r`n## 1.0.0 (2026-04-07)`r`n`r`nFirst.`r`n"

        Add-ChangelogSection -Content $content -Heading '1.1.0 (2026-08-15)' -Body 'Second.' |
            Should -Be "# CHANGELOG`n`n## 1.1.0 (2026-08-15)`n`nSecond.`n`n## 1.0.0 (2026-04-07)`n`nFirst.`n"
    }

    It 'appends the first section after the title' {
        Add-ChangelogSection -Content "# CHANGELOG`n" -Heading '1.0.0 (2026-04-07)' -Body 'First.' |
            Should -Be "# CHANGELOG`n`n## 1.0.0 (2026-04-07)`n`nFirst.`n"
    }
}

Describe 'Get-ReleaseNotesVerdict' {
    It 'calls whitespace-only notes empty' {
        Get-ReleaseNotesVerdict -Text "  `n`n " | Should -Be 'empty'
        Get-ReleaseNotesVerdict -Text '' | Should -Be 'empty'
    }

    It 'calls headings and boilerplate alone empty' {
        Get-ReleaseNotesVerdict -Text "### New`n`n**npm**: https://www.npmjs.com/package/x" | Should -Be 'empty'
    }

    It 'calls a compare link alone compare-link-only' {
        Get-ReleaseNotesVerdict -Text '**Full Changelog**: https://github.com/o/r/compare/v1.2.0...v1.3.0' | Should -Be 'compare-link-only'
        Get-ReleaseNotesVerdict -Text 'https://github.com/o/r/compare/v1.2.0...v1.3.0' | Should -Be 'compare-link-only'
    }

    It 'calls Conventional Commits bullets a raw commit list' {
        $text = @('- feat(scope): add a thing', '- fix: repair a thing', '- tidy the README') -join "`n"
        Get-ReleaseNotesVerdict -Text $text | Should -Be 'raw-commit-list'
    }

    It 'calls hash-prefixed bullets a raw commit list' {
        Get-ReleaseNotesVerdict -Text "* abc1234 chore: bump`n* 0123456789 docs!: rewrite" | Should -Be 'raw-commit-list'
    }

    It 'calls conventional-changelog bullets with a trailing commit link a raw commit list' {
        Get-ReleaseNotesVerdict -Text '* **core:** add a thing ([abc1234](https://github.com/o/r/commit/abc1234))' | Should -Be 'raw-commit-list'
    }

    It 'calls GitHub generated bullets a raw commit list' {
        Get-ReleaseNotesVerdict -Text "## What's Changed`n* Add a thing by @someone in https://github.com/o/r/pull/12" | Should -Be 'raw-commit-list'
    }

    It 'does not count a bold scope prefix as raw' {
        Get-ReleaseNotesVerdict -Text "### Fixed`n`n- **deps:** update the lockfile`n- **test:** stop a flaky case" | Should -Be 'readable'
    }

    It 'calls notes readable when fewer than half the bullets are raw' {
        $text = @('- fix: repair a thing', '- Add a thing', '- Improve another thing') -join "`n"
        Get-ReleaseNotesVerdict -Text $text | Should -Be 'readable'
    }

    It 'calls prose without bullets readable' {
        Get-ReleaseNotesVerdict -Text 'This release adds working directory support.' | Should -Be 'readable'
    }

    It 'calls every section ConvertTo-ChangelogSection renders readable' {
        $commits = @(
            @{ Subject = 'feat(exec): add execution options'; Body = '' }
            @{ Subject = 'fix: report the real fault line'; Body = '' }
            @{ Subject = 'build: pin the dev dependency scope'; Body = '' }
        )

        Get-ReleaseNotesVerdict -Text (ConvertTo-ChangelogSection -Commit $commits) | Should -Be 'readable'
        Get-ReleaseNotesVerdict -Text (ConvertTo-ChangelogSection -Commit @()) | Should -Be 'readable'
    }
}

Describe 'Assert-ReadableReleaseNotes' {
    It 'passes readable notes' {
        { Assert-ReadableReleaseNotes -Text 'This release has 1 fix.' } | Should -Not -Throw
    }

    It 'names the label and the verdict when it refuses' {
        { Assert-ReadableReleaseNotes -Text '' -Label 'The 9.9.9 CHANGELOG.md section' } | Should -Throw '*The 9.9.9 CHANGELOG.md section are empty (empty)*'
        { Assert-ReadableReleaseNotes -Text '- feat: x' } | Should -Throw '*(raw-commit-list)*'
    }
}
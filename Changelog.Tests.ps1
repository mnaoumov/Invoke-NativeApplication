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

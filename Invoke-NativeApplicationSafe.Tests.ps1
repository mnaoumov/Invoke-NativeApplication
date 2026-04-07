BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'Invoke-NativeApplicationSafe' {
    Context 'filters error output' {
        It 'returns only non-error lines' {
            $result = Invoke-NativeApplicationSafe { cmd /c "echo stdout & echo stderr 1>&2" }
            $result | ForEach-Object { $_.IsError | Should -BeFalse }
        }

        It 'excludes STDERR lines from output' {
            $allOutput = Invoke-NativeApplication { cmd /c "echo stdout & echo stderr 1>&2" } -IgnoreExitCode
            $safeOutput = Invoke-NativeApplicationSafe { cmd /c "echo stdout & echo stderr 1>&2" }
            $safeOutput.Count | Should -BeLessThan $allOutput.Count
        }
    }

    Context 'ignores exit code' {
        It 'does not throw on non-zero exit code' {
            { Invoke-NativeApplicationSafe { cmd /c "exit 1" } } | Should -Not -Throw
        }

        It 'returns output even with non-zero exit code' {
            $result = @(Invoke-NativeApplicationSafe { cmd /c "echo hello & exit 1" })
            $result | Should -Not -BeNullOrEmpty
            $result[0].ToString() | Should -Be 'hello '
        }
    }

    Context 'aliases' {
        It 'safeexec alias resolves to Invoke-NativeApplicationSafe' {
            $alias = Get-Alias safeexec
            $alias.ReferencedCommand.Name | Should -Be 'Invoke-NativeApplicationSafe'
        }

        It 'safeexec alias works' {
            $result = safeexec { cmd /c "echo test & echo err 1>&2" }
            $result | ForEach-Object { $_.IsError | Should -BeFalse }
        }
    }
}

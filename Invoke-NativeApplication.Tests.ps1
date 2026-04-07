BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'Invoke-NativeApplication' {
    Context 'successful execution' {
        It 'returns output as InvokeNativeApplication.OutputLine objects' {
            $result = @(Invoke-NativeApplication { cmd /c echo hello })
            $result | Should -HaveCount 1
            $result[0] | Should -BeOfType [InvokeNativeApplication.OutputLine]
            $result[0].ToString() | Should -Be 'hello'
            $result[0].IsError | Should -BeFalse
        }

        It 'returns multiple lines' {
            $result = Invoke-NativeApplication { cmd /c "echo line1 & echo line2" }
            $result | Should -HaveCount 2
            $result[0].ToString() | Should -Be 'line1 '
            $result[1].ToString() | Should -Be 'line2'
        }

        It 'does not throw for exit code 0' {
            { Invoke-NativeApplication { cmd /c "exit 0" } } | Should -Not -Throw
        }
    }

    Context 'exit code handling' {
        It 'throws on non-zero exit code by default' {
            { Invoke-NativeApplication { cmd /c "exit 1" } } | Should -Throw '*exit code 1*'
        }

        It 'throws on exit code not in AllowedExitCodes' {
            { Invoke-NativeApplication { cmd /c "exit 2" } -AllowedExitCodes @(0, 1) } | Should -Throw '*exit code 2*'
        }

        It 'does not throw when exit code is in AllowedExitCodes' {
            { Invoke-NativeApplication { cmd /c "exit 3" } -AllowedExitCodes @(0, 3) } | Should -Not -Throw
        }

        It 'does not throw with IgnoreExitCode switch' {
            { Invoke-NativeApplication { cmd /c "exit 42" } -IgnoreExitCode } | Should -Not -Throw
        }
    }

    Context 'STDERR handling' {
        It 'captures STDERR as IsError lines' {
            $result = Invoke-NativeApplication { cmd /c "echo errormsg 1>&2" } -IgnoreExitCode
            $errors = $result | Where-Object { $_.IsError }
            $errors | Should -Not -BeNullOrEmpty
        }

        It 'captures both STDOUT and STDERR' {
            $result = Invoke-NativeApplication { cmd /c "echo stdout & echo stderr 1>&2" } -IgnoreExitCode
            $stdout = $result | Where-Object { -not $_.IsError }
            $stderr = $result | Where-Object { $_.IsError }
            $stdout | Should -Not -BeNullOrEmpty
            $stderr | Should -Not -BeNullOrEmpty
        }
    }

    Context 'ArgumentList splatting' {
        It 'passes arguments via splatting' {
            $params = @{ message = 'splatted' }
            $result = @(Invoke-NativeApplication { param($message) cmd /c echo $message } -ArgumentList $params)
            $result | Should -HaveCount 1
            $result[0].ToString() | Should -Be 'splatted'
        }
    }

    Context 'aliases' {
        It 'exec alias resolves to Invoke-NativeApplication' {
            $alias = Get-Alias exec
            $alias.ReferencedCommand.Name | Should -Be 'Invoke-NativeApplication'
        }

        It 'exec alias works' {
            $result = @(exec { cmd /c echo test })
            $result[0].ToString() | Should -Be 'test'
        }
    }
}

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

    Context 'out parameters' {
        It 'captures STDOUT and STDERR separately' {
            Invoke-NativeApplication { cmd /c "echo out & echo err 1>&2" } -IgnoreExitCode -StdOutVariable 'stdOut' -StdErrVariable 'stdErr' | Out-Null
            @($stdOut) | Should -HaveCount 1
            @($stdErr) | Should -HaveCount 1
            $stdOut[0].ToString() | Should -Be 'out '
            $stdOut[0].IsError | Should -BeFalse
            $stdErr[0].ToString() | Should -Be 'err '
            $stdErr[0].IsError | Should -BeTrue
        }

        It 'captures the interleaved output' {
            $result = @(Invoke-NativeApplication { cmd /c "echo out & echo err 1>&2" } -IgnoreExitCode -OutputVariable 'allOutput')
            @($allOutput) | Should -HaveCount 2
            @($allOutput | ForEach-Object { $_.ToString() }) | Should -Be @($result | ForEach-Object { $_.ToString() })
        }

        It 'captures the exit code' {
            Invoke-NativeApplication { cmd /c "exit 42" } -IgnoreExitCode -ExitCodeVariable 'exitCode' | Out-Null
            $exitCode | Should -Be 42
        }

        It 'captures Success as false for a disallowed exit code' {
            Invoke-NativeApplication { cmd /c "exit 42" } -IgnoreExitCode -SuccessVariable 'success' | Out-Null
            $success | Should -BeFalse
        }

        It 'captures Success as true for an allowed exit code' {
            Invoke-NativeApplication { cmd /c "exit 3" } -AllowedExitCodes @(0, 3) -SuccessVariable 'success' | Out-Null
            $success | Should -BeTrue
        }

        It 'captures timings' {
            Invoke-NativeApplication { cmd /c "echo hello" } -StartTimeVariable 'startTime' -EndTimeVariable 'endTime' -DurationVariable 'duration' | Out-Null
            $startTime | Should -BeOfType [DateTime]
            $endTime | Should -BeOfType [DateTime]
            $duration | Should -BeOfType [TimeSpan]
            $duration.TotalMilliseconds | Should -BeGreaterThan 0
            $endTime | Should -BeGreaterOrEqual $startTime
        }

        It 'captures the command with its arguments' {
            $params = @{ message = 'splatted' }
            Invoke-NativeApplication { param($message) cmd /c echo $message } -ArgumentList $params -CommandVariable 'command' | Out-Null
            $command | Should -BeLike '*cmd /c echo $message*'
            $command | Should -BeLike '*splatted*'
        }

        It 'sets the out variables before throwing on a disallowed exit code' {
            $errorMessage = $null

            try {
                Invoke-NativeApplication { cmd /c "echo out & echo err 1>&2 & exit 7" } -ExitCodeVariable 'exitCode' -StdErrVariable 'stdErr' -SuccessVariable 'success' | Out-Null
            } catch {
                $errorMessage = $_.Exception.Message
            }

            $errorMessage | Should -BeLike '*exit code 7*'
            $exitCode | Should -Be 7
            $success | Should -BeFalse
            @($stdErr) | Should -HaveCount 1
        }

        It 'reports the caller location in the exit code error' {
            { Invoke-NativeApplication { cmd /c "exit 1" } } | Should -Throw ('*failed at *{0}*' -f (Split-Path -Path $PSCommandPath -Leaf))
        }

        It 'tolerates a leading $ in the variable name' {
            Invoke-NativeApplication { cmd /c "exit 5" } -IgnoreExitCode -ExitCodeVariable '$exitCode' | Out-Null
            $exitCode | Should -Be 5
        }

        It 'leaves unrequested variables untouched' {
            $stdErr = 'untouched'
            Invoke-NativeApplication { cmd /c "echo err 1>&2" } -IgnoreExitCode -StdOutVariable 'stdOut' | Out-Null
            $stdErr | Should -Be 'untouched'
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

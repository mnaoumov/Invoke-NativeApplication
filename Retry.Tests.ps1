BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'retries' {
    BeforeEach {
        # Fails with exit code 1 and the given STDERR text until the given attempt.
        $state = @{ Count = 0 }
        $flaky = {
            param($SucceedOn, $ErrText)
            $state.Count++

            if ($state.Count -ge $SucceedOn) {
                cmd /c "echo attempt $($state.Count)"
            } else {
                cmd /c "echo $ErrText 1>&2& exit 1"
            }
        }.GetNewClosure()
    }

    Context 'Invoke-NativeApplication' {
        It 'does not retry by default' {
            { Invoke-NativeApplication $flaky @{ SucceedOn = 2; ErrText = 'ETIMEDOUT' } } | Should -Throw '*exit code 1*'
            $state.Count | Should -Be 1
        }

        It 'retries until an attempt succeeds' {
            $result = @(Invoke-NativeApplication $flaky @{ SucceedOn = 3; ErrText = 'ETIMEDOUT' } -MaxRetries 3 -RetryDelaySeconds 0 -OutputVariable 'output' -ExitCodeVariable 'exitCode' -WarningVariable 'warnings' -WarningAction SilentlyContinue)
            $state.Count | Should -Be 3
            $exitCode | Should -Be 0
            @($output | ForEach-Object { $_.ToString().Trim() }) | Should -Be @('attempt 3')
            @($warnings) | Should -HaveCount 2
            "$($warnings[0])" | Should -BeLike 'Attempt 1 of 4 failed with exit code 1. Retrying in 0 s.'
            # Every attempt's lines are streamed, the failed ones' STDERR included.
            @($result | Where-Object { $_.IsError }) | Should -HaveCount 2
            ($result | Select-Object -Last 1).ToString().Trim() | Should -Be 'attempt 3'
        }

        It 'throws the last failure once the retries run out' {
            { Invoke-NativeApplication $flaky @{ SucceedOn = 10; ErrText = 'ETIMEDOUT' } -MaxRetries 2 -RetryDelaySeconds 0 -WarningAction SilentlyContinue } | Should -Throw '*exit code 1*ETIMEDOUT*'
            $state.Count | Should -Be 3
        }

        It 'retries only failures matching the pattern' {
            { Invoke-NativeApplication $flaky @{ SucceedOn = 2; ErrText = 'fatal' } -MaxRetries 2 -RetryTriggerErrorPattern 'ETIMEDOUT|ECONNRESET' -RetryDelaySeconds 0 } | Should -Throw '*exit code 1*'
            $state.Count | Should -Be 1
        }

        It 'retries a failure whose STDERR matches the pattern' {
            Invoke-NativeApplication $flaky @{ SucceedOn = 2; ErrText = 'npm ERR! ECONNRESET' } -MaxRetries 2 -RetryTriggerErrorPattern 'ETIMEDOUT|ECONNRESET' -RetryDelaySeconds 0 -WarningAction SilentlyContinue | Out-Null
            $state.Count | Should -Be 2
        }

        It 'matches the pattern against every STDERR line, beyond the 10 in the message' {
            $sb = {
                $state.Count++
                if ($state.Count -ge 2) { cmd /c "echo ok" } else { cmd /c "(echo ECONNRESET& for /l %i in (1,1,15) do @echo noise %i) 1>&2& exit 1" }
            }.GetNewClosure()
            Invoke-NativeApplication $sb -MaxRetries 1 -RetryTriggerErrorPattern 'ECONNRESET' -RetryDelaySeconds 0 -WarningAction SilentlyContinue | Out-Null
            $state.Count | Should -Be 2
        }

        It 'retries a disallowed exit code even with IgnoreExitCode, and does not throw' {
            Invoke-NativeApplication $flaky @{ SucceedOn = 10; ErrText = 'x' } -IgnoreExitCode -MaxRetries 2 -RetryDelaySeconds 0 -SuccessVariable 'success' -WarningAction SilentlyContinue | Out-Null
            $state.Count | Should -Be 3
            $success | Should -BeFalse
        }

        It 'honours AllowedExitCodes' {
            Invoke-NativeApplication { $state.Count++; cmd /c "exit 1" }.GetNewClosure() -AllowedExitCodes @(0, 1) -MaxRetries 2 -RetryDelaySeconds 0 | Out-Null
            $state.Count | Should -Be 1
        }

        It 'retries a script block that throws' {
            $sb = { $state.Count++; if ($state.Count -lt 2) { throw 'transient' }; cmd /c echo ok }.GetNewClosure()
            $result = @(Invoke-NativeApplication $sb -MaxRetries 1 -RetryDelaySeconds 0 -WarningAction SilentlyContinue)
            $state.Count | Should -Be 2
            $result[-1].ToString() | Should -Be 'ok'
        }

        It 'keeps the out variables of the last attempt when the last attempt throws' {
            try {
                Invoke-NativeApplication $flaky @{ SucceedOn = 10; ErrText = 'boom' } -MaxRetries 1 -RetryDelaySeconds 0 -StdErrVariable 'err' -WarningAction SilentlyContinue | Out-Null
            } catch {
                $caught = $_
            }
            $caught | Should -Not -BeNullOrEmpty
            @($err) | Should -HaveCount 1
            $err[0].ToString().Trim() | Should -Be 'boom'
        }

        It 'names the caller as the call site' {
            { Invoke-NativeApplication { cmd /c "exit 1" } -MaxRetries 1 -RetryDelaySeconds 0 -WarningAction SilentlyContinue } | Should -Throw '*Retry.Tests.ps1*'
        }

        It 'waits RetryDelaySeconds between attempts' {
            $elapsed = Measure-Command {
                Invoke-NativeApplication $flaky @{ SucceedOn = 2; ErrText = 'x' } -MaxRetries 1 -RetryDelaySeconds 0.5 -WarningAction SilentlyContinue | Out-Null
            }
            $elapsed.TotalMilliseconds | Should -BeGreaterOrEqual 450
        }

        It 'appends the later attempts to the log' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'retry.log'
            Invoke-NativeApplication $flaky @{ SucceedOn = 2; ErrText = 'first' } -MaxRetries 1 -RetryDelaySeconds 0 -LogPath $logPath -WarningAction SilentlyContinue | Out-Null
            $lines = @(Get-Content -LiteralPath $logPath | ForEach-Object { $_.Trim() })
            $lines | Should -Be @('[ERR] first', 'attempt 2')
        }

        It 'rejects an invalid pattern' {
            { Invoke-NativeApplication { cmd /c echo } -MaxRetries 1 -RetryTriggerErrorPattern '(' } | Should -Throw '*Invalid regular expression*'
        }

        It 'rejects a negative MaxRetries' {
            { Invoke-NativeApplication { cmd /c echo } -MaxRetries -1 } | Should -Throw
        }
    }

    Context 'Invoke-NativeApplicationSafe' {
        It 'retries a non-zero exit code and returns the STDOUT of the last attempt' {
            $result = @(Invoke-NativeApplicationSafe $flaky @{ SucceedOn = 2; ErrText = 'x' } -MaxRetries 2 -RetryDelaySeconds 0 -WarningAction SilentlyContinue)
            $state.Count | Should -Be 2
            @($result | ForEach-Object { $_.ToString().Trim() }) | Should -Be @('attempt 2')
        }

        It 'does not throw once the retries run out' {
            { Invoke-NativeApplicationSafe $flaky @{ SucceedOn = 10; ErrText = 'x' } -MaxRetries 1 -RetryDelaySeconds 0 -WarningAction SilentlyContinue } | Should -Not -Throw
            $state.Count | Should -Be 2
        }
    }

    Context 'Elevate' {
        BeforeEach {
            # Runs the elevated half as a plain child process instead of a UAC launch.
            Mock -ModuleName Invoke-NativeApplication -CommandName Test-IsElevated -MockWith { $false }
            Mock -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -MockWith {
                $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentString -WindowStyle Hidden -Wait -PassThru
                return $process.ExitCode
            }
            $counterPath = Join-Path -Path $TestDrive -ChildPath ('count-' + [guid]::NewGuid().ToString('N'))
        }

        It 'runs the attempts in the elevated process, behind one prompt' {
            # Closures do not travel to the elevated process, so a file keeps the count.
            $sb = {
                param($Path)
                $count = 1 + @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue).Count
                Add-Content -LiteralPath $Path -Value 'x'
                if ($count -ge 3) { cmd /c "echo attempt $count" } else { cmd /c "echo ETIMEDOUT 1>&2& exit 1" }
            }
            $result = @(Invoke-NativeApplication $sb @{ Path = $counterPath } -Elevate -MaxRetries 3 -RetryTriggerErrorPattern 'ETIMEDOUT' -RetryDelaySeconds 0 -ExitCodeVariable 'exitCode')
            Should -Invoke -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -Times 1 -Exactly
            @(Get-Content -LiteralPath $counterPath) | Should -HaveCount 3
            $exitCode | Should -Be 0
            # Only the last attempt's lines come back.
            @($result | ForEach-Object { $_.ToString().Trim() }) | Should -Be @('attempt 3')
        }

        It 'throws the last failure once the elevated retries run out' {
            $sb = { param($Path) Add-Content -LiteralPath $Path -Value 'x'; cmd /c "exit 4" }
            { Invoke-NativeApplication $sb @{ Path = $counterPath } -Elevate -MaxRetries 1 -RetryDelaySeconds 0 } | Should -Throw '*exit code 4*'
            Should -Invoke -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -Times 1 -Exactly
            @(Get-Content -LiteralPath $counterPath) | Should -HaveCount 2
        }
    }
}

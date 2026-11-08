BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'execution options' {
    Context 'WorkingDirectory' {
        It 'runs the native application in the given directory' {
            $directory = (Resolve-Path -LiteralPath $TestDrive).ProviderPath
            $result = @(Invoke-NativeApplication { cmd /c cd } -WorkingDirectory $directory)
            $result[0].ToString() | Should -Be $directory
        }

        It 'restores the current location afterwards' {
            $before = (Get-Location).Path
            Invoke-NativeApplication { cmd /c cd } -WorkingDirectory $TestDrive | Out-Null
            (Get-Location).Path | Should -Be $before
        }

        It 'restores the current location when the exit code throws' {
            $before = (Get-Location).Path
            { Invoke-NativeApplication { cmd /c "exit 1" } -WorkingDirectory $TestDrive } | Should -Throw '*exit code 1*'
            (Get-Location).Path | Should -Be $before
        }

        It 'throws for a missing directory' {
            { Invoke-NativeApplication { cmd /c cd } -WorkingDirectory (Join-Path -Path $TestDrive -ChildPath 'missing') } | Should -Throw
        }
    }

    Context 'Environment' {
        BeforeEach {
            [System.Environment]::SetEnvironmentVariable('INA_TEST_SET', 'original')
            [System.Environment]::SetEnvironmentVariable('INA_TEST_NEW', [NullString]::Value)
        }

        AfterEach {
            [System.Environment]::SetEnvironmentVariable('INA_TEST_SET', [NullString]::Value)
            [System.Environment]::SetEnvironmentVariable('INA_TEST_NEW', [NullString]::Value)
        }

        It 'passes the overrides to the native application' {
            $result = @(Invoke-NativeApplication { cmd /c "echo %INA_TEST_SET%-%INA_TEST_NEW%" } -Environment @{ INA_TEST_SET = 'changed'; INA_TEST_NEW = 'added' })
            $result[0].ToString() | Should -Be 'changed-added'
        }

        It 'removes a variable given a $null value' {
            $result = @(Invoke-NativeApplication { cmd /c "if defined INA_TEST_SET (echo defined) else (echo removed)" } -Environment @{ INA_TEST_SET = $null })
            $result[0].ToString() | Should -Be 'removed'
        }

        It 'restores the previous values afterwards' {
            { Invoke-NativeApplication { cmd /c "exit 1" } -Environment @{ INA_TEST_SET = 'changed'; INA_TEST_NEW = 'added' } } | Should -Throw
            $env:INA_TEST_SET | Should -Be 'original'
            Test-Path -Path Env:INA_TEST_NEW | Should -BeFalse
        }
    }

    Context 'LogPath' {
        It 'writes every line, marking STDERR lines' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'run.log'
            Invoke-NativeApplication { cmd /c "echo out& echo err 1>&2" } -IgnoreExitCode -LogPath $logPath | Out-Null
            $lines = @(Get-Content -LiteralPath $logPath)
            $lines | Should -Be @('out', '[ERR] err ')
        }

        It 'overwrites by default and appends with AppendLog' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'append.log'
            Invoke-NativeApplication { cmd /c echo first } -LogPath $logPath | Out-Null
            Invoke-NativeApplication { cmd /c echo second } -LogPath $logPath | Out-Null
            @(Get-Content -LiteralPath $logPath) | Should -Be @('second')

            Invoke-NativeApplication { cmd /c echo third } -LogPath $logPath -AppendLog | Out-Null
            @(Get-Content -LiteralPath $logPath) | Should -Be @('second', 'third')
        }

        It 'logs the STDERR lines Invoke-NativeApplicationSafe filters out' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'safe.log'
            $result = @(Invoke-NativeApplicationSafe { cmd /c "echo out& echo err 1>&2" } -LogPath $logPath)
            $result | Should -HaveCount 1
            @(Get-Content -LiteralPath $logPath) | Should -HaveCount 2
        }
    }

    Context 'Priority' {
        It 'runs the native application at the given priority and restores its own' {
            $hostPath = (Get-Process -Id $PID).Path
            $before = [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass
            $result = @(Invoke-NativeApplication { param($HostPath) & $HostPath -NoProfile -NonInteractive -Command '[System.Diagnostics.Process]::GetCurrentProcess().PriorityClass.ToString()' } -ArgumentList @{ HostPath = $hostPath } -Priority BelowNormal)
            $result[-1].ToString() | Should -Be 'BelowNormal'
            [System.Diagnostics.Process]::GetCurrentProcess().PriorityClass | Should -Be $before
        }

        It 'rejects a priority that a child would not inherit' {
            { Invoke-NativeApplication { cmd /c echo x } -Priority High } | Should -Throw
        }
    }

    Context 'Elevate' {
        BeforeEach {
            # Replace the UAC launch with a plain one, so the whole request/response
            # round trip runs without a prompt.
            Mock -ModuleName Invoke-NativeApplication -CommandName Test-IsElevated -MockWith { $false }
            Mock -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -MockWith {
                $process = Start-Process -FilePath $FilePath -ArgumentList $ArgumentString -Wait -PassThru -NoNewWindow
                $process.ExitCode
            }
        }

        It 'hands back the output lines and the exit code' {
            $result = @(Invoke-NativeApplication { cmd /c "echo out& echo err 1>&2& exit 3" } -Elevate -AllowedExitCodes @(3) -ExitCodeVariable 'exitCode')
            Should -Invoke -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -Times 1 -Exactly
            $result | Should -HaveCount 2
            $result[0] | Should -BeOfType [InvokeNativeApplication.OutputLine]
            $result[0].ToString() | Should -Be 'out'
            $result[0].IsError | Should -BeFalse
            $result[1].ToString() | Should -Be 'err '
            $result[1].IsError | Should -BeTrue
            $exitCode | Should -Be 3
        }

        It 'throws on a disallowed exit code' {
            { Invoke-NativeApplication { cmd /c "exit 5" } -Elevate } | Should -Throw '*exit code 5*'
        }

        It 'passes the arguments, the working directory and the environment' {
            $directory = (Resolve-Path -LiteralPath $TestDrive).ProviderPath
            $result = @(Invoke-NativeApplication { param($Message) cmd /c "echo $Message %INA_TEST_ELEVATED%& cd" } -ArgumentList @{ Message = 'hello' } -Elevate -WorkingDirectory $directory -Environment @{ INA_TEST_ELEVATED = 'set' })
            $result[0].ToString() | Should -Be 'hello set'
            $result[1].ToString() | Should -Be $directory
            Test-Path -Path Env:INA_TEST_ELEVATED | Should -BeFalse
        }

        It 'passes the caller location on when no WorkingDirectory is given' {
            $directory = (Resolve-Path -LiteralPath $TestDrive).ProviderPath
            Push-Location -LiteralPath $directory
            try {
                $result = @(Invoke-NativeApplication { cmd /c cd } -Elevate)
            } finally {
                Pop-Location
            }

            $result[0].ToString() | Should -Be $directory
        }

        It 'reports a script block failure in the elevated process' {
            { Invoke-NativeApplication { throw 'boom' } -Elevate } | Should -Throw '*elevated PowerShell process failed: boom*'
        }

        It 'runs in-process when already elevated' {
            Mock -ModuleName Invoke-NativeApplication -CommandName Test-IsElevated -MockWith { $true }
            $result = @(Invoke-NativeApplication { cmd /c echo inline } -Elevate)
            $result[0].ToString() | Should -Be 'inline'
            Should -Invoke -ModuleName Invoke-NativeApplication -CommandName Start-ElevatedHost -Times 0 -Exactly
        }
    }
}

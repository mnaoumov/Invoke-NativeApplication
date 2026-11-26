BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'Redact' {
    BeforeEach {
        $secret = 's3cr3t-token'
        # Echoes the token to STDOUT and STDERR, then fails.
        $leaky = { param($Token) cmd /c "echo out $Token& echo err $Token 1>&2& exit 1" }
    }

    Context 'Invoke-NativeApplication' {
        It 'passes the value to the native application unchanged' {
            $result = @(Invoke-NativeApplication { param($Token) cmd /c echo $Token } -ArgumentList @{ Token = $secret } -Redact $secret)
            $result[0].ToString() | Should -Be $secret
        }

        It 'keeps a secret passed through ArgumentList out of the thrown message' {
            $message = $null

            try {
                Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret | Out-Null
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -BeLike '*exit code 1*'
            $message | Should -BeLike '*Token=`*`*`**'
            $message | Should -BeLike '*err `*`*`**'
            $message | Should -Not -BeLike "*$secret*"
        }

        It 'keeps the secret out of the captured command' {
            Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret -IgnoreExitCode -CommandVariable 'command' | Out-Null
            $command | Should -BeLike '*Token=`*`*`**'
            $command | Should -Not -BeLike "*$secret*"
        }

        It 'keeps the secret out of the log' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'redact.log'
            Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret -IgnoreExitCode -LogPath $logPath | Out-Null
            $log = Get-Content -LiteralPath $logPath -Raw
            $log | Should -Not -BeLike "*$secret*"
            # STDOUT and STDERR interleave in no fixed order.
            @(Get-Content -LiteralPath $logPath | ForEach-Object { $_.Trim() } | Sort-Object) | Should -Be @('[ERR] err ***', 'out ***')
        }

        It 'keeps the secret out of the verbose message' {
            $verbose = Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret -IgnoreExitCode -Verbose 4>&1 |
                Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }
            "$verbose" | Should -BeLike '*Token=`*`*`**'
            "$verbose" | Should -Not -BeLike "*$secret*"
        }

        It 'keeps the secret out of ErrorMessage' {
            { Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret -ErrorMessage "Token $secret rejected" } |
                Should -Throw 'Token `*`*`* rejected*'
        }

        It 'leaves the returned lines and the line captures as they are' {
            $result = @(Invoke-NativeApplication $leaky -ArgumentList @{ Token = $secret } -Redact $secret -IgnoreExitCode -StdErrVariable 'err')
            @($result | ForEach-Object { $_.ToString().Trim() } | Sort-Object) | Should -Be @("err $secret", "out $secret")
            $err[0].ToString().Trim() | Should -Be "err $secret"
        }

        It 'masks a longer secret whole before a shorter one it contains' {
            Invoke-NativeApplication { param($A) cmd /c echo $A } -ArgumentList @{ A = 'abc-abcdef' } -Redact 'abc', 'abcdef' -CommandVariable 'command' | Out-Null
            $command | Should -BeLike '*A=`*`*`*-`*`*`**'
        }

        It 'ignores empty and null values' {
            Invoke-NativeApplication { cmd /c echo plain } -Redact '', $null -CommandVariable 'command' | Out-Null
            $command | Should -Be 'cmd /c echo plain'
        }

        It 'redacts a secret the script block closes over' {
            $token = $secret
            $sb = { cmd /c "echo $token 1>&2& exit 1" }.GetNewClosure()
            $message = $null

            try {
                Invoke-NativeApplication $sb -Redact $token | Out-Null
            } catch {
                $message = $_.Exception.Message
            }

            $message | Should -BeLike '*STDERR:*`*`*`**'
            $message | Should -Not -BeLike "*$secret*"
        }

        It 'keeps the secret out of the retry warning' {
            $sb = { param($Token) throw "auth failed for $Token" }
            $warnings = $null

            try {
                Invoke-NativeApplication $sb -ArgumentList @{ Token = $secret } -Redact $secret -MaxRetries 1 -RetryDelaySeconds 0 -WarningVariable 'warnings' -WarningAction SilentlyContinue | Out-Null
            } catch {
                $null = $_
            }

            @($warnings) | Should -HaveCount 1
            "$($warnings[0])" | Should -BeLike '*auth failed for `*`*`**'
            "$($warnings[0])" | Should -Not -BeLike "*$secret*"
        }
    }

    Context 'Invoke-NativeApplicationSafe' {
        It 'keeps the secret out of the captured command and the log' {
            $logPath = Join-Path -Path $TestDrive -ChildPath 'safe-redact.log'
            Invoke-NativeApplicationSafe $leaky -ArgumentList @{ Token = $secret } -Redact $secret -LogPath $logPath -CommandVariable 'command' | Out-Null
            $command | Should -Not -BeLike "*$secret*"
            Get-Content -LiteralPath $logPath -Raw | Should -Not -BeLike "*$secret*"
        }
    }
}

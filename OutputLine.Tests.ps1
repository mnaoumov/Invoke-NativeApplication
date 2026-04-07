BeforeAll {
    Import-Module "$PSScriptRoot/Invoke-NativeApplication.psd1" -Force
}

Describe 'InvokeNativeApplication.OutputLine' {
    Context 'Constructor' {
        It 'stores the message and IsError flag' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'hello', $true
            $output.ToString() | Should -Be 'hello'
            $output.IsError | Should -BeTrue
        }

        It 'defaults to empty string when value is null' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList $null, $false
            $output.ToString() | Should -Be ''
            $output.Length | Should -Be 0
        }
    }

    Context 'String behavior' {
        BeforeAll {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'Hello, World!', $false
        }

        It 'returns correct Length' {
            $output.Length | Should -Be 13
        }

        It 'supports indexer' {
            $output[0] | Should -Be 'H'
            $output[7] | Should -Be 'W'
        }

        It 'supports Substring' {
            $output.Substring(7) | Should -Be 'World!'
            $output.Substring(0, 5) | Should -Be 'Hello'
        }

        It 'supports Contains' {
            $output.Contains('World') | Should -BeTrue
            $output.Contains('xyz') | Should -BeFalse
        }

        It 'supports StartsWith' {
            $output.StartsWith('Hello') | Should -BeTrue
            $output.StartsWith('World') | Should -BeFalse
        }

        It 'supports EndsWith' {
            $output.EndsWith('World!') | Should -BeTrue
            $output.EndsWith('Hello') | Should -BeFalse
        }

        It 'supports IndexOf' {
            $output.IndexOf('World') | Should -Be 7
            $output.IndexOf('xyz') | Should -Be -1
            $output.IndexOf([char]'o') | Should -Be 4
        }

        It 'supports LastIndexOf' {
            $output.LastIndexOf('l') | Should -Be 10
            $output.LastIndexOf([char]'l') | Should -Be 10
        }

        It 'supports ToLower and ToUpper' {
            $output.ToLower() | Should -Be 'hello, world!'
            $output.ToUpper() | Should -Be 'HELLO, WORLD!'
        }

        It 'supports ToLowerInvariant and ToUpperInvariant' {
            $output.ToLowerInvariant() | Should -Be 'hello, world!'
            $output.ToUpperInvariant() | Should -Be 'HELLO, WORLD!'
        }

        It 'supports Replace with strings' {
            $output.Replace('World', 'PS') | Should -Be 'Hello, PS!'
        }

        It 'supports Replace with chars' {
            $output.Replace([char]'!', [char]'?') | Should -Be 'Hello, World?'
        }

        It 'supports Split' {
            $parts = $output.Split([char[]]@(','))
            $parts.Count | Should -Be 2
            $parts[0] | Should -Be 'Hello'
        }

        It 'supports Trim, TrimStart, TrimEnd' {
            $padded = New-Object InvokeNativeApplication.OutputLine -ArgumentList '  test  ', $false
            $padded.Trim() | Should -Be 'test'
            $padded.TrimStart() | Should -Be 'test  '
            $padded.TrimEnd() | Should -Be '  test'
        }

        It 'supports PadLeft and PadRight' {
            $short = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'hi', $false
            $short.PadLeft(5) | Should -Be '   hi'
            $short.PadRight(5) | Should -Be 'hi   '
            $short.PadLeft(5, [char]'*') | Should -Be '***hi'
        }

        It 'supports Insert' {
            $output.Insert(5, '!!') | Should -Be 'Hello!!, World!'
        }

        It 'supports Remove' {
            $output.Remove(5) | Should -Be 'Hello'
            $output.Remove(5, 2) | Should -Be 'HelloWorld!'
        }

        It 'supports ToCharArray' {
            $chars = $output.ToCharArray()
            $chars.Length | Should -Be 13
            $chars[0] | Should -Be 'H'
        }

        It 'supports IndexOfAny' {
            $output.IndexOfAny([char[]]@('W', 'x')) | Should -Be 7
        }

        It 'supports LastIndexOfAny' {
            $output.LastIndexOfAny([char[]]@('l', 'o')) | Should -Be 10
        }
    }

    Context 'ToString and string conversion' {
        It 'ToString returns the inner value' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $output.ToString() | Should -Be 'test'
        }

        It 'implicit conversion to string works' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            [string]$s = $output
            $s | Should -Be 'test'
            $s | Should -BeOfType [string]
        }

        It 'string interpolation works' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'world', $false
            "hello $output" | Should -Be 'hello world'
        }
    }

    Context 'Equality and comparison' {
        It 'Equals returns true for same string value' {
            $a = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $b = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $true
            $a.Equals($b) | Should -BeTrue
        }

        It 'Equals returns true for matching string' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $output.Equals('test') | Should -BeTrue
            $output.Equals('other') | Should -BeFalse
        }

        It 'Equals with StringComparison works' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'TEST', $false
            $output.Equals('test', [StringComparison]::OrdinalIgnoreCase) | Should -BeTrue
            $output.Equals('test', [StringComparison]::Ordinal) | Should -BeFalse
        }

        It 'GetHashCode matches string hash code' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $output.GetHashCode() | Should -Be 'test'.GetHashCode()
        }

        It 'CompareTo string works' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'beta', $false
            $output.CompareTo('alpha') | Should -BeGreaterThan 0
            $output.CompareTo('beta') | Should -Be 0
            $output.CompareTo('gamma') | Should -BeLessThan 0
        }

        It 'CompareTo InvokeNativeApplication.OutputLine works' {
            $a = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'alpha', $false
            $b = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'beta', $false
            $a.CompareTo($b) | Should -BeLessThan 0
        }
    }

    Context 'IsError property' {
        It 'IsError is true for error output' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'error msg', $true
            $output.IsError | Should -BeTrue
        }

        It 'IsError is false for normal output' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'normal', $false
            $output.IsError | Should -BeFalse
        }
    }

    Context 'Clone' {
        It 'returns a clone of the inner string' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $clone = $output.Clone()
            $clone | Should -Be 'test'
        }
    }

    Context 'Normalize' {
        It 'returns normalized string' {
            $output = New-Object InvokeNativeApplication.OutputLine -ArgumentList 'test', $false
            $output.IsNormalized() | Should -BeTrue
            $normalized = $output.Normalize()
            $normalized | Should -Be 'test'
        }
    }
}

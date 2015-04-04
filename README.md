# Invoke-NativeApplication
A set of helper functions to invoke native applications in PowerShell with proper error messages and exit codes handlers

Invocation of native applications in PowerShell seems to easy but actually it is not.

For more explanation see https://mnaoumov.wordpress.com/2015/01/11/execution-of-external-commands-in-powershell-done-right/ and https://mnaoumov.wordpress.com/2015/03/31/execution-of-external-commands-native-applications-in-powershell-done-right-part-2/


After you import the *exec.ps1* you can safely use

    exec { .\some-application-that-writes-to-the-STDERR-at-returns-some-exit-code.exe }
    safeexec { .\some-application-that-writes-to-the-STDERR-at-returns-some-exit-code.exe }
    
and those functions will capture STDERR stream properly and check exit code after your application has exited.

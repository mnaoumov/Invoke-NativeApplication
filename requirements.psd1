@{
    # Without CurrentUser, PSDepend installs into $env:ProgramFiles and fails without admin rights.
    PSDependOptions = @{
        Parameters = @{
            Scope = 'CurrentUser'
        }
    }

    Pester          = '5.7.1'
}

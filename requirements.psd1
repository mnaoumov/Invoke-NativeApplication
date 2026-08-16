@{
    # PSDepend uses Target as the scope proxy for PSGalleryModule; it is not a passthrough
    # Parameter. Without CurrentUser it defaults to AllUsers and fails without admin rights.
    PSDependOptions = @{
        Target = 'CurrentUser'
    }

    Pester          = '5.7.1'
}

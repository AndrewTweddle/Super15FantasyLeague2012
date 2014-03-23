function Select-Properties
{
    param (
        [object[]] $property
    )
    begin
    {
        [object[]] $propertyMappings = $property | % {
            if ($_ -is [hashTable] -and $_.D)
            {
                $propertyName = $_.N
                $dataType = $_.D
                # $code = "Get-EventLog -LogName $name -Newest 5 -EntryType Error "
                $code = "[$($_.D)]::Parse(`$_.$propertyName)"
                $e = $executioncontext.InvokeCommand.NewScriptBlock($code)
                @{name=$propertyName; expression=$e}
            }
            else
            {
                $_
            }
        }
    }
    process
    {
        $_ | select-object $propertyMappings
    }
}
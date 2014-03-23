function Select-Properties
{
    param (
        [hashTable] $propertyTypeMappings
    )
    process
    {
        $record = $_
        $newObject = new-object PSObject
        $propertyTypeMappings.Get_Keys() | % {
            $propertyName = $_
            $propertyType = $propertyTypeMappings[$_]
            $propertyValue = $record.$propertyName
            switch ($propertyType)
            {
                'int'    { $propertyValue = [int]::Parse( $propertyValue ) }
                'double' { $propertyValue = [double]::Parse( $propertyValue ) }
                'bool'   { $propertyValue = [bool]::Parse( $propertyValue ) }
                'DateTime' { $propertyValue = [DateTime]::Parse( $propertyValue ) }
            }
            $newObject | Add-Member NoteProperty $propertyName $propertyValue
        }
        $newObject
    }
}
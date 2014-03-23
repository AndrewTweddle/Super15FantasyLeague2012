param (
    [string] $2011FolderPath = 'flarchive:\2011\PlayerStats2011',
    [string] $2012FolderPath = 'fl:\PrevSeasonAnalysis\PlayerStats\DownloadedPlayerStats'
)

$fileNames = Get-ChildItem $2011FolderPath -filter *.csv | % { $_.Name } | sort-object
# join-string $fileNames -separator ',' | out-clipboard

$csvFiles = $fileNames | ? { $_ -match 'PlayerStatsRound_(?<year>\d{4})_(?<month>\d{2})_(?<day>\d{2})\.csv' } | 
    select-object @{n='FileName';e={$matches[0] }},@{n='Year';e={$matches.year}},@{n='Month';e={$matches.Month}},@{n='Day';e={$matches.Day}}

$round0File = new-object PSObject
$round0File | add-member -MemberType NoteProperty -Name FileName -value 'PlayerStatsRound0.csv'
$round0File | add-member -MemberType NoteProperty -Name Year -value 2011
$round0File | add-member -MemberType NoteProperty -Name Month -value 2
$round0File | add-member -MemberType NoteProperty -Name Day -value 8

$csvFiles += $round0File
$csvFiles = $csvFiles | select-object FileName,Year,Month,Day,@{n='Date';e={new-object datetime -argumentList $_.Year,$_.Month,$_.Day}} | sort-object Date
# $csvFiles

$friday = [datetime]::Parse('2011-02-18')
$fridays = 0..21 | % { $friday.AddDays( 7 * $_ ) }
# $fridays

$round = 0
$csvFilesByRound =`
    $fridays | % { 
        $friday = $_
        $csvFiles | ? { $_.Date -lt $friday } | sort-object Date -descending | select-object -first 1 | `
            select-object `
                @{n='SourcePath';e={"$2011FolderPath\$($_.FileName)"}}, `
                @{n='DestPath';e={"$2012FolderPath\PlayerStats_Round$($Round)_$($_.Date.ToString('yyyy_MM_dd')).csv"}}
        $round++
    }

$csvFilesByRound | % { Copy-Item -path $_.SourcePath -destination $_.DestPath -force }

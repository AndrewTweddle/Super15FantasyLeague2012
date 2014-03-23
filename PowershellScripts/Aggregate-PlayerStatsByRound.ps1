param (
    [string] $playerStatsFolderPath = 'fl:\PrevSeasonAnalysis\PlayerStats',
    [string] $aggregateFilePath = 'fl:\PrevSeasonAnalysis\PlayerStats\AllPlayerStats.csv'
)

$playerFiles = Get-ChildItem "$playerStatsFolderPath\ByPlayer"
$aggregateStats = $playerFiles | % {
    $playerFileName = $_.FullName
    $playerStats = import-csv $playerFileName
    $playerStats
}

$aggregateStats | export-csv $aggregateFilePath -noTypeInformation

$aggregateStats | group-object RoundsCompleted | % {
    $grouping = $_
    $round = $grouping.Name
    $exportFileName = "$playerStatsFolderPath\ByRound\Round_$($round).csv"
    $grouping.Group | export-csv $exportFileName -noTypeInformation
}

param 
(
    [string] $importFile = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2011.RoundRobinOnly.csv',
    [string] $teamsFile = 'fl:\MasterData\Global\Teams.csv'
)

$teams = import-csv $teamsFile
$results = import-csv $importFile

# Export scores as home team:
$groupings = $results | group-object HomeTeam

$groupings | % {
    $grouping = $_
    $teamName = $grouping.Name
    $teamCode = ($teams | ? { $_.TeamName -eq $teamName }).TeamCode
    $outputFileName = "fl:\PrevSeasonAnalysis\MatchResults\2011\ResultsByTeam\$($teamCode)_HomeResults.RoundRobinOnly.csv"
    $grouping.Group | select-object DatePlayed,`
        @{ n='TeamName';e={$teamName}}, `
        @{ n='Opponents';e={$_.AwayTeam}}, `
        @{ n='PointsScored'; e={$_.HomeScore}}, `
        @{ n='PointsConceded'; e={$_.AwayScore}} `
        | export-csv $outputFileName -noTypeInformation
}


# Export scores as away team:
$groupings = $results | group-object AwayTeam

$groupings | % {
    $grouping = $_
    $teamName = $grouping.Name
    $teamCode = ($teams | ? { $_.TeamName -eq $teamName }).TeamCode
    $outputFileName = "fl:\PrevSeasonAnalysis\MatchResults\2011\ResultsByTeam\$($teamCode)_AwayResults.RoundRobinOnly.csv"
    $grouping.Group | select-object DatePlayed, `
        @{ n='TeamName';e={$teamName}}, `
        @{ n='Opponents';e={$_.HomeTeam}}, `
        @{ n='PointsScored'; e={$_.AwayScore}}, `
        @{ n='PointsConceded'; e={$_.HomeScore}} `
        | export-csv $outputFileName -noTypeInformation
}

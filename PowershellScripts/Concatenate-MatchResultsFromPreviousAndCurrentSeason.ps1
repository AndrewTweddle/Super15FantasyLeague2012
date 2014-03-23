param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

# Input file paths:
[string] $prevSeasonResultsFilePath = "FL:\PrevSeasonAnalysis\MatchResults\$($season-1)\AllResultsByTeamAndRound.csv"
if ($upcomingRound -gt 1)
{
    [string] $seasonToDateResultsFilePath = "FL:\DataByRound\Round$($upcomingRound-1)\TeamResults\SeasonToDateMatchResultsWithComponentsOfScore.csv"
    [string] $prevRoundConcatenatedResultsFilePath = "FL:\DataByRound\Round$($upcomingRound - 1)\Inputs\AllMatchResultsToDate.csv"
}

# Output file paths:
[string] $concatenatedResultsFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\AllMatchResultsToDate.csv"


# Load input data:
if ($upcomingRound -gt 19)  # Note: Upcoming round 19 can still use the stats to the end of round 18.
{
    # For play-off rounds, use the match results from the last round robin round:
    copy-item -path $prevRoundConcatenatedResultsFilePath -destination $concatenatedResultsFilePath
}
else
{
    $prevSeasonResults = import-csv $prevSeasonResultsFilePath
    $prevSeasonResultsWithSeason = $prevSeasonResults | Add-Member NoteProperty 'Season' $($season - 1) -passThru
    $concatenatedResults = $prevSeasonResultsWithSeason

    if ($upcomingRound -gt 1)
    {
        $seasonToDateResults = import-csv $seasonToDateResultsFilePath
        $concatenatedResults = $concatenatedResults + $seasonToDateResults
    }

    $concatenatedResults | export-csv $concatenatedResultsFilePath -noTypeInformation
}
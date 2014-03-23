param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

# Input file paths:
[string] $prevSeasonPlayerStatsFilePath = "FL:\PrevSeasonAnalysis\PlayerStats\AllPlayerStats.csv"
if ($upcomingRound -gt 1)
{
    [string] $seasonToDatePlayerStatsFilePath = "FL:\DataByRound\Round$($upcomingRound - 1)\PlayerStats\PlayerStatsToDate.csv"
    [string] $prevRoundConcatenatedPlayerStatsFilePath = "FL:\DataByRound\Round$($upcomingRound - 1)\Inputs\AllPlayerStatsToDate.csv"
}

# Output file paths:
[string] $concatenatedPlayerStatsFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\AllPlayerStatsToDate.csv"


# Load input data:
if ($upcomingRound -gt 19)  # Note: Upcoming round 19 can still use the stats to the end of round 18.
{
    # For play-off rounds, use the stats from the last round robin round:
    copy-item -path $prevRoundConcatenatedPlayerStatsFilePath -destination $concatenatedPlayerStatsFilePath
}
else
{
    # Round robin round:
    $prevSeasonPlayerStats = import-csv $prevSeasonPlayerStatsFilePath | ? {
        # Only include round robin rounds in stats:
        $round = [int]::Parse( $_.RoundsCompleted )
        ($round -gt 0) -and ($round -le 18)
    }

    $prevSeasonPlayerStatsWithSeason = $prevSeasonPlayerStats | Add-Member NoteProperty 'Season' $($season - 1) -passThru
    $concatenatedPlayerStats = $prevSeasonPlayerStatsWithSeason

    if ($upcomingRound -gt 1)
    {
        $seasonToDatePlayerStats = import-csv $seasonToDatePlayerStatsFilePath
        $concatenatedPlayerStats = $concatenatedPlayerStats + $seasonToDatePlayerStats
    }

    $concatenatedPlayerStats `
        | select-object `
            "Season","RoundsCompleted","IsInCompetition","FullName","FirstName","Surname","Position","Team","Price", `
            "PointsAsNonKicker","KickingPoints","PointsAsKicker","FullAppearance","PartAppearance", `
            "Tries","Assists","Conversions","Penalties","DropGoals","HomeWin","HomeDraw","AwayWin","AwayDraw","YellowCard","RedCard", `
            "PriceChange","TotalPointsAsNonKicker","TotalKickingPoints","TotalPoints","FullAppearances","PartAppearances", `
            "TotalTries","TotalAssists","TotalConversions","TotalPenalties","TotalDropGoals", `
            "HomeWins","HomeDraws","AwayWins","AwayDraws","YellowCards","RedCards" `
        | export-csv $concatenatedPlayerStatsFilePath -noTypeInformation
}

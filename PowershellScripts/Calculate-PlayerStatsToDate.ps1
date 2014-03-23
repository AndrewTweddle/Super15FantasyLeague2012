param (
    [int] $season = $( read-host 'Season' ),
    [int] $round = $( read-host 'Round completed' )
)

# Output files:
[string] $playerStatsToDateFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayerStatsToDate.csv"

# Concatenate all rounds' player stats to give player stats for upcoming round:
$playerStatsToDate = @( 
    1..$round | % {
        $round = $_
        [string] $playerStatsForRoundFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayerStatsForRound.csv"
        $playerStatsForRound = import-csv $playerStatsForRoundFilePath
        $playerStatsForRound
    }
)
$playerStatsToDate | export-csv $playerStatsToDateFilePath -noTypeInformation

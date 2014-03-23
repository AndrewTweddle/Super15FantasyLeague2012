param (
    [int] $round = 0,
    [int] $season = 2012
)

$positions = Import-Csv "fl:\MasterData\global\Positions.csv"

# Create a lookup (dictionary) of players who played Super 15 the previous year.
# This is to set the Rookie field (Y='Rookie', N='Not a rookie', 'X' = 'Unknown').
# Note that a rookie is only with respect to the current season, not the player's entire career.
# He might be quite experienced in other competitions, or returning to Super 15 after a gap.
# But he is still considered a rookie with respect to the current season.
$prevSeasonPlayerLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $($season - 1)
[bool] $prevSeasonPlayersFound = $prevSeasonPlayerLookup -ne $null

# Load player stats:
$downloadedPlayerStats = import-csv "fl:\DataByRound\Round$round\PlayerStats\DownloadedPlayerStatsAfterRound.csv"

$playerRecords = $downloadedPlayerStats | % {
    $playerStats = $_
    $playerName = $playerStats.FullName
    $positionCode = $playerStats.Position
    $positionType = ($positions | ? {$_.PositionCode -eq $positionCode}).PositionType
    $teamCode = $playerStats.Team
    $rookie = $( 
        if ($prevSeasonPlayersFound)
        {
            if ($prevSeasonPlayerLookup.$playerName)
            {
                'N'
            }
            else
            {
                'Y'
            }
        } 
        else 
        {
            'X'
        }
    )
    $playerData = new-object PSObject
    $playerData | add-member NoteProperty 'PlayerName' $playerName
    $playerData | add-member NoteProperty 'TeamCode' $teamCode
    $playerData | add-member NoteProperty 'PositionCode' $positionCode
    $playerData | add-member NoteProperty 'PositionType' $positionType
    $playerData | add-member NoteProperty 'Rookie' $rookie
    $playerData
}

$playerRecords | sort-object PlayerName | export-csv "fl:\MasterData\$season\Players\Players.csv" -noTypeInformation

$playerRecords | group-object TeamCode | % {
    $grouping = $_
    $teamCode = $grouping.Name
    $exportFileName = "fl:\MasterData\$season\Players\$($teamCode)_Players.csv"
    $grouping.Group | export-csv $exportFileName -noTypeInformation
    $subGroupings = $grouping.Group | group-object PositionType
    $subGroupings | % {
        $subGrouping = $_
        $positionType = $subGrouping.Name
        $exportFileName = "fl:\MasterData\$season\Players\$($teamCode)_$($positionType)_Players.csv"
        $subGrouping.Group | export-csv $exportFileName -noTypeInformation
    }
}

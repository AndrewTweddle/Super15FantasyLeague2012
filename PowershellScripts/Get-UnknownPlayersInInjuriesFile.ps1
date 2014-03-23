param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

$playersLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $season

# Load injured players:
[string] $injuriesFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\Injuries.csv"
$injuries = import-csv $injuriesFilePath
$injuredPlayers = $injuries | group-object PlayerName | % { $_.Name }

# See which players can't be found in the players for the season:
$unknownPlayers = @( $injuredPlayers | ? { $playersLookup.$_ -eq $null } )

# Display unknown players:
if ($unknownPlayers)
{
    Write-Host 'The following players are in the injuries file but not in the list of players for the season:' -foregroundColor Green
    $unknownPlayers | % {
        Write-Host "    $_" -foregroundColor Yellow
    }
}
else
{
    Write-Host 'No unknown players in injuries file' -foregroundColor Green
}
Write-Host

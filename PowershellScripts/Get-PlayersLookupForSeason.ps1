# Returns a hash code of Super 15 players in a particular season
param (
    [int] $season = $( throw 'Please provide the season' )
)

$playersFilePath = "fl:\MasterData\$season\Players\Players.csv"

if (-not (test-path $playersFilePath))
{
    [hashtable] $null
}
else
{
    $players = import-csv $playersFilePath
    $playerGroupings = $players | Group-Object PlayerName
    $playerLookup = @{}
    $playerGroupings | % {
        $grouping = $_
        $playerLookup[$grouping.Name] = $grouping.Group[0]
    }

    $playerLookup
}

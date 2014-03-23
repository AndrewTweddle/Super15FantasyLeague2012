param (
    [int] $season = 2012,
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

[int] $prevRound = $upcomingRound - 1

[string] $downloadedStatsFilePath = "FL:\DataByRound\Round$prevRound\PlayerStats\DownloadedPlayerStatsAfterRound.csv"
[string] $playerPricesFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\PlayerPrices.csv"

# Get lookup data for generating extra fields:
$positions = import-csv "FL:\MasterData\Global\Positions.csv"
$playersLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $season

# Extract player data and prices from downloaded stats:
Write-Host "Extracting players and prices from downloaded stats..." -foregroundColor Cyan

$downloadedStats = import-csv $downloadedStatsFilePath
$playerPrices = $downloadedStats `
    | select-object `
        @{ n='PlayerName'; e={ $_.FullName }}, `
        @{ n='TeamCode'; e={ $_.Team }}, `
        @{ n='PositionCode'; e={ $_.Position }}, `
        @{ n='PositionType'
           e={
                $positionCode = $_.Position;
                $position = $positions | ? { $_.PositionCode -eq $positionCode }
                if ($position) { $position.PositionType }
           }
        }, `
        @{ n='Price'
           e={ 
                [double]::Parse( $_.Price ) 
           }
         }, `
        @{ n='Rookie'
           e={ 
                $player = $playersLookup[$_.FullName]
                if ($player) {$player.Rookie} else { 'Y' } 
           }
        }, `
        @{ n='NotInPlayersForSeason'
           e={
                $player = $playersLookup[$_.FullName]
                $player -eq $null
           }
        } `
    | sort-object PlayerName

# Write to output file:
$playerPrices | select-object PlayerName,TeamCode,PositionCode,PositionType,Price,Rookie | export-csv $playerPricesFilePath -noTypeInformation

# Warn if any new players were found that are not in the list of players for the season:
Write-Host "Looking for any new players which are not in the season players list..." -foregroundColor Cyan

[bool] $newPlayersFound = $false
    
$playerPrices | ? { $_.NotInPlayersForSeason } | % { 
    $playerName = $_.PlayerName
    if (-not $newPlayersFound)
    {
        $newPlayersFound = $true
        Write-Host
        Write-Host "New players were found in downloaded stats. Please update Players.csv in the master data folder!" -foregroundColor Red
        Write-Host
    }
    Write-Host "    $playerName" -foregroundColor Yellow
}
if ($newPlayersFound)
{
    Write-Host
}

# Check if any players have been removed from the list of players in the season players folder:
Write-Host "Looking for any players which are in the season players list, but not in the current player list..." -foregroundColor Cyan

$players = import-csv "FL:\MasterData\$season\Players\Players.csv"
$players | % { 
    $p = $_.PlayerName
    $pp = ( $playerPrices | ? { $_.PlayerName -eq $p })
    if (-not $pp)
    { 
        Write-Host "    $p not found" -foregroundColor Cyan
    }
}

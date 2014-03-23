param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [switch] $teamSheetsAfterCutoff = $false
)

$playersLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $season
$teams = import-csv FL:\MasterData\Global\Teams.csv

# File and folder paths:
if ($teamSheetsAfterCutoff)
{
    [string] $teamsheetsFolderPath = "FL:\DataByRound\Round$upcomingRound\TeamSheets\TeamsheetsAfterCutoff"
}
else
{
    [string] $teamsheetsFolderPath = "FL:\DataByRound\Round$upcomingRound\TeamSheets"
}
$allPlayersNotInTeamSheetsFilePath = "$teamsheetsFolderPath\AllPlayersNotInTeamSheets.csv"

$allPlayersNotInTeamSheets = @(
    foreach ($team in $teams)
    {
        $teamCode = $team.TeamCode
        
        Write-Host '--------------------------------------------------------' -foregroundColor Green
        Write-Host "Reconciling teamsheets for $($team.TeamName) [$teamCode]" -foregroundColor Green
        
        $teamSheetFileName = "$teamsheetsFolderPath\$($teamCode)_TeamSheet.csv"
        if (-not (test-path $teamSheetFileName))
        {
            Write-Host "    No team sheet found for team $teamCode" -foregroundColor Yellow
        }
        else
        {
            $teamSheetRecords = import-csv $teamSheetFileName
            $tsPlayers = $teamSheetRecords | % { $_.PlayerName } | sort-object
            
            $allTeamPlayersFilePath = "FL:\MasterData\$season\Players\$($teamCode)_Players.csv" 
            $allTeamPlayers = import-csv $allTeamPlayersFilePath
            $allPlayers = $allTeamPlayers | % { $_.PlayerName } | sort-object
            $comparison = Compare-Object $tsPlayers $allPlayers
            
            # Determine players who are not in the teamsheets. These are possible injuries:
            $playersNotInTeamSheet = @( $comparison | ? { $_.SideIndicator -eq '=>' } | % { $_.InputObject } )
            if ($playersNotInTeamSheet)
            {
                Write-Host '    Players not in team sheet:' -foregroundColor Cyan
                $playersNotInTeamSheet | % {
                    Write-Host "        $_" -foregroundColor Yellow
                }
                Write-Host
                
                # Return these players:
                $playersNotInTeamSheet
            }
            
            # Determine players who are in teamsheets, but not in the main list of players. 
            # These are possible typos:
            $unmatchedNamesInTeamsheet = @( $comparison | ? { $_.SideIndicator -eq '<=' } | % { $_.InputObject } )
            if ($unmatchedNamesInTeamsheet)
            {
                Write-Host '    Players in teamsheet which are missing from players list (possible typo):' -foregroundColor Magenta
                $unmatchedNamesInTeamsheet | % {
                    Write-Host "        $_" -foregroundColor Red
                }
                Write-Host
            }
        }
        Write-Host
    }
)

$allPlayersNotInTeamSheets | export-csv $allPlayersNotInTeamSheetsFilePath -noTypeInformation

param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

$playersLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $season
$teams = import-csv FL:\MasterData\Global\Teams.csv

# File and folder paths:
$teamsheetsFolderPath = "FL:\DataByRound\Round$upcomingRound\TeamSheets"
$injuriesFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\Injuries.csv"

$probabilitiesOfPlayingFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\ProbabilitiesOfPlaying.csv"

# Use injuries file as default probabilities. Add or update it as necessary:
$probabilitiesOfPlaying = import-csv $injuriesFilePath | `
    select-object `
        Season, `
        @{ 
            n='Round'
            e={ [int]::Parse( $_.Round) }
        }, `
        TeamCode,PlayerName, `
        @{ 
            n='ProbabilityOfPlaying'
            e={ [double]::Parse( $_.ProbabilityOfPlaying )}
        }, `
        Reason,Notes

$teamSheetProbabilities = @(
    foreach ($team in $teams)
    {
        $teamCode = $team.TeamCode
        
        Write-Host '--------------------------------------------------------' -foregroundColor Green
        Write-Host "Applying probabilities from teamsheets for $($team.TeamName) [$teamCode]" -foregroundColor Green
        
        $teamSheetFileName = "$teamsheetsFolderPath\$($teamCode)_TeamSheet.csv"
        if (-not (test-path $teamSheetFileName))
        {
            Write-Host "    No team sheet found for team $teamCode" -foregroundColor Red
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
                $playersNotInTeamSheet | % {
                    Write-Host "    Setting probability to zero for player $_ (not in teamsheet)"
                    new-object PSObject -property @{
                        Season = $season
                        Round = $upcomingRound
                        TeamCode = $teamCode
                        PlayerName = $_
                        ProbabilityOfPlaying = [double] 0.0
                        Reason = 'Not in teamsheet'
                        Notes = ''
                    }
                }
            }
            
            # For each player in the teamsheet, set their probability:
            $teamSheetRecords | % {
                $record = $_
                $playerName = $record.PlayerName
                $roleCode = $record.RoleCode
                $probabilityOfPlaying = [double]::Parse($record.ProbabilityOfPlaying)
                
                # Players on the bench might not get to play. 
                # So set their probability of playing to 90% if it is over 90%:
                if ($roleCode -eq 'S')
                {
                    if ($probabilityOfPlaying -ge 0.9)
                    {
                        $probabilityOfPlaying = 0.9
                    }
                    $reason = 'Found in teamsheet (on bench)'
                }
                else
                {
                    $reason = 'Found in teamsheet (starting)'
                }
                
                new-object PSObject -property @{
                    Season = $season
                    Round = $upcomingRound
                    TeamCode = $teamCode
                    PlayerName = $playerName
                    ProbabilityOfPlaying = $probabilityOfPlaying
                    Reason = $reason
                    Notes = ''
                }
            }
        }
        Write-Host
    }
) | select-object Season,Round,TeamCode,PlayerName,ProbabilityOfPlaying,Reason,Notes  # Just to reorder the fields correctly

# Generate combined probabilities to add:
Write-Host 'Determining which team sheet probability records to add and which to update...' -foregroundColor Green

$probabilitiesToAdd = @( 
    foreach ($prob in $teamSheetProbabilities) {
        $playerName = $prob.PlayerName
        $existingProb = $probabilitiesOfPlaying | ? { ($_.Round -eq $upcomingRound) -and ($_.PlayerName -eq $playerName) }
        if ($existingProb)
        {
            try
            {
                # Update the existing probability:
                $existingProb.ProbabilityOfPlaying = $prob.ProbabilityOfPlaying
                $existingProb.Reason = $prob.Reason
                $existingProb.Notes = 'Injury probability overridden by team sheet probability'
            }
            catch
            {
                Write-Host "Error while setting existing probability on player $playerName" -foregroundColor Red
                
                Write-Host 'Existing probability record:'
                $existingProb | out-host
                Write-Host
                Write-Host 'Teamsheet prob record:'
                $prob | out-host
                Write-Host
            }
        }
        else
        {
            # Add to a list of probabilities to append to the injury probabilities:
            $prob
        }
    }
)

# Merging new probability records with existing (from injuries file):
if ($probabilitiesToAdd)
{
    $probabilitiesOfPlaying = $probabilitiesOfPlaying + @( $probabilitiesToAdd )
}

$probabilitiesOfPlaying = $probabilitiesOfPlaying | sort-object Season,TeamCode,PlayerName,Round

# Save to the ProbabilitiesOfPlaying.csv file:
$probabilitiesOfPlaying | export-csv $probabilitiesOfPlayingFilePath -noTypeInformation

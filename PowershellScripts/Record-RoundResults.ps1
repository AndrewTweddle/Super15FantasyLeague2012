param (
    [int] $season = $( read-host 'Season' ),
    [int] $round = $( read-host 'Round completed' )
)

Invoke-PromptingAction 'Record results of completed round' {
    # Get the path to the round folder:
    [string] $roundFolder = "FL:\DataByRound\Round$round"
    if (-not (test-path $roundFolder))
    {
        [System.IO.Directory]::CreateDirectory( $roundFolder )
    }
    $roundFolder = convert-path $roundFolder
    Write-Host "Save round results in sub-folders of $roundFolder ..." -foregroundColor Green
    
    # Create sub-folders:
    Invoke-PromptingAction 'Generate folder structure for round' -action {
        $subFoldersToCreate = @(
            'TeamResults'
            'PlayerStats'
            'FantasyTeamResults'
        )
        
        foreach( $subFolder in $subFoldersToCreate )
        {
            $folder = join-path $roundFolder $subFolder
            
            if (-not (test-path $folder))
            {
                [System.IO.Directory]::CreateDirectory( $folder ) | out-null
                Write-Host "Directory created: $folder" -foregroundColor Green
            }
        }
    }
    
    # Reminder to create ChosenTeam folder:
    Invoke-PromptingAction 'Populate ChosenTeam folder with selected optimization model (if not already done)' -manual
    
    # Modify SelectedTeam to reflect substitutions:
    Invoke-PromptingAction 'Modify TeamSelection.csv with the effect of any substitutions' {
        Invoke-PromptingAction 'Backup TeamSelection.csv to OriginalTeamSelection.csv' -manual
        Invoke-PromptingAction 'Edit TeamSelection.csv to change RoleCodes from P to S and vice versa' -manual
        Invoke-PromptingAction 'Recalculate estimates based on the change in roles' {
            . FL:\PowershellScripts\Calculate-EstimatesForAdjustedTeamSelection.ps1 $round
        }
    }
    
    # Get player stats from UDT web site:
    Invoke-PromptingAction 'Get player stats from udt web site' {
        Invoke-PromptingAction 'Download json file of player stats from Fantasy League web site to PlayerStats folder' -manual
        
        $jsonFileName = read-host "Please provide the name of the json file to import (with the extension, but not the path)"
        
        $playerStats = & FL:\PowershellScripts\Get-PlayerStatsFromJsonFile.ps1 "FL:\DataByRound\Round$round\PlayerStats\$jsonFileName"
        $playerStats | export-csv "$roundFolder\PlayerStats\DownloadedPlayerStatsAfterRound.csv" -noTypeInformation
    }
    
    Invoke-PromptingAction 'Update player stats' {
        # Update list of players for the season:
        FL:\PowershellScripts\Generate-PlayersForSeasonFromDownloadedPlayerStats.ps1 `
            -season $season -round $round
        
        Invoke-PromptingAction 'Calculate player stats for round' {
            . FL:\PowershellScripts\Calculate-PlayerStatsForRound.ps1 `
                -season $season -round $round
        }
        
        Invoke-PromptingAction 'Calculate player stats to date' {
            FL:\PowershellScripts\Calculate-PlayerStatsToDate.ps1 `
                -season $season -round $round
        }
    }
    
    # Calculate variances:
    Invoke-PromptingAction 'Calculate variances for selected team' {
        . FL:\PowershellScripts\Calculate-TeamSelectionVariances.ps1 `
            -season $season -round $round
    }
    
    Invoke-PromptingAction 'Create and edit FantasyTeamResults\PlayerVariancesForRounds.xlsx' {
        $destExcelFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\PlayerVariancesForRound.xlsx"
        
        # Copy Excel file from previous round:
        if ($round -gt 1 -and -not (test-path $destExcelFilePath))
        {
            $sourceExcelFilePath = "FL:\DataByRound\Round$($round-1)\FantasyTeamResults\PlayerVariancesForRound.xlsx"
            Invoke-PromptingAction 'Copy Excel file from previous round' {
                copy-item $sourceExcelFilePath $destExcelFilePath
            }
        }
        
        # Open source csv file:
        $srcCsvFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\PlayerVariancesForRound.csv"
        Invoke-PromptingAction 'Open csv file with player variances' {
            Invoke-Item $srcCsvFilePath
        }
        
        # Open new Excel file:
        Invoke-PromptingAction 'Open Excel file with player variances' {
            Invoke-Item $destExcelFilePath
        }
        
        Invoke-PromptingAction 'Copy data from csv file to Excel (paste special -> values only)' -manual
    }
    
    # Get match results:
    Invoke-PromptingAction 'Update match results' {
        # Save these to the TeamResults folder
        # TODO:
        Invoke-PromptingAction 'Get match results to date' {
            . FL:\PowershellScripts\Calculate-MatchResultsToDate.ps1 `
                -season $season -round $round
        }
        
        Invoke-PromptingAction 'Get match results with components of score' {
            . FL:\PowershellScripts\Calculate-MatchResultsToDateWithComponentsOfScore.ps1 `
                -season $season -round $round
        }
    }
    
    # Get log points:
    Invoke-PromptingAction 'Save latest log results to TeamResults\LogPoints.csv' {
        [string] $logPointsFilePath = "$roundFolder\TeamResults\LogPoints.csv"
        if (-not (test-path $logPointsFilePath))
        {
            $teams = import-csv "FL:\MasterData\$season\Teams.csv"
            $byesGroupedByTeam = import-csv "FL:\MasterData\$season\Fixtures\TeamFixtures.csv" `
                | ? { $_.FixtureType -eq 'B' } `
                | select-object @{ n = 'Round'; e={ [int]::Parse($_.Round) }},TeamCode `
                | ? { $_.Round -le $round } `
                | group-object TeamCode
            
            $logPointsRowTemplates = $teams | % {
                $teamCode = $_.TeamCode
                $byesGroup = $byesGroupedByTeam | ? { $_.Name -eq $teamCode }
                if ($byesGroup) {
                    [int] $byeCount = $byesGroup.Group.Count
                } else {
                    [int] $byeCount = 0
                }
                new-object PSObject -property @{
                    TeamCode = $teamCode
                    LogPoints = ''
                    Byes = $byeCount
                    Played = ''
                    Won = ''
                    Lost = ''
                    Drawn = ''
                    PointsFor = ''
                    PointsAgainst = ''
                    PointsDifference = ''
                    BonusPoints = ''
                }
            }
            
            $logPointsRowTemplates `
                | select-object TeamCode,LogPoints,Byes,Played,Won,Lost,Drawn,PointsFor,PointsAgainst,PointsDifference,BonusPoints `
                | export-csv $logPointsFilePath -noTypeInformation
        }
        dev:\tools\notepad++\notepad++.exe $logPointsFilePath
    }
    
    # Update FantasyTeamResultsByRound.xlsx:
    Invoke-PromptingAction 'Create and edit FantasyTeamResults\FantasyTeamResultsByRound.xlsx' {
        $destExcelFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\FantasyTeamResultsByRound.xlsx"
        
        # Copy Excel file from previous round:
        if ($round -gt 1 -and -not (test-path $destExcelFilePath))
        {
            $sourceExcelFilePath = "FL:\DataByRound\Round$($round-1)\FantasyTeamResults\FantasyTeamResultsByRound.xlsx"
            Invoke-PromptingAction 'Copy Excel file from previous round' {
                copy-item $sourceExcelFilePath $destExcelFilePath
            }
        }
        
        # Open new Excel file:
        Invoke-PromptingAction 'Open Excel file with fantasy team results by round' {
            Invoke-Item $destExcelFilePath
        }
        
        Invoke-PromptingAction 'Manually capture a new row for the last round into the Fantasy team results' -manual
    }
    
    # Update the team budget after the completion of the round:
    Invoke-PromptingAction 'Update the team budget after the round' {
        if ($round -gt 1)
        {
            [string] $fantasyTeamBudgetByRoundFilePath = "FL:\DataByRound\Round$($round-1)\FantasyTeamResults\FantasyTeamBudgetByRound.csv"
            $fantasyTeamBudgetByRound = import-csv $fantasyTeamBudgetByRoundFilePath
        } else
        {
            $fantasyTeamBudgetByRound = $null
        }

        [string] $newBudgetAsString = read-host 'New budget (or ENTER to use previous budget)'
        if ([string]::IsNullOrEmpty($newBudgetAsString))
        {
            if ($fantasyTeamBudgetByRound)
            {
                $otherRules = import-csv "FL:\MasterData\$season\Rules\OtherRules.csv"
                [double] $newBudget = [double]::Parse( $otherRules.InitialBudget )
            }
            else
            {
                $prevBudgetAsString = ( 
                    $fantasyTeamBudgetByRound | ? { 
                        [int]::Parse( $_.RoundCompleted ) -eq $round - 1
                    }
                ).Budget
                [double] $newBudget = [double]::Parse( $prevBudgetAsString )
            }
        }
        else
        {
            [double] $newBudget = [double]::Parse( $newBudgetAsString )
        }
        
        $newRecord = new-object PSObject
        $newRecord | Add-Member NoteProperty 'RoundCompleted' $round
        $newRecord | Add-Member NoteProperty 'Budget' $newBudget
        
        if ($fantasyTeamBudgetByRound)
        {
            $fantasyTeamBudgetByRound = @( $fantasyTeamBudgetByRound ) + @( $newRecord )
        }
        else
        {
            $fantasyTeamBudgetByRound = @( $newRecord )
        }
        
        [string] $fantasyTeamBudgetByRoundFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\FantasyTeamBudgetByRound.csv"
        $fantasyTeamBudgetByRound | export-csv $fantasyTeamBudgetByRoundFilePath -noTypeInformation
    }
    
    # Check for data discrepancies:
    Invoke-PromptingAction 'Check for data discrepancies' {
        Invoke-PromptingAction 'Look for players who scored points in the round but did not play' {
            # Input files:
            [string] $playerStatsForRoundFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayerStatsForRound.csv"
            
            # Output files:
            [string] $playersWithPointsWhenTheyDidNotPlayFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayersWithPointsWhenTheyDidNotPlay.csv"
            [string] $playersWithNegativePointsInARoundFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayersWithNegativePointsInARound.csv"
            
            . FL:\PowershellScripts\Get-PlayerStatsWherePlayerScoredPointsButDidNotPlay.ps1 `
                -allPlayerStatsFilePath $playerStatsForRoundFilePath `
                -playersWithPointsWhenTheyDidNotPlayFilePath $playersWithPointsWhenTheyDidNotPlayFilePath `
                -playersWithNegativePointsInARoundFilePath $playersWithNegativePointsInARoundFilePath
        }
        
        Invoke-PromptingAction 'Check for discrepancies between player contributions to team score and the team score' {
            $seasonToDateMatchResultsFilePath = "FL:\DataByRound\Round$round\TeamResults\SeasonToDateMatchResultsWithComponentsOfScore.csv"
            $seasonToDateMatchResults = import-csv "FL:\DataByRound\Round$round\TeamResults\SeasonToDateMatchResultsWithComponentsOfScore.csv" `
                | select-object `
                    @{ n='Round'; e={ [int]::Parse( $_.Round ) }},
                    TeamCode,TeamName,
                    @{ n='TotalPointsScored'; e={ [int]::Parse( $_.TotalPointsScored ) }},
                    @{ n='TotalTriesScored'; e={ [int]::Parse( $_.TotalTriesScored ) }},
                    @{ n='ConversionsScored'; e={ [int]::Parse( $_.ConversionsScored ) }},
                    @{ n='PenaltiesScored'; e={ [int]::Parse( $_.PenaltiesScored ) }},
                    @{ n='DropGoalsScored'; e={ [int]::Parse( $_.DropGoalsScored ) }},
                    @{ n='PenaltyTriesScored'; e={ [int]::Parse( $_.PenaltyTriesScored ) }},
                    @{ n='UnknownPointsScored'; e={ [int]::Parse( $_.UnknownPointsScored ) }} `
                | ? { $_.Round -eq $round }
            
            $seasonToDateMatchResults | ? {
                $_.UnknownPointsScored -ne 0
            } | % {
                Write-Host "$($_.TeamName) have $($_.UnknownPointsScored) points of unknown origin" -foregroundColor Yellow
            }
            Write-Host
            
            $seasonToDateMatchResults | ? {
                $_.PenaltyTriesScored -ne 0
            } | % {
                Write-Host "$($_.TeamName) appeared to score $($_.PenaltyTriesScored) penalty try/tries. Check that this is correct." -foregroundColor Yellow
            }
            Write-Host
        }
    }
}

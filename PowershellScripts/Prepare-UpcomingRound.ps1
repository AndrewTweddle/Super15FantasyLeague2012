param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

Invoke-PromptingAction 'Prepare for upcoming round' {
    $roundFolder = join-path $( convert-path 'FL:\DataByRound' ) "Round$upcomingRound"
    if (-not (test-path $roundFolder))
    {
        [System.IO.Directory]::CreateDirectory( $roundFolder ) | out-null
        Write-Host "Directory created: $roundFolder" -foregroundColor Green
        Write-Host
    }
    $roundFolder = convert-path $roundFolder
    
    # Create sub-folders:
    Invoke-PromptingAction 'Generate folder structure for round' -action {
        $subFoldersToCreate = @(
            'ChosenTeam'
            'Inputs'
            'Predictions'
            'Predictions\NegBin'
            'Forecasts'
            'Forecasts\NegBin'
            'Parameters'
            'Analysis'
            'OptimisationModels'
            'PowershellScripts'
            'TeamSheets'
            'TeamSheets\TeamSheetsAfterCutoff'
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
        Write-Host
    }
    
    Invoke-PromptingAction 'Copy log table to inputs folder' {
        $sourceLogPointsFilePath = "FL:\DataByRound\Round$($upcomingRound-1)\TeamResults\LogPoints.csv"
        $destLogPointsFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\LogPoints.csv"
        
        if ($upcomingRound -gt 1)
        {
            if (test-path $sourceLogPointsFilePath)
            {
                copy-item -path $sourceLogPointsFilePath -destination $destLogPointsFilePath
                Write-Host "Copied log points file after previous round to $destLogPointsFilePath" -foregroundColor Green
            }
            else
            {
                Write-Host "Source file not found: $sourceLogPointsFilePath"
            }
        }
        else
        {
            # TODO: Automate this instead...
            Write-Host 'Please create a LogPoints.csv file in the Inputs sub-folder with zero points per team'
        }
        Write-Host
    }
    
    Invoke-PromptingAction 'Generate previous and current season''s combined match results to date' {
        . FL:\PowershellScripts\Concatenate-MatchResultsFromPreviousAndCurrentSeason.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    Invoke-PromptingAction 'Update player prices and stats' {
        Invoke-PromptingAction 'Extract player data including prices' {
            . FL:\PowershellScripts\Get-PlayerPricesFromDownloadedPlayerStats.ps1 `
                -season $season -upcomingRound $upcomingRound
        }
        
        Invoke-PromptingAction 'Generate previous season and current season''s combined player stats to date' {
            FL:\PowershellScripts\Concatenate-PlayerStatsFromPreviousAndCurrentSeason.ps1 `
                -season $season -upcomingRound $upcomingRound
        }
        
        Invoke-PromptingAction 'Generate aggregate player stats to date' {
            FL:\PowershellScripts\Calculate-AggregateStatsByPlayer.ps1 `
                -season $season -upcomingRound $upcomingRound
        }
        
        Invoke-PromptingAction 'Generate aggregate position stats to date' {
            FL:\PowershellScripts\Calculate-AggregateStatsByPosition.ps1 `
                -season $season -upcomingRound $upcomingRound
        }
    }
    
    Invoke-PromptingAction 'Forecast match results for remainder of the season' {
        $predictPlayOffs = $upcomingRound -le 18
        
        if ($predictPlayOffs)
        {
            # Generate fixtures to forecast:
            Invoke-PromptingAction 'Generate future fixtures to forecast' -action {
                . FL:\PowershellScripts\Calculate-FutureFixturesAtRound.ps1 `
                    -season $season -upcomingRound $upcomingRound
            }
            
            Invoke-PromptingAction 'Forecast match results for remainder of the round robin rounds' {
                . FL:\PowershellScripts\Forecast-MatchResults.ps1 `
                    -season $season -upcomingRound $upcomingRound
            }
            
            # Added 2012-02-26:
            Invoke-PromptingAction 'Generate predicted finalists' {
                . FL:\PowershellScripts\Generate-PredictedFinalists.ps1 `
                    -upcomingRound $upcomingRound
            }
        }
        else
        {
            # Copy predicted finalists file from previous round:
            [string] $prevRoundPredictedFinalistsFilePath = "FL:\DataByRound\Round$($upcomingRound-1)\Forecasts\NegBin\PredictedFinalists_NegBin.csv"
            [string] $predictedFinalistsFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\NegBin\PredictedFinalists_NegBin.csv"
            
            if (-not (test-path $predictedFinalistsFilePath))
            {
                Invoke-PromptingAction 'Copy predicted finalists file from previous round' {
                    copy-item -path $prevRoundPredictedFinalistsFilePath -destination $predictedFinalistsFilePath
                }
            }
            
            # Prompt user to edit it manually:
            Invoke-PromptingAction 'Edit the predicted finalists file to enter the actual finalists' {
                dev:\tools\notepad++\notepad++.exe $( convert-path $predictedFinalistsFilePath )
            }
        }
        
        # Re-generate the fixtures, but using the predicted log table results to determine likely play-off fixtures:
        Invoke-PromptingAction 'Calculate future fixtures based on predicted log position' {
            FL:\PowershellScripts\Calculate-FutureFixturesAtRound.ps1 `
                 -season $season -upcomingRound $upcomingRound `
                 -calculatePlayOffFixtures:$true
        }
        
        if (-not $predictPlayOffs)
        {
            Invoke-PromptingAction 'Forecast match results for all remaining rounds, including the play-offs' {
                . FL:\PowershellScripts\Forecast-MatchResults.ps1 `
                    -season $season -upcomingRound $upcomingRound
            }
            
            $futureFixturesFileName = "FL:\DataByRound\Round$upcomingRound\Inputs\FutureTeamFixtures.csv"
            Invoke-PromptingAction "Check if play-offs will go according to home team advantage. If not, edit $($futureFixturesFileName)." -manual
        }
        
        # Re-generate the forecasts as now the extra play-off rounds will be included:
        Invoke-PromptingAction 'Forecast match results for all remaining rounds, including the play-offs' {
            . FL:\PowershellScripts\Forecast-MatchResults.ps1 `
                -season $season -upcomingRound $upcomingRound
        }
    }
    
    # Copy previous round's rules/parameters
    Invoke-PromptingAction 'Copy previous round''s parameters' {
        [string] $prevRoundEstimationWeightsFilePath = "FL:\DataByRound\Round$($upcomingRound-1)\Parameters\EstimationWeights.csv"
        [string] $estimationWeightsFilePath = "FL:\DataByRound\Round$upcomingRound\Parameters\EstimationWeights.csv"
        if ((test-path $prevRoundEstimationWeightsFilePath) -and -not (test-path $estimationWeightsFilePath))
        {
            Copy-Item -path $prevRoundEstimationWeightsFilePath -destination $estimationWeightsFilePath
        }
        
        # TODO: Copy other parameters as well
        
        Invoke-PromptingAction 'Optional: Update weights in Parameters\EstimationWeights.csv' -manual
    }
    
    # Create a file of injuries:
    [string] $injuriesFilePath = join-path $( convert-path "FL:\DataByRound\Round$upcomingRound" ) 'Inputs\Injuries.csv'
    $injuriesFilePath | out-clipboard
    if ($upcomingRound -gt 1 -and -not (test-path $injuriesFilePath))
    {
        # Copy previous round's predicted injuries to this round's injuries file, dropping injury data for past rounds:
        $prevRoundInjuriesFilePath = "FL:\DataByRound\Round$($upcomingRound - 1)\Inputs\Injuries.csv"
        $prevRoundInjuries = @( import-csv $prevRoundInjuriesFilePath )
        $prevRoundInjuries | ? { [int]::Parse( $_.Round ) -ge $upcomingRound } | export-csv $injuriesFilePath -noTypeInformation
    }
    Invoke-PromptingAction 'Update injury information in inputs\injuries.csv (path has been copied to the clipboard)' -manual
    
    Invoke-PromptingAction 'Check player names in injuries are correct' {
        FL:\PowershellScripts\Get-UnknownPlayersInInjuriesFile.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    # Repeat, to give time to fix the file:
    Invoke-PromptingAction 'REPEAT: Check player names in injuries are correct' {
        FL:\PowershellScripts\Get-UnknownPlayersInInjuriesFile.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    [string] $prevRoundTeamSheetTemplatePath = "C:\FantasyLeague\DataByRound\Round$($upcomingRound-1)\TeamSheets\TeamSheet_Template.csv"
    [string] $teamSheetTemplatePath = "C:\FantasyLeague\DataByRound\Round$upcomingRound\TeamSheets\TeamSheet_Template.csv"
    if ((test-path $prevRoundTeamSheetTemplatePath) -and -not (test-path $teamSheetTemplatePath))
    {
        Copy-Item -path $prevRoundTeamSheetTemplatePath -destination $teamSheetTemplatePath
    }
    
    Invoke-PromptingAction 'Create team sheets csv files for each team' -manual
    
    Invoke-PromptingAction 'Download team sheets web page to TeamSheets\TeamSheets.html' {
        Start-Process 'http://www.ultimatedreamteams.com/site/blog/item/41-super-rugby-weekly-team-sheets.html'
    }
    
    Invoke-PromptingAction 'Check team sheet data' {
        & FL:\PowershellScripts\Reconcile-TeamSheets.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    # Repeat once to see that all fixes have been applied correctly:
    Invoke-PromptingAction 'REPEAT: Check team sheet data' {
        & FL:\PowershellScripts\Reconcile-TeamSheets.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    Invoke-PromptingAction 'Generate probabilities of playing from team sheet and injury data' {
        FL:\PowershellScripts\Generate-ProbabilitiesOfPlaying.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    Invoke-PromptingAction 'Generate player forecasts' {
        . FL:\PowershellScripts\Forecast-PlayerScores.ps1 `
            -season $season -upcomingRound $upcomingRound
    }
    
    # Set up transfer schedule:
    Invoke-PromptingAction 'Set up transfer schedule' {
        Invoke-PromptingAction 'Copy Input\TransferCalculations.xlsx and Transfers.csv from previous round' {
            # TODO: Copy previous round's transfer schedule:
            
            Write-Host 'Instructions:' -foregroundColor Gray
            Write-Host '-------------' -foregroundColor Gray
            Write-Host
            Write-Host '1. Update the TransfersUsed column for the previous round' -foregroundColor Gray
            Write-Host '2. Set the upcoming round field' -foregroundColor Gray
            Write-Host '3. Set the value for the upcoming round in the TransfersAllocatedForKnownInjuries column' -foregroundColor Gray
            Write-Host '4. Optionally set the TransfersAllocatedForOptimization value to a positive or negative number to adjust the transfers allocated to the round' -foregroundColor Gray
            Write-Host '5. Create a new csv file - Inputs\Transfers.csv' -foregroundColor Gray
            Write-Host '6. Copy the following columns into the csv file: UpcomingRound, CumTransfersAvailable, TransfersAvailableForRound' -foregroundColor Gray
            Write-Host '7. Remove rows for previous rounds from the csv file and save it' -foregroundColor Gray
            Write-Host
        }
    }
    
    # Generate optimization scripts:
    Invoke-PromptingAction 'Generate optimization scripts' {
        # TODO: Check if following boundary condition is correct...
        if (22 - $upcomingRound -le 7)
        {
            . FL:\PowershellScripts\Generate-OptimizationScripts.ps1 `
                -season $season -upcomingRound $upcomingRound -reduceAll `
                -roundsAheadToGenerateScriptsFor @(  22 - $upcomingRound )
        }
        else
        {
            . FL:\PowershellScripts\Generate-OptimizationScripts.ps1 `
                -season $season -upcomingRound $upcomingRound -reduceAll
        }
    }
}

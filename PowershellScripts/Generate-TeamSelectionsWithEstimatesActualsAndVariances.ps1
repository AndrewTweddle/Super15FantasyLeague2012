param (
    [string] $pathToPlayerEstimationModelFolder = $( read-host 'Path to folder containing player estimation models' ),
    [string] $pathToTeamSelectionsForRoundsWithoutEstimates = $( read-host 'Input file path to team selections csv file (without estimates)' ),
    [string] $pathToTeamSelectionsForRoundsWithEstimates = $( read-host 'Output file path for team selections csv file (with estimates)' ),
    [switch] $useEstimationModelsForFutureRounds = $false,  
        # If true, then the team selection for round N uses the estimation model for upcoming round N.
        # If false, then the team selection for round N uses the estimation model for $upcomingRound (following parameter)
    [int] $upcomingRound = 1
)

$playerSelectionsWithoutEstimates = import-csv $pathToTeamSelectionsForRoundsWithoutEstimates

$playerSelectionsWithEstimates = $playerSelectionsWithoutEstimates `
    | select-object UpcomingRound,Role,PlayerName,Position,Team,`
        @{ n='Estimates'; 
           e={
                $playerSelection = $_
                $fullName = $playerSelection.PlayerName
                $nextRound = $playerSelection.UpcomingRound
                
                if ($useEstimationModelsForFutureRounds)
                {
                    $round = $nextRound - 1
                }
                else
                {
                    $round = $upcomingRound - 1
                }
                $playerEstimationModelPath = "$pathToPlayerEstimationModelFolder\$($fullName)_AfterRound$($round)_EstimatedScoresForFutureRounds.csv"
                $estimatedScoresForFutureRounds = import-csv $playerEstimationModelPath
                $estimates = $estimatedScoresForFutureRounds | ? { $_.Round -eq $nextRound }
                if (-not $estimates)
                {
                    throw "No estimates for $fullName after round $round for round $nextRound"
                }
                $estimates
           }
        }, `
        @{ n='Multiplier'; e={ if ($_.Role -eq 'S') { 0.5 } else { 1.0 } } } `
    | select-object UpcomingRound,Role,PlayerName,Position,Team, `
        @{n='PredictedAppearanceScore'; e={ $_.Multiplier * $_.Estimates.PredictedAppearanceScore } }, `
        @{n='PredictedTeamResultScore'; e={ $_.Multiplier * $_.Estimates.PredictedTeamResultScore }}, `
        @{n='PredictedNonKickingScore'; e={ $_.Multiplier * $_.Estimates.PredictedNonKickingScore}}, `
        @{n='PredictedKickingScore'; e={ if ($_.Role -eq 'K') { $_.Estimates.PredictedKickingScore } else { 0.0 }}}, `
        @{n='PredictedCaptainScore'; e={ if ($_.Role -eq 'C') { $_.Estimates.PredictedCaptainScore } else { 0.0 }}} `
    | select-object UpcomingRound,Role,PlayerName,Position,Team, PredictedAppearanceScore,
        PredictedTeamResultScore,PredictedNonKickingScore,PredictedKickingScore,PredictedCaptainScore, `
        @{ n='PredictedTotalScore'; 
           e={ $_.PredictedAppearanceScore + $_.PredictedTeamResultScore + $_.PredictedNonKickingScore + $_.PredictedKickingScore + $_.PredictedCaptainScore }
         }

$playerSelectionsWithEstimates | export-csv $pathToTeamSelectionsForRoundsWithEstimates -noTypeInformation

. fl:\PowershellScripts\Generate-TeamSelectionsForRoundsWithEstimates.ps1 `
    'fl:\PrevSeasonAnalysis\EstimationModels\EstimationModelUsedIn2011' `
    'fl:\Simulated2011Season\TeamSelections_WithoutEstimates.Actual.csv' `
    'fl:\Simulated2011Season\TeamSelections_WithEstimates.Actual.csv' `
    -useEstimationModelsForFutureRounds

# Calculate actuals and variances:
[string] $pathToPlayerActualScoresFolder = 'fl:\PrevSeasonAnalysis\PlayerStats'
[string] $pathToTeamSelectionsForRoundsWithEstimates = 'fl:\Simulated2011Season\TeamSelections_WithEstimates.Actual.csv'
[string] $pathToTeamSelectionsWithActualsAndVariances = 'fl:\Simulated2011Season\TeamSelections_WithActualsAndVariances.Actual.csv'
[string] $pathToAggregateEstimatesActualsAndVariancesByRound = 'fl:\Simulated2011Season\AggregateEstimatesActualsAndVariancesByRound.Actual.csv'
    
. fl:\PowershellScripts\Calculate-ActualScoresAndVariancesForPlayerSelection.ps1 `
    $pathToPlayerActualScoresFolder `
    $pathToTeamSelectionsForRoundsWithEstimates `
    $pathToTeamSelectionsWithActualsAndVariances `
    $pathToAggregateEstimatesActualsAndVariancesByRound

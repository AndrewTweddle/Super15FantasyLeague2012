# This is a temporary script to upgrade the team selection outputs to the new format (implemented by Parse-OptimizationOutputs.ps1):
#

param (
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $optimizationModelSubPath = 'ChosenTeam',
    [string] $estimationModel = 'NegBin'
)

# Input file paths:
if ($optimizationModelSubPath -eq 'ChosenTeam')
{
    [string] $optimizationModelFolderPath = "FL:\DataByRound\Round$upcomingRound\ChosenTeam"
}
else
{
    [string] $optimizationModelFolderPath = "FL:\DataByRound\Round$upcomingRound\OptimisationModels\$optimizationModelSubPath"
}

[string] $playerEstimatesFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$estimationModel\PlayerEstimates_$($estimationModel).csv"

# Load data:
$playerEstimates = import-csv $playerEstimatesFilePath
$playerEstimatesByPlayerName = $playerEstimates | group-object PlayerName
$playerEstimatesLookup = @{}
$playerEstimatesByPlayerName | % {
    $concisePlayerName = $_.Name -replace '\W',''
    $playerEstimatesLookup.$concisePlayerName = $_.Group
}

$selectionsByRound = import-csv "$optimizationModelFolderPath\SelectionsByRound.csv" 

$newSelectionsByRound = $selectionsByRound | % {
    [string] $roleCode = $_.RoleCode
    [string] $roleName = $_.RoleName
    [int] $round = [int]::Parse( $_.Round )
    [string] $concisePlayerName = $_.ConcisePlayerName
    
    Write-Host "Round $round : upgrading $concisePlayerName" -foregroundColor Green
    
    # Following code is copied from Parse-OptimizationOutputs.ps1
    
    # Add the estimates for various components:
    $estimate = $playerEstimatesLookup.$concisePlayerName | ? { 
        $round -eq [int]::Parse( $_.Round ) 
    }
    
    [double] $captainFactor = 0
    [double] $kickerFactor = 0
    [double] $substituteFactor = 0
    switch ($roleCode)
    {
        'C' { $captainFactor = 1 }
        'K' { $kickerFactor = 1 }
        'S' { $substituteFactor = 1 }
    }
    $nonKickerFactor = 1 - 0.5 * $substituteFactor
    
    $estimatedPoints = `
        (1 - $kickerFactor) * ($nonKickerFactor + $captainFactor) * $estimate.EstimatedPointsAsPlayer `
        + $kickerFactor * $estimate.EstimatedPointsAsKicker
    
    new-object PSObject -property @{
        Round = $round
        PlayerName = $estimate.PlayerName
        RoleCode = $roleCode
        RoleName = $roleName
        PositionCode = $estimate.PositionCode
        TeamCode = $estimate.TeamCode
        Price = $estimate.Price
        ProbabilityOfPlaying = $estimate.ProbabilityOfPlaying
        EstimatedTotalPoints = $estimatedPoints
        EstimatedCaptainPoints = $captainFactor * $estimate.EstimatedPointsAsPlayer
        EstimatedMatchPoints = $nonKickerFactor * $estimate.EstimatedMatchPoints
        EstimatedPointsForTeamBonusPoints = $nonKickerFactor * $estimate.EstimatedPointsForTeamBonusPoints
        EstimatedAppearancePoints = $nonKickerFactor * $estimate.EstimatedAppearancePoints
        EstimatedPointsForTries = $nonKickerFactor * $estimate.EstimatedPointsForTries
        EstimatedPointsForAssists = $nonKickerFactor * $estimate.EstimatedPointsForAssists
        EstimatedPointsForPenalties = $kickerFactor * $estimate.EstimatedPointsForPenalties
        EstimatedPointsForConversions = $kickerFactor * $estimate.EstimatedPointsForConversions
        EstimatedPointsForDropGoals = $nonKickerFactor * $estimate.EstimatedPointsForDropGoals
        EstimatedPointsForYellowCards = $nonKickerFactor * $estimate.EstimatedPointsForYellowCards
        EstimatedPointsForRedCards = $nonKickerFactor * $estimate.EstimatedPointsForRedCards
        EstimatedTries = $estimate.EstimatedTries
        EstimatedAssists = $estimate.EstimatedAssists
        EstimatedPenalties = $estimate.EstimatedPenalties
        EstimatedConversions = $estimate.EstimatedConversions
        EstimatedDropGoals = $estimate.EstimatedDropGoals
        EstimatedYellowCards = $estimate.EstimatedYellowCards
        EstimatedRedCards = $estimate.EstimatedRedCards
    }
} `
| sort-object Round,RoleCode,PositionCode,PlayerName `
| select-object `
    Round,PlayerName,RoleCode,RoleName,Price,ProbabilityOfPlaying,EstimatedTotalPoints,EstimatedCaptainPoints,`
    EstimatedMatchPoints,EstimatedPointsForTeamBonusPoints,EstimatedAppearancePoints,`
    EstimatedPointsForTries,EstimatedPointsForAssists,EstimatedPointsForPenalties,EstimatedPointsForConversions,`
    EstimatedPointsForDropGoals,EstimatedPointsForYellowCards,EstimatedPointsForRedCards,`
    EstimatedTries,EstimatedAssists,EstimatedPenalties,EstimatedConversions,EstimatedDropGoals,EstimatedYellowCards,EstimatedRedCards

$newSelectionsByRound | export-csv "$optimizationModelFolderPath\NewSelectionsByRound.csv" -noTypeInformation

$teamSelection = $newSelectionsByRound | ? { 
    $_.Round -eq $upcomingRound
} `
| sort-object RoleCode,PositionCode,PlayerName `
| select-object `
    PlayerName,RoleCode,RoleName,Price,ProbabilityOfPlaying,EstimatedTotalPoints,EstimatedCaptainPoints,`
    EstimatedMatchPoints,EstimatedPointsForTeamBonusPoints,EstimatedAppearancePoints,`
    EstimatedPointsForTries,EstimatedPointsForAssists,EstimatedPointsForPenalties,EstimatedPointsForConversions,`
    EstimatedPointsForDropGoals,EstimatedPointsForYellowCards,EstimatedPointsForRedCards,`
    EstimatedTries,EstimatedAssists,EstimatedPenalties,EstimatedConversions,EstimatedDropGoals,EstimatedYellowCards,EstimatedRedCards

$teamSelection | export-csv "$optimizationModelFolderPath\NewTeamSelection.csv" -noTypeInformation

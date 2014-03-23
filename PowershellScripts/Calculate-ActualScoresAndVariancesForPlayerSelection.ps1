param (
    [string] $pathToPlayerActualScoresFolder = $( read-host 'Path to folder containing actual scores for players' ),
    [string] $pathToTeamSelectionsForRoundsWithEstimates = $( read-host 'Input file path to team selections csv file (with estimates)' ),
    [string] $pathToTeamSelectionsWithActualsAndVariances = $( read-host 'Output file path for team selections csv file (with actuals and variances)' ),
    [string] $pathToAggregateEstimatesActualsAndVariancesByRound = $( read-host 'Output file path for aggregates by round (with actuals and variances)' )
)

$teamSelectionInputs = import-csv $pathToTeamSelectionsForRoundsWithEstimates `
    | select-object `
        @{n='UpcomingRound';e={[int]::Parse($_.UpcomingRound)}},`
        Role,PlayerName,Position,Team,`
        @{n='PredictedAppearanceScore'; e={[double]::Parse($_.PredictedAppearanceScore)}},`
        @{n='PredictedTeamResultScore'; e={[double]::Parse($_.PredictedTeamResultScore)}},`
        @{n='PredictedNonKickingScore'; e={[double]::Parse($_.PredictedNonKickingScore)}},`
        @{n='PredictedKickingScore'; e={[double]::Parse($_.PredictedKickingScore)}},`
        @{n='PredictedCaptainScore'; e={[double]::Parse($_.PredictedCaptainScore)}},`
        @{n='PredictedTotalScore'; e={[double]::Parse($_.PredictedTotalScore)}}

$teamSelectionOutputs = $teamSelectionInputs | % {
    $playerSelection = $_
    $playerName = $playerSelection.PlayerName
    $upcomingRound = $playerSelection.UpcomingRound
    $playerActuals = import-csv "$pathToPlayerActualScoresFolder\$($playerName).csv"
    $playerActualsForRound = $playerActuals `
        | ? { [int]::Parse($_.RoundsCompleted) -eq $upcomingRound } `
        | select-object `
            @{n='PointsAsNonKicker'; e={[double]::Parse($_.PointsAsNonKicker)}},`
            @{n='KickingPoints'; e={[double]::Parse($_.KickingPoints)}},`
            @{n='FullAppearance'; e={[double]::Parse($_.FullAppearance)}},`
            @{n='PartAppearance'; e={[double]::Parse($_.PartAppearance)}},`
            @{n='HomeWin'; e={[double]::Parse($_.HomeWin)}},`
            @{n='HomeDraw'; e={[double]::Parse($_.HomeDraw)}},`
            @{n='AwayWin'; e={[double]::Parse($_.AwayWin)}},`
            @{n='AwayDraw'; e={[double]::Parse($_.AwayDraw)}}
    
    if ($playerActualsForRound)
    {
        if ($_.Role -eq 'S') 
        { 
            $multiplier = 0.5
        }
        else
        {
            $multiplier = 1.0
        }
        $ActualAppearanceScore = $multiplier * ( 4 * $playerActualsForRound.FullAppearance + 2 * $playerActualsForRound.PartAppearance)
        $ActualTeamResultScore = $multiplier * ( 4 * $playerActualsForRound.HomeWin + 2 * $playerActualsForRound.HomeDraw `
                                               + 8 * $playerActualsForRound.AwayWin + 4 * $playerActualsForRound.AwayDraw )
        if ($_.Role -eq 'K')
        { 
            $ActualKickingScore = $playerActualsForRound.KickingPoints
        }
        else
        {
            $ActualKickingScore = 0.0
        }
        $ActualNonKickingScore = $multiplier * $playerActualsForRound.PointsAsNonKicker - $ActualAppearanceScore - $ActualTeamResultScore
        if ($_.Role -eq 'C')
        {
            $ActualCaptainScore = $playerActualsForRound.PointsAsNonKicker
        }
        else
        {
            $ActualCaptainScore = 0.0
        }
        $ActualTotalScore = $ActualAppearanceScore + $ActualTeamResultScore + $ActualKickingScore + $ActualNonKickingScore + $ActualCaptainScore
        
        $AppearanceScoreVariance = $ActualAppearanceScore - $playerSelection.PredictedAppearanceScore
        $TeamResultScoreVariance = $ActualTeamResultScore - $playerSelection.PredictedTeamResultScore
        $NonKickingScoreVariance = $ActualNonKickingScore - $playerSelection.PredictedNonKickingScore
        $KickingScoreVariance = $ActualKickingScore - $playerSelection.PredictedKickingScore
        $CaptainScoreVariance = $ActualCaptainScore - $playerSelection.PredictedCaptainScore
        $TotalScoreVariance = $ActualTotalScore - $playerSelection.PredictedTotalScore
        
        $playerSelection `
            | select-object `
                UpcomingRound,Role,PlayerName,Position,Team,PredictedAppearanceScore,PredictedTeamResultScore,`
                PredictedNonKickingScore,PredictedKickingScore,PredictedCaptainScore,PredictedTotalScore,`
                @{ n='ActualAppearanceScore'; e={$ActualAppearanceScore}},`
                @{ n='ActualTeamResultScore'; e={$ActualTeamResultScore}},`
                @{ n='ActualNonKickingScore'; e={$ActualNonKickingScore}},`
                @{ n='ActualKickingScore'; e={$ActualKickingScore}},`
                @{ n='ActualCaptainScore'; e={$ActualCaptainScore}},`
                @{ n='ActualTotalScore'; e={$ActualTotalScore}},`
                @{ n='AppearanceScoreVariance'; e={$AppearanceScoreVariance}},`
                @{ n='TeamResultScoreVariance'; e={$TeamResultScoreVariance}},`
                @{ n='NonKickingScoreVariance'; e={$NonKickingScoreVariance}},`
                @{ n='KickingScoreVariance'; e={$KickingScoreVariance}},`
                @{ n='CaptainScoreVariance'; e={$CaptainScoreVariance}},`
                @{ n='TotalScoreVariance'; e={$TotalScoreVariance}}
    }
    else
    {
        throw "No actuals found for player $playerName after round $upcomingRound"
    }
}

$teamSelectionOutputs | export-csv $pathToTeamSelectionsWithActualsAndVariances -noTypeInformation

if ($pathToAggregateEstimatesActualsAndVariancesByRound)
{
    $propertyNames = @('PredictedAppearanceScore','PredictedTeamResultScore',`
        'PredictedNonKickingScore','PredictedKickingScore','PredictedCaptainScore','PredictedTotalScore',`
        'ActualAppearanceScore', 'ActualTeamResultScore', 'ActualNonKickingScore',`
        'ActualKickingScore','ActualCaptainScore','ActualTotalScore',`
        'AppearanceScoreVariance','TeamResultScoreVariance','NonKickingScoreVariance',`
        'KickingScoreVariance','CaptainScoreVariance', 'TotalScoreVariance')
    
    $groupings = $teamSelectionOutputs | group-object UpcomingRound
    $aggregates = $groupings | % {
        $round = [int]::Parse( $_.Name )
        $players = $_.Group
        $aggregate = new-object PSObject
        $aggregate | Add-Member  -memberType NoteProperty -name 'Round' -value $round
        
        $propertyNames | % {
            $propertyName = $_
            $propertyValue = $players | Measure-Object -sum -property $propertyName | % { $_.Sum }
            $aggregate | Add-Member -memberType NoteProperty -name $propertyName -value $propertyValue
        }
        
        $aggregate
    }
    
    # Calculate cumulative estimates, actuals and variances by component:
    $aggregates | % {
        $aggregate = $_
        $round = $aggregate.Round
        
        $propertyNames | % {
            $propertyName = $_
            $propertyValue = $aggregates | ? { $_.Round -le $round } | Measure-Object -sum -property $propertyName | % { $_.Sum }
            $aggregate | Add-Member -memberType NoteProperty -name "Cumulative$propertyName" -value $propertyValue
        }
    }
    
    $aggregates | export-csv $pathToAggregateEstimatesActualsAndVariancesByRound -noTypeInformation
}
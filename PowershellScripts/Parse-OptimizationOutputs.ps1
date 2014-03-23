param (
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $optimizationModelSubPath = $( read-host 'Model sub-path (without leading or trailing slashes)' ),
    [TimeSpan] $durationOfRun = $( throw 'Please provide the duration of the run' ),
    [string] $estimationModel = 'NegBin'
)

# Input file paths:
[string] $optimizationModelFolderPath = "FL:\DataByRound\Round$upcomingRound\OptimisationModels\$optimizationModelSubPath"
[string] $playerEstimatesFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$estimationModel\PlayerEstimates_$($estimationModel).csv"

# Output file paths:
[string] $lpOutputsFilePath = "$optimizationModelFolderPath\optimization.lp.outputs"

# Load data:
$lpOutputs = Get-Content $lpOutputsFilePath

$playerEstimates = import-csv $playerEstimatesFilePath
$playerEstimatesByPlayerName = $playerEstimates | group-object PlayerName
$playerEstimatesLookup = @{}
$playerEstimatesByPlayerName | % {
    $concisePlayerName = $_.Name -replace '\W',''
    $playerEstimatesLookup.$concisePlayerName = $_.Group
}

# Check if a feasible solution was found:
if ($lpOutputs | ? { $_.StartsWith('This problem is infeasible') })
{ 
    [bool] $feasible = $false
    
    Write-Host "No feasible solution found" -foregroundColor Red
    Write-Host
    
    # Create contents of summary file:
    [string] $summaryContents = @"
Feasible : No
Duration : $durationOfRun
"@

    # Create summary record
    $summary = new-object PSObject -property @{
        UpcomingRound = $upcomingRound
        OptimizationModelSubPath = $optimizationModelSubPath
        IsFeasible = $feasible
        IsOptimal = $false
        OptimalValue = 0.0
        TimeCompleted = get-date
        DurationOfRun = $durationOfRun
    }
    
    # Delete output files if found:
    remove-item "$optimizationModelFolderPath\ScoresByRound.csv"
    remove-item "$optimizationModelFolderPath\SelectionsByRound.csv"
    remove-item "$optimizationModelFolderPath\TransfersByRound.csv"
    remove-item "$optimizationModelFolderPath\TransferCountsByRound.csv"
    remove-item "$optimizationModelFolderPath\TeamSelection.csv"
}
else 
{ 
    [bool] $feasible = $true
    
    # Determine whether the solution was suboptimal:
    if ($lpOutputs | ? { $_.StartsWith('Suboptimal solution') })
    {
        [bool] $subOptimal = $true
        
        Write-Host 'The solution is sub-optimal!' -foregroundColor Yellow
        Write-Host 
    }
    else
    {
        [bool] $subOptimal = $false
    }
    
    # Get optimal value:
    [double] $optimalValue = $lpOutputs | ? {
        $_ -match '^Value\ of\ objective\ function:\s+(?<OptimalValue>(\d|\.)+)$'
    } | % {
        [double]::Parse( $matches.OptimalValue )
    }
    
    Write-Host "The value of the objective function is $optimalValue" -foregroundColor Green
    Write-Host
    
    # Get scores by round
    $scoresByRound = $lpOutputs | ? {
        $_ -match '^ScoreForRound_(?<Round>\d+)\s+(?<Score>(\d|\.)+)$'
    } | % {
        $scoreForRound = new-object PSObject
        $scoreForRound | Add-Member NoteProperty 'Round' -value $( [int]::Parse( $matches.Round ) )
        $scoreForRound | Add-Member NoteProperty 'Score' -value $( [double]::Parse( $matches.Score ) )
        $scoreForRound
    }
    $scoresByRound | export-csv "$optimizationModelFolderPath\ScoresByRound.csv" -noTypeInformation
    
    # Get selections:
    $playerStatuses = $lpOutputs | ? {
        $_ -match '^(?<Status>(IsInTeam)|(IsKicker)|(IsCaptain)|(IsSubstitute))_(?<ConcisePlayerName>(?:(?!_).)+)_(?<Round>\d+)\s+1$'
    } | % {
        new-object PSObject -property @{
            Status = $matches.Status
            ConcisePlayerName = $matches.ConcisePlayerName
            Round = [int]::Parse($matches.Round)
        }
    }
    $groupedStatuses = $playerStatuses | group-object ConcisePlayerName,Round
    $selectionsByRound = $groupedStatuses | % {
        $groupedStatus = $_
        $statusRecord = $groupedStatus.Group | ? { $_.Status -ne 'IsInTeam' }
        if ($statusRecord)
        {
            switch ($statusRecord.Status)
            {
                'IsKicker' { 
                    $roleCode = 'K' 
                    $roleName = 'Kicker'
                }
                'IsCaptain' {
                    $roleCode = 'C'
                    $roleName = 'Captain'
                }
                default {
                    $roleCode = 'S'
                    $roleName = 'Substitute'
                }
            }
        }
        else
        {
            $roleCode = 'P'
            $roleName = 'Player'
            $statusRecord = $groupedStatus.Group | select-object -first 1
        }
        
        [int] $round = $statusRecord.Round
        [string] $concisePlayerName = $statusRecord.ConcisePlayerName
        
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
    
    $selectionsByRound | export-csv "$optimizationModelFolderPath\SelectionsByRound.csv" -noTypeInformation
    
    # Get players transferred in and out:
    $transfersByRound = $lpOutputs | ? {
        $_ -match 'Transfers(?<Direction>(In)|(Out))_(?<ConcisePlayerName>(?:(?!_).)+)_(?<Round>\d+)\s+1'
    } | % {
        new-object PSObject -property @{
            Round = [int]::Parse($matches.Round)
            Direction = $matches.Direction
            ConcisePlayerName = $matches.ConcisePlayerName
        }
    } | select-object Round,Direction,ConcisePlayerName | sort-object Round,Direction,ConcisePlayerName
    
    $transfersByRound | export-csv "$optimizationModelFolderPath\TransfersByRound.csv" -noTypeInformation
    
    # Get transfer counts by round:
    $transferCountsByRound = $lpOutputs | ? {
        $_ -match '^TransfersForRound_(?<Round>\d+)\s+(?<Transfers>\d+)$'
    } | % {
        new-object PSObject -property @{
            Round = [int]::Parse($matches.Round)
            Transfers = [int]::Parse($matches.Transfers)
        }
    } | select-object Round,Transfers | sort-object Round
    
    $transferCountsByRound | export-csv "$optimizationModelFolderPath\TransferCountsByRound.csv" -noTypeInformation
    
    # Save player selections for current or clamped round:
    $teamSelection = $selectionsByRound | ? { 
        $_.Round -eq $upcomingRound
    } `
    | sort-object RoleCode,PositionCode,PlayerName `
    | select-object `
        PlayerName,RoleCode,RoleName,Price,ProbabilityOfPlaying,EstimatedTotalPoints,EstimatedCaptainPoints,`
        EstimatedMatchPoints,EstimatedPointsForTeamBonusPoints,EstimatedAppearancePoints,`
        EstimatedPointsForTries,EstimatedPointsForAssists,EstimatedPointsForPenalties,EstimatedPointsForConversions,`
        EstimatedPointsForDropGoals,EstimatedPointsForYellowCards,EstimatedPointsForRedCards,`
        EstimatedTries,EstimatedAssists,EstimatedPenalties,EstimatedConversions,EstimatedDropGoals,EstimatedYellowCards,EstimatedRedCards
    
    $teamSelection | export-csv "$optimizationModelFolderPath\TeamSelection.csv" -noTypeInformation
    [string[]] $playerSummaries = @( 
        $teamSelection | % {
            "$($_.RoleCode) $($_.RoleName) : $($_.ConcisePlayerName)"
        }
    )
    
    # Save summary of run:
    [string] $summaryContents = @"
Feasible      : Yes
Optimal       : $( if ($subOptimal) {'No'} else {'Yes'} )
Optimal value : $optimalValue
Duration      : $durationOfRun


"@ + $( join-string -strings $playerSummaries -NewLine )

    # Create summary record
    $summary = new-object PSObject -property @{
        UpcomingRound = $upcomingRound
        OptimizationModelSubPath = $optimizationModelSubPath
        IsFeasible = $feasible
        IsOptimal = -not $subOptimal
        OptimalValue = $optimalValue
        TimeCompleted = get-date
        DurationOfRun = $durationOfRun
    }
}

# Save summary columns to a csv file:
$summary = $summary | select-object UpcomingRound,OptimizationModelSubPath,IsFeasible,IsOptimal,OptimalValue,TimeCompleted,DurationOfRun

# Write out summary of run:
Write-Host "====================================================" -foregroundColor Yellow
Write-Host "Summary:" -foregroundColor Yellow
Write-Host
Write-Host $summaryContents -foregroundColor Green
Write-Host

$summaryFilePath = "$(convert-path $optimizationModelFolderPath)\Summary.txt"
[System.IO.File]::WriteAllText( $summaryFilePath, $summaryContents )

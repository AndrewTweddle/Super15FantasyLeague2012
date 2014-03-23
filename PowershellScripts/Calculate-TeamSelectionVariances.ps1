param (
    [int] $season = $( read-host 'Season' ),
    [int] $round = $( read-host 'Completed round' )
    # Later: [string] $optimizationModelSubPath = $( read-host 'Model sub-path (without leading or trailing slashes)' ),
    # Later: [string] $forecastingModel = 'NegBin'
)

# Input files:
[string] $teamSelectionFilePath = "FL:\DataByRound\Round$round\ChosenTeam\TeamSelection.csv"
[string] $actualPlayerStatsForRoundFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayerStatsForRound.csv"

# Output files:
[string] $playerVariancesForRoundFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\PlayerVariancesForRound.csv"
[string] $teamVariancesForRoundFilePath = "FL:\DataByRound\Round$round\FantasyTeamResults\TeamVariancesForRound.csv"

# Import data:
$teamSelection = import-csv $teamSelectionFilePath
$actualPlayerStats = import-csv $actualPlayerStatsForRoundFilePath
$actualPlayerStatsLookup = @{}
$actualPlayerStats | % {
    $actualPlayerStatsLookup[$_.FullName] = $_
}

[string[]] $estimationProperties = @(
    'ProbabilityOfPlaying'
    'EstimatedTotalPoints'
    'EstimatedCaptainPoints'
    'EstimatedMatchPoints'
    'EstimatedPointsForTeamBonusPoints'
    'EstimatedAppearancePoints'
    'EstimatedPointsForTries'
    'EstimatedPointsForAssists'
    'EstimatedPointsForPenalties'
    'EstimatedPointsForConversions'
    'EstimatedPointsForDropGoals'
    'EstimatedPointsForYellowCards'
    'EstimatedPointsForRedCards'
    'EstimatedTries'
    'EstimatedAssists'
    'EstimatedConversions'
    'EstimatedPenalties'
    'EstimatedDropGoals'
    'EstimatedYellowCards'
    'EstimatedRedCards'
)
[string[]] $actualProperties = @(
    'Played'
    'ActualTotalPoints'
    'ActualCaptainPoints'
    'ActualMatchPoints'
    'ActualPointsForTeamBonusPoints'
    'ActualAppearancePoints'
    'ActualPointsForTries'
    'ActualPointsForAssists'
    'ActualPointsForPenalties'
    'ActualPointsForConversions'
    'ActualPointsForDropGoals'
    'ActualPointsForYellowCards'
    'ActualPointsForRedCards'
    'ActualTries'
    'ActualAssists'
    'ActualConversions'
    'ActualPenalties'
    'ActualDropGoals'
    'ActualYellowCards'
    'ActualRedCards'
)
[string[]] $varianceProperties = @(
    'ProbabilityOfPlayingVariance'
    'TotalPointsVariance'
    'CaptainPointsVariance'
    'MatchPointsVariance'
    'PointsForTeamBonusPointsVariance'
    'AppearancePointsVariance'
    'TryPointsVariance'
    'AssistPointsVariance'
    'PenaltyPointsVariance'
    'ConversionPointsVariance'
    'DropGoalPointsVariance'
    'YellowCardPointsVariance'
    'RedCardPointsVariance'
    'TriesVariance'
    'AssistsVariance'
    'ConversionsVariance'
    'PenaltiesVariance'
    'DropGoalsVariance'
    'YellowCardsVariance'
    'RedCardsVariance'
)

$playerVariances = @(
    $teamSelection | % {
        $selectedPlayer = $_
        $actualStats = $actualPlayerStatsLookup[$selectedPlayer.PlayerName]
        
        $actualStats | Add-Member NoteProperty 'Played' -value $( `
            [int]::Parse( $actualStats.FullAppearance ) + [int]::Parse( $actualStats.PartAppearance ) `
        )
        
        [double] $actualTotalPoints = 0.0
        [double] $actualCaptainPoints = 0.0
        
        [double] $actualPointsAsNonKicker = [double]::Parse($actualStats.PointsAsNonKicker)
        [double] $actualPointsAsKicker = [double]::Parse($actualStats.PointsAsKicker)
        
        [double] $nonKickingFactor = 1.0
        [double] $kickingFactor = 0.0
        
        switch ($selectedPlayer.RoleCode)
        {
            'C' { 
                $actualCaptainPoints = $actualPointsAsNonKicker
                $actualTotalPoints = $actualPointsAsNonKicker * 2.0
            }
            'K' {
                $actualTotalPoints = $actualPointsAsKicker
                $kickingFactor = 1.0
            }
            'P' { 
                $actualTotalPoints = $actualPointsAsNonKicker
            }
            'S' { 
                $nonKickingFactor = 0.5
                $actualTotalPoints = $nonKickingFactor * $actualPointsAsNonKicker
            }
        }
        $actualStats | Add-Member NoteProperty 'ActualTotalPoints' $actualTotalPoints
        $actualStats | Add-Member NoteProperty 'ActualCaptainPoints' $actualCaptainPoints

        # Convert actual points by component into actual points based on player's role:
        [double] $actualMatchPoints = $nonKickingFactor * [double]::Parse( $actualStats.MatchPoints )
        [double] $actualPointsForTeamBonusPoints = $nonKickingFactor * [double]::Parse( $actualStats.PointsForTeamBonusPoints )
        [double] $actualAppearancePoints = $nonKickingFactor * [double]::Parse( $actualStats.AppearancePoints )
        [double] $actualPointsForTries = $nonKickingFactor * [double]::Parse( $actualStats.PointsForTries )
        [double] $actualPointsForAssists = $nonKickingFactor * [double]::Parse( $actualStats.PointsForAssists )
        [double] $actualPointsForPenalties = $kickingFactor * [double]::Parse( $actualStats.PointsForPenalties )
        [double] $actualPointsForConversions = $kickingFactor * [double]::Parse( $actualStats.PointsForConversions )
        [double] $actualPointsForDropGoals = $nonKickingFactor * [double]::Parse( $actualStats.PointsForDropGoals )
        [double] $actualPointsForYellowCards = $nonKickingFactor * [double]::Parse( $actualStats.PointsForYellowCards )
        [double] $actualPointsForRedCards = $nonKickingFactor * [double]::Parse( $actualStats.PointsForRedCards )
        
        $actualStats | Add-Member NoteProperty 'ActualMatchPoints' $actualMatchPoints
        $actualStats | Add-Member NoteProperty 'ActualPointsForTeamBonusPoints' $actualPointsForTeamBonusPoints
        $actualStats | Add-Member NoteProperty 'ActualAppearancePoints' $actualAppearancePoints
        $actualStats | Add-Member NoteProperty 'ActualPointsForTries' $actualPointsForTries
        $actualStats | Add-Member NoteProperty 'ActualPointsForAssists' $actualPointsForAssists
        $actualStats | Add-Member NoteProperty 'ActualPointsForPenalties' $actualPointsForPenalties
        $actualStats | Add-Member NoteProperty 'ActualPointsForConversions' $actualPointsForConversions
        $actualStats | Add-Member NoteProperty 'ActualPointsForDropGoals' $actualPointsForDropGoals
        $actualStats | Add-Member NoteProperty 'ActualPointsForYellowCards' $actualPointsForYellowCards
        $actualStats | Add-Member NoteProperty 'ActualPointsForRedCards' $actualPointsForRedCards
        
        $actualStats | Add-Member NoteProperty 'ActualTries' $( [int]::Parse( $actualStats.Tries) )
        $actualStats | Add-Member NoteProperty 'ActualAssists' $( [int]::Parse( $actualStats.Assists) )
        $actualStats | Add-Member NoteProperty 'ActualConversions' $( [int]::Parse( $actualStats.Conversions) )
        $actualStats | Add-Member NoteProperty 'ActualPenalties' $( [int]::Parse( $actualStats.Penalties) )
        $actualStats | Add-Member NoteProperty 'ActualDropGoals' $( [int]::Parse( $actualStats.DropGoals) )
        $actualStats | Add-Member NoteProperty 'ActualYellowCards' $( [int]::Parse( $actualStats.YellowCard) )
        $actualStats | Add-Member NoteProperty 'ActualRedCards' $( [int]::Parse( $actualStats.RedCard) )
        
        $playerVariance = new-object PSObject -property @{
            PlayerName = $selectedPlayer.PlayerName
            RoleCode = $selectedPlayer.RoleCode
            RoleName = $selectedPlayer.RoleName
            Price = [double]::Parse( $selectedPlayer.Price )
        }
        $playerVariance = $playerVariance | select-object PlayerName,RoleCode,RoleName,Price
        
        [int] $dynamicPropertyCount = $estimationProperties.Length
        
        # Add variance properties:
        0..($dynamicPropertyCount-1) | % {
            $propertyIndex = $_
            $estimationPropertyName = $estimationProperties[$propertyIndex]
            $actualPropertyName = $actualProperties[$propertyIndex]
            $variancePropertyName = $varianceProperties[$propertyIndex]
            
            [double] $variance = $actualStats.$actualPropertyName - $selectedPlayer.$estimationPropertyName
            $playerVariance | Add-Member NoteProperty $variancePropertyName $variance
        }
        
        # Add percent variance properties:
        0..($dynamicPropertyCount-1) | % {
            $propertyIndex = $_
            $estimationPropertyName = $estimationProperties[$propertyIndex]
            $actualPropertyName = $actualProperties[$propertyIndex]
            $variancePropertyName = $varianceProperties[$propertyIndex] -replace 'Variance','PercentVariance'
            
            if ($selectedPlayer.$estimationPropertyName -eq 0.0)
            {
                [double] $percentVariance = 0.0
            }
            else
            {
                [double] $percentVariance = 100.0 * ($actualStats.$actualPropertyName - $selectedPlayer.$estimationPropertyName)/([double]$selectedPlayer.$estimationPropertyName)
            }
            $playerVariance | Add-Member NoteProperty $variancePropertyName $percentVariance
        }
        
        # Add estimated properties:
        0..($dynamicPropertyCount-1) | % {
            $propertyIndex = $_
            $propertyName = $estimationProperties[$propertyIndex]
            [double] $value = $selectedPlayer.$propertyName
            $playerVariance | Add-Member NoteProperty $propertyName $value
        }
        
        # Add actual properties:
        0..($dynamicPropertyCount-1) | % {
            $propertyIndex = $_
            $propertyName = $actualProperties[$propertyIndex]
            [double] $value = $actualStats.$propertyName
            $playerVariance | Add-Member NoteProperty $propertyName $value
        }
        
        # Add extra properties which may be of interest:
        $playerVariance | Add-Member NoteProperty 'ActualFullAppearance' $( [int]::Parse( $actualStats.FullAppearance ) )
        $playerVariance | Add-Member NoteProperty 'ActualPartAppearance' $( [int]::Parse( $actualStats.PartAppearance ) )
        $playerVariance | Add-Member NoteProperty 'ActualHomeWin' $( [int]::Parse( $actualStats.HomeWin ) )
        $playerVariance | Add-Member NoteProperty 'ActualHomeDraw' $( [int]::Parse( $actualStats.HomeDraw ) )
        $playerVariance | Add-Member NoteProperty 'ActualAwayWin' $( [int]::Parse( $actualStats.AwayWin ) )
        $playerVariance | Add-Member NoteProperty 'ActualAwayDraw' $( [int]::Parse( $actualStats.AwayDraw ) )
        $playerVariance | Add-Member NoteProperty 'ActualBonusPoints' $( [int]::Parse( $actualStats.BonusPoints ) )
        
        # Return the variance record:
        $playerVariance
    }
)

$playerVariances | export-csv $playerVariancesForRoundFilePath -noTypeInformation

$teamVariance = new-object PSObject
$teamVariance | Add-Member NoteProperty Season $season
$teamVariance | Add-Member NoteProperty Round $round

$varianceProperties | % {
    $propertyName = $_
    if ($propertyName -eq 'ProbabilityOfPlayingVariance')
    {
        [double] $aggregateValue = ($playerVariances | measure-object $propertyName -Average).Average
    }
    else
    {
        [double] $aggregateValue = ($playerVariances | measure-object $propertyName -sum).Sum
    }
    $teamVariance | Add-Member NoteProperty $propertyName $aggregateValue
}

$teamVariance | export-csv $teamVariancesForRoundFilePath -noTypeInformation

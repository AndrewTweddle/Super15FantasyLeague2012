param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $optimizationModelSubPath = $( read-host 'Model sub-path (without leading or trailing slashes)' ),
    [string] $forecastingModel = 'NegBin'
    # Ignore the following - the algorithm is fast enough without doing extra filtering...
    # [int] $startRound = $upcomingRound,
    # [int] $endRound = 21
)

# Inputs:
[string] $playerEstimatesFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$forecastingModel\PlayerEstimates_$($forecastingModel).csv"
[string] $teamForPreviousRoundFilePath = "FL:\DataByRound\Round$($upcomingRound - 1)\ChosenTeam\TeamSelection.csv"

# Outputs:
[string] $playerModelsFilePath = "FL:\DataByRound\Round$upcomingRound\OptimisationModels\$optimizationModelSubPath\PlayerModel.csv"

# Load lookup data:
$players = import-csv "FL:\MasterData\$season\Players\Players.csv"
$concisePlayerNameLookup = @{}
$players | % {
    $playerName = $_.PlayerName
    $concisePlayerName = $playerName -replace '\W',''
    $concisePlayerNameLookup[$concisePlayerName] = $playerName
}

# Load input data:
$playerEstimates = import-csv $playerEstimatesFilePath

if ($upcomingRound -eq 1)
{
    $playerModels = $playerEstimates | `
        select-object `
            Round,PlayerName,PositionCode,TeamCode,Price,GamesPlayed,EstimatedPointsAsPlayer,EstimatedPointsAsKicker,`
            @{ n='PreviousRole';
               e={
                    'X'  # TODO: Is this correct for a player not chosen last round
               }
            }
}
else
{
    $teamForPreviousRound = import-csv $teamForPreviousRoundFilePath `
        | select-object `
            PlayerName,
            RoleCode,
            RoleName
    
    $playerModels = $playerEstimates | `
        select-object `
            Round,PlayerName,PositionCode,TeamCode,Price,GamesPlayed,EstimatedPointsAsPlayer,EstimatedPointsAsKicker,`
            @{ n='PreviousRole';
               e={
                    $playerName = $_.PlayerName
                    $playerSelection = $teamForPreviousRound | ? { $_.PlayerName -eq $playerName }
                    
                    # TODO: Consider only setting previous role for the very next round...
                    if ($playerSelection)
                    {
                        $playerSelection.RoleCode
                    }
                    else
                    {
                        'X'
                    }
               }
            }
    
}

# Export the data:
$playerModels | export-csv $playerModelsFilePath -noTypeInformation

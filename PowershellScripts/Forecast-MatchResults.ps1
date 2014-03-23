param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $estimationModel = 'NegBin',
    [double] $weightingOfEachGameLastSeason = 0.8,  # Was: 0.25, then 0.8, then 0.55 from round 15
    [double] $weightingOfGameRelativeToPreviousGame = 1.15,  # was 1.05. Then 1.1. Then 1.15 from round 15.
    [string] $baseFieldToEstimate = '',  # Estimate all fields
    [string] $pathToR = 'C:\Program Files\R\R-2.14.1\bin\x64\R.exe',
    [string] $pathToRScript = 'FL:\RScripts\ForecastMatchResults.R'
)

# Command line arguments to pass to script:
#    1: season          (default 2012)
#    2: upcoming round  (default 1)
#    3: model to use    (default "NegBin")
#    4: weighting of previous eason game to first game of current season  (default 0.25)
#    5: weighting of a game in the current season to a game in the previous round (default 1.05)
#    6: base field name to estimate/forecast (default "" => estimate all fields)

$rScriptPath = convert-path $pathToRScript

[string[]] $arguments = @(
    '--no-save'
    '-f'
    $rScriptPath
    '--slave'
    '--args'
    $season
    $upcomingRound
    $estimationModel
    $weightingOfEachGameLastSeason
    $weightingOfGameRelativeToPreviousGame
    $baseFieldToEstimate
)

& $pathToR $arguments

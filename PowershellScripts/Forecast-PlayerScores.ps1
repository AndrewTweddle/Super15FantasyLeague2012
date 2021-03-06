param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $estimationModel = 'NegBin',
    [string] $pathToR = 'C:\Program Files\R\R-2.14.1\bin\x64\R.exe',
    [string] $pathToRScript = 'FL:\RScripts\ForecastPlayerScores.R'
)

# Command line arguments to pass to script:
#    1: season          (default 2012)
#    2: upcoming round  (default 1)
#    3: model to use    (default "NegBin")

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
)

& $pathToR $arguments

param (
    [string] $forecastsFilePath = 'C:\FantasyLeague\RScripts\ScratchPad\Results\Test\glm.nb.TotalPointsScored.NoReferees.Forecasts.csv'
)
$forecasts = import-csv $forecastsFilePath

$forecasts | group-object TeamCode `
    | select-object Name,@{
        n='Wins'; e={ ($_.Group | measure-object PredictedProbWin -sum).Sum } 
    } `
    | sort-object Wins -desc

# TODO:
# 1. Also extract likely log points from outputs
# 2. Generate expected finalists and update fixtures and fixture types with finalists
# 3. Re-forecast extra rounds with finalists
# 4. Generate various scenarios of who the finalists might be, with probabilities on each scenario
# 

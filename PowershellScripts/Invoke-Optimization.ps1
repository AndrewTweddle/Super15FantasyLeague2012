param (
    [string] $modelSubPath = $( read-host 'Optimization model subpath' ),
    [string] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [int] $endRound = 21,  # The last round to optimize to
    [double] $budget = 200.0,
    [string] $transferAllocation = '', # A comma separated list of round offset and transfers available up to that round
    [string] $targetScorePerRound = '' # , # Whitespace to ignore, else a string that parses to a double
    # [int] $filterByCandidateType = 0,
    # [int] $breakAtFirst = 0
)

Set-Location 

$swatch = [System.Diagnostics.Stopwatch]::StartNew()
try
{
    [string] $optimizationModelFolderPath = join-path $(convert-path "FL:\DataByRound\Round$upcomingRound\OptimisationModels") "$modelSubPath"
    if (-not (test-path $optimizationModelFolderPath))
    {
        new-item $optimizationModelFolderPath -type Directory | out-null
        Write-Host "Created folder $optimizationModelFolderPath" -foregroundColor Green
        Write-Host
    }
    
    & FL:\PowershellScripts\Generate-PredictedFinalistsForOptimization.ps1 `
        -upcomingRound $upcomingRound `
        -optimizationModelSubPath $modelSubPath
    
    & FL:\PowershellScripts\Generate-PlayerModelForOptimization.ps1 `
        -season $season `
        -upcomingRound $upcomingRound `
        -optimizationModelSubPath $modelSubPath
    
    Start-Process 'FL:\CSharp\Optimization\bin\debug\Optimization.exe' -argumentList @(
        $modelSubPath
        $upcomingRound
        $endRound
        $budget
        "`"$transferAllocation`""
    ) -Wait -NoNewWindow
    
    # & FL:\CSharp\Optimization\bin\debug\Optimization.exe `
    #     $modelSubPath $startRound $endRound $budget `
    #     $transferAllocation $targetScorePerRound # $filterByCandidateType $breakAtFirst
}
finally
{
    $swatch.Stop()
    $duration = $swatch.Elapsed
    . FL:\PowershellScripts\Parse-OptimizationOutputs.ps1 `
        -upcomingRound $upcomingRound -optimizationModelSubPath $modelSubPath -durationOfRun $duration
}

# Test and debug:  . C:\FantasyLeague\PowershellScripts\Invoke-Optimization.ps1 Test 1 5 200.0 '5,7'

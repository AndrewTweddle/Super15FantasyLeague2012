param (
    [int] $upcomingRound = $( read-host 'Round' ),
    [string] $model = 'NegBin'
)

$forecastsFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$model\Forecasts_$model.csv"
$forecasts = import-csv $forecastsFilePath `
    | ? { $_.FixtureType -eq 'H' } `
    | select-object `
        @{ n='Round'; e={[int]::Parse($_.Round) }},
        TeamCode,
        OpponentsTeamCode,
        @{ n='HomeScore'; e={[int]([double]::Parse($_.PredictedTotalPointsScored))}},
        @{ n='AwayScore'; e={[int]([double]::Parse($_.PredictedTotalPointsConceded))}},
        @{ n='Difference'; e={ [double]::Parse($_.PredictedTotalPointsScored) - [double]::Parse($_.PredictedTotalPointsConceded)}},
        @{ n='PredictedTotalTriesScored'; e={ [double]::Parse($_.PredictedTotalTriesScored ) }},
        @{ n='PredictedTotalTriesConceded'; e={ [double]::Parse($_.PredictedTotalTriesConceded ) }},
        @{ n='PredictedPenaltiesScored'; e={ [double]::Parse($_.PredictedPenaltiesScored ) }},
        @{ n='PredictedPenaltiesConceded'; e={ [double]::Parse($_.PredictedPenaltiesConceded ) }} `
    | ? { $_.Round -eq $upcomingRound }

Write-Host "Predictions for round $upcomingRound :"
Write-Host "========================="
Write-Host
    
$forecasts | % {
    Write-Host "$($_.TeamCode) $($_.HomeScore) - $($_.AwayScore) $($_.OpponentsTeamCode)     ... The difference (H-A) is $([Math]::Round($_.Difference))   [$([Math]::Round($_.Difference,1))]"
    Write-Host
    Write-Host "    Tries    : $($_.PredictedTotalTriesScored.ToString('0.00')) - $($_.PredictedTotalTriesConceded.ToString('0.00'))"
    Write-Host "    Penalties: $($_.PredictedPenaltiesScored.ToString('0.00')) - $($_.PredictedPenaltiesConceded.ToString('0.00'))"
    Write-Host
    Write-Host
}

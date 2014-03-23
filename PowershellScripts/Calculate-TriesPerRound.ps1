$m = import-csv "C:\FantasyLeague\DataByRound\Round8\TeamResults\SeasonToDateMatchResultsWithComponentsOfScore.csv" | `
    select-object @{n='Round';e={[int]::Parse($_.Round)}},@{n='TotalTriesScored';e={[int]::Parse($_.TotalTriesScored)}}
$m | group-object Round | % { 
    Write-Host "Round $($_.Name)"; 
    $totalTries = ($_.Group | measure-object TotalTriesScored -sum).Sum; 
    Write-Host "    $totalTries tries"; 
    Write-Host "    $($totalTries/$_.Count*2) per match ($($_.Count / 2) matches)" 
}

param (
    $teamFixturesFile = 'fl:\MasterData\2012\Fixtures\TeamFixtures.csv'
)

$teamFixtures = import-csv $teamFixturesFile | select-object @{n='Round';e={[int]::Parse($_.Round)}},FixtureType
$byeCounts = $teamFixtures | ? { $_.Round -le 18 -and $_.FixtureType -eq 'B' } | group-object Round | select-object @{n='Round';e={$_.Name}},Count

$byesForAllRounds = 1..18 | % {
    $round = $_
    $byeCount = $byeCounts | ? { $_.Round -eq $round }
    if ($byeCount)
    {
        $byeCount
    }
    else
    {
        $byeCount = new-object PSObject
        $byeCount | Add-Member NoteProperty 'Round' $round
        $byeCount | Add-Member NoteProperty 'Count' 0
    }
}

$byesForAllRounds

$byesForAllRounds | % { $_.Count } | out-clipboard

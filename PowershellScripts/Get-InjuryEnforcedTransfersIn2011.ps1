param (
    [string] $teamSelectionsFilePath = 'FL:\Simulated2011Season\TeamSelections.Actual.csv',
    [string] $playerStatsFolderPath = 'FL:\PrevSeasonAnalysis\PlayerStats\ByPlayer',
    [string] $teamFixturesFilePath = 'FL:\MasterData\2011\Fixtures\TeamFixtures.csv',
    [string] $knownInjuriesFolderPath = 'FLArchive:\2011\Injuries',
    [string] $selectedPlayerInjuriesFilePath = 'FL:\PrevSeasonAnalysis\Injuries\SelectedPlayerInjuriesInFollowingRound.csv',
    [string] $injuryCountsByRoundFilePath = 'FL:\PrevSeasonAnalysis\Injuries\SelectedPlayerInjuryCountsInFollowingRoundByRound.csv',
    [string] $knownInjuryCountsByRoundFilePath = 'FL:\PrevSeasonAnalysis\Injuries\SelectedPlayerKnownInjuryCountsInFollowingRoundByRound.csv'
)

$teamFixtures = import-csv $teamFixturesFilePath
$teamSelections = import-csv $teamSelectionsFilePath

$lastRound = 0

$injuries = $teamSelections | % {
    $selection = $_
    $playerName = $selection.PlayerName
    $upcomingRound = [int]::Parse( $selection.UpcomingRound )
    
    if ($upcomingRound -lt 21)
    {
        if ($lastRound -ne $upcomingRound)
        {
            $lastRound = $upcomingRound
            $nextRound = $lastRound + 1
            Write-Host "Checking for injuries to selected players after round $upcomingRound" -foregroundColor Green
            
            $knownInjuriesInNextRound = Get-Content "$knownInjuriesFolderPath\Injuries_Round$($nextRound).txt" | ? { 
                $_ -and (-not $_.StartsWith('#'))
            } | % {
                ($_ -split ':')[0].Trim()
            }
        }
        Write-Host "    Checking if $playerName (chosen in round $upcomingRound) was injured/unavailable in following round" -foregroundColor Cyan
        
        $playerStatsFile = "$playerStatsFolderPath\$($playerName).csv"
        $playerStats = import-csv $playerStatsFile
        $playerStatsForNextRound = $playerStats | ? { $_.RoundsCompleted -eq $nextRound }
        if (-not $playerStatsForNextRound)
        {
            Write-Error "No stats for player $playerName for round $nextRound"
        }
        else
        {
            $playedNextRound = [int]::Parse($playerStatsForNextRound.FullAppearance) + [int]::Parse($playerStatsForNextRound.PartAppearance)
            if (-not $playedNextRound)
            {
                # Did team have a bye?
                $teamCode = $playerStatsForNextRound.Team
                $fixture = $teamFixtures | ? { $_.Round -eq $nextRound -and $_.TeamCode -eq $teamCode }
                if ($fixture.FixtureType -ne 'B')
                {
                    if ($nextRound -eq 2 -and ($teamCode -eq 'HUR' -or $teamCode -eq 'CRU'))
                    {
                        Write-Host "        Player $playerName in cancelled match between Crusaders and Hurricanes" -foregroundColor Magenta
                    }
                    else
                    {
                        if ($knownInjuriesInNextRound | ? { $_ -eq $playerName })
                        {
                            $isKnown = $true
                        }
                        else
                        {
                            $isKnown = $false
                        }
                    
                        $playerInjury = new-object PSObject
                        $playerInjury | Add-Member NoteProperty 'Round' $nextRound
                        $playerInjury | Add-Member NoteProperty 'PlayerName' $playerName
                        $playerInjury | Add-Member NoteProperty 'IsKnown' $isKnown
                        $playerInjury
                        Write-Host "        Player $playerName was injured in round $nextRound" -foregroundColor Yellow
                    }
                }
            }
        }
    }
}

$injuries | export-csv $selectedPlayerInjuriesFilePath -noTypeInformation
$injuries

# Group injury counts by round for players selected the previous round:
$injuryCounts = $injuries | group-object Round | select-object @{n='Round';e={$_.Name}},Count
$injuryCounts | export-csv $injuryCountsByRoundFilePath -noTypeInformation
$injuryCounts | % {
    $round = $_.Round
    $count = $_.Count
    Write-Host "Round $round : $count" -foregroundColor Yellow
}
Write-Host

# We are really interested in the injury counts we knew about for players we had selected the previous round:
Write-Host 'Known injury counts for selected players by upcoming round:'

$knownInjuryCounts = $injuries | ? { $_.IsKnown } | group-object Round | select-object @{n='Round';e={$_.Name}},Count
$knownInjuryCounts | export-csv $knownInjuryCountsByRoundFilePath -noTypeInformation
$knownInjuryCounts | % {
    $round = $_.Round
    $count = $_.Count
    Write-Host "Round $round : $count" -foregroundColor Cyan
}

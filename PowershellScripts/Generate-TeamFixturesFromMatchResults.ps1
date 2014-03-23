param (
    [string] $matchResultsFolder = 'fl:\PrevSeasonAnalysis\MatchResults',
    [string] $season = '2011'
)

[string] $inputMatchesFile = "$matchResultsFolder\Super_rugby_$($season).csv"
[string] $outputFolder = "fl:\MasterData\$season\Fixtures"

$teams = import-csv "fl:\MasterData\$season\teams.csv"

$fixtures = import-csv $inputMatchesFile | select-object `
    @{n='Round'; e={[int]::Parse($_.Round)}},
    @{n='FixtureDate';e={$_.DatePlayed}},
    @{n='HomeTeamCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
    @{n='HomeTeamName';e={$_.HomeTeam}},
    @{n='AwayTeamCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
    @{n='AwayTeamName';e={$_.AwayTeam}},
    Referee

$fixtures | export-csv "fl:\MasterData\$season\Fixtures\Fixtures.csv" -noTypeInformation

$byes = $fixtures | group-object Round | % {
    $grouping = $_
    $round = $grouping.Name
    $teamsWithByes = $teams | ? { 
        $teamCode = $_.TeamCode
        $fixtureForTeam = $grouping.Group | ? { 
            $_.HomeTeamCode -eq $teamCode -or $_.AwayTeamCode -eq $teamCode 
        }
        if ($fixtureForTeam) { $false } else { $true }
    }
    if ($teamsWithByes)
    {
        $teamsWithByes | % {
            $teamWithBye = $_
            $bye = new-object PSObject
            $bye | Add-Member NoteProperty 'Round' $round
            $bye | Add-Member NoteProperty 'TeamCode' $teamWithBye.TeamCode
            $bye | Add-Member NoteProperty 'TeamName' $teamWithBye.TeamName
            $bye | Add-Member NoteProperty 'FixtureType' 'B'
            $bye | Add-Member NoteProperty 'OpponentsTeamCode' ''
            $bye | Add-Member NoteProperty 'OpponentsTeamName' ''
            $bye | Add-Member NoteProperty 'Referee' ''
            $bye | Add-Member NoteProperty 'FixtureDate' ''
            $bye
        }
    }
}
    
$fixturesByTeam = @(
    $fixtures | % {
        $fixture = $_
        
        # Add byes for previous round:
        if ($fixture.Round -ne $lastRound)
        {
            $byes | ? { $_.Round -eq $lastRound }
            $lastRound = $fixture.Round
        }
        
        $homeFixture = $fixture | select-object `
            Round,
            @{n='TeamCode'; e={$_.HomeTeamCode}},
            @{n='TeamName'; e={$_.HomeTeamName}},
            @{n='FixtureType'; e={'H'}},
            @{n='OpponentsTeamCode'; e={$_.AwayTeamCode}},
            @{n='OpponentsTeamName'; e={$_.AwayTeamName}},
            Referee,
            FixtureDate
        
        $awayFixture = $fixture | select-object `
            Round,
            @{n='TeamCode'; e={$_.AwayTeamCode}}, `
            @{n='TeamName'; e={$_.AwayTeamName}}, `
            @{n='FixtureType'; e={'A'}},
            @{n='OpponentsTeamCode'; e={$_.HomeTeamCode}},
            @{n='OpponentsTeamName'; e={$_.HomeTeamName}},
            Referee,
            FixtureDate
        
        $homeFixture
        $awayFixture
    }
) + @( $byes | ? { $_.Round -eq $lastRound } )

$fixturesByTeam | export-csv "fl:\MasterData\$season\Fixtures\TeamFixtures.csv" -noTypeInformation

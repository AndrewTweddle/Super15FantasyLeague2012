param (
    [string] $importFilePath = 'fl:\Spreadsheets\Fixtures_2012.csv',
    [string] $exportFilePath = 'fl:\MasterData\2012\Fixtures\Fixtures.csv',
    [string] $teamFixturesFilePath = 'fl:\MasterData\2012\Fixtures\TeamFixtures.csv'
)

# Output format:
# Round	FixtureDate	HomeTeamCode	HomeTeamName	AwayTeamCode	AwayTeamName	Referee Venue (optional)
#

# TODO: See if referees chosen for matches yet

$teams = import-csv 'FL:\MasterData\Global\Teams.csv'

$nameToCodeMapping = @{
    'W Force' = 'WFR'
}

$teams | % {
    $team = $_
    $nameToCodeMapping[$team.TeamName] = $team.TeamCode
}

$teamCodeToTeamNameMapping = @{}
$teams | % {
    $team = $_
    $teamCodeToTeamNameMapping[$team.TeamCode] = $team.TeamName
}


$imports = import-csv $importFilePath
$fixtures = $imports | % { 
    $import = $_
    Write-Host $import -foregroundColor Green
    if ($import.Date -match '^BYES?\:\s+(?<TeamName>(?:(?!,|$).)+)(?:,(?<TeamName>(?:(?!,|$).)+))*$')
    {
        # Don't bother to store this
        $matches.TeamName | % { Write-Host "Bye for team $_ " -foregroundColor Cyan }
    }
    else
    {
        $round = [int]::Parse($import.Round)
        [DateTime] $fixtureDate = [DateTime] "$($import.Date) 2012"
        $fixture = new-object PSObject
        $fixture | Add-Member NoteProperty 'Round' $round
        $fixture | Add-Member NoteProperty 'FixtureDate' $fixtureDate
        
        if ($round -le 18)
        {
            $homeTeamCode = $nameToCodeMapping[$import.HomeTeamName.Trim()]
            $homeTeamName = $teamCodeToTeamNameMapping[$homeTeamCode]
            $awayTeamCode = $nameToCodeMapping[$import.AwayTeamName.Trim()]
            $awayTeamName = $teamCodeToTeamNameMapping[$awayTeamCode]
        }
        else
        {
            $homeTeamCode = ''
            $homeTeamName = ''
            $awayTeamCode = ''
            $awayTeamName = ''
        }
        $fixture | Add-Member NoteProperty 'HomeTeamCode' $homeTeamCode
        $fixture | Add-Member NoteProperty 'HomeTeamName' $homeTeamName
        $fixture | Add-Member NoteProperty 'AwayTeamCode' $awayTeamCode
        $fixture | Add-Member NoteProperty 'AwayTeamName' $awayTeamName
        $fixture | Add-Member NoteProperty 'Referee' ''
        $fixture | Add-Member NoteProperty 'Venue' $import.Venue
        $fixture
    }
}

$fixtures | export-csv $exportFilePath -noTypeInformation


# Calculate fixtures by team, including byes:
$byes = $fixtures | ? { $_.HomeTeamCode } | group-object Round | % {
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

$lastRound = 0

$fixturesByTeam = @(
    $fixtures | ? { $_.HomeTeamCode } | % {
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

$fixturesByTeam | export-csv $teamFixturesFilePath -noTypeInformation

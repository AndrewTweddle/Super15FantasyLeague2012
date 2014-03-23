param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $forecastingModel = 'NegBin',
    [switch] $calculatePlayOffFixtures = $false
)

$allFixturesFileName = "FL:\MasterData\$season\Fixtures\TeamFixtures.csv"
$futureFixturesFileName = "FL:\DataByRound\Round$upcomingRound\Inputs\FutureTeamFixtures.csv"

$allFixtures = import-csv $allFixturesFileName
$futureFixtures = $allFixtures | ? { [int]::Parse( $_.Round ) -ge $upcomingRound }

if ($calculatePlayOffFixtures)
{
    [string] $predictedFinalistsFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$forecastingModel\PredictedFinalists_$($forecastingModel).csv"
    $finalists = import-csv $predictedFinalistsFilePath | `
        select-object @{
            n='Position'
            e={ [int]::Parse( $_.Position ) }
        }, `
        AdjustedTeamCode, `
        TeamCode

    $teams = import-csv 'FL:\MasterData\Global\Teams.csv'

    $teamLookup = @{}
    1..6 | % {
        $position = $_
        $teamCode = ( $finalists | ? { $_.Position -eq $position } ).AdjustedTeamCode
        $team = $teams | ? { $_.TeamCode -eq $teamCode }
        $teamLookup.$position = $team
    }
    
    # Estimate round 19 fixtures:
    $quarter1Date = [DateTime] '2012/07/20'
    $quarter2Date = [DateTime] '2012/07/21'
    # Team 3 versus team 6
    # Team 4 versus team 5
    
    $quarter1_Home = new-object PSObject -property @{
        Round = 19
        TeamCode = $teamLookup[3].TeamCode
        TeamName = $teamLookup[3].TeamName
        FixtureType = 'H'
        OpponentsTeamCode = $teamLookup[6].TeamCode
        OpponentsTeamName = $teamLookup[6].TeamName
        Referee = ''
        FixtureDate = $quarterDate1
    }
    $quarter1_Away = new-object PSObject -property @{
        Round = 19
        TeamCode = $teamLookup[6].TeamCode
        TeamName = $teamLookup[6].TeamName
        FixtureType = 'A'
        OpponentsTeamCode = $teamLookup[3].TeamCode
        OpponentsTeamName = $teamLookup[3].TeamName
        Referee = ''
        FixtureDate = $quarterDate1
    }
    $quarter2_Home = new-object PSObject -property @{
        Round = 19
        TeamCode = $teamLookup[4].TeamCode
        TeamName = $teamLookup[4].TeamName
        FixtureType = 'H'
        OpponentsTeamCode = $teamLookup[5].TeamCode
        OpponentsTeamName = $teamLookup[5].TeamName
        Referee = ''
        FixtureDate = $quarterDate2
    }
    $quarter2_Away = new-object PSObject -property @{
        Round = 19
        TeamCode = $teamLookup[5].TeamCode
        TeamName = $teamLookup[5].TeamName
        FixtureType = 'A'
        OpponentsTeamCode = $teamLookup[4].TeamCode
        OpponentsTeamName = $teamLookup[4].TeamName
        Referee = ''
        FixtureDate = $quarterDate2
    }
    if ($futureFixtures)
    {
        $futureFixtures = $futureFixtures + @( $quarter1_Home, $quarter1_Away, $quarter2_Home, $quarter2_Away )
    }
    else
    {
        $futureFixtures = @( $quarter1_Home, $quarter1_Away, $quarter2_Home, $quarter2_Away ) | `
            select-object Round,TeamCode,TeamName,FixtureType,OpponentsTeamCode,OpponentsTeamName,Referee,FixtureDate
    }
    
    # Estimate round 20 fixtures:
    $semi1Date = [DateTime] '2012/07/27'
    $semi2Date = [DateTime] '2012/07/28'
    
    # Team 1 versus team 4:
    $semi1_Home = new-object PSObject -property @{
        Round = 20
        TeamCode = $teamLookup[1].TeamCode
        TeamName = $teamLookup[1].TeamName
        FixtureType = 'H'
        OpponentsTeamCode = $teamLookup[4].TeamCode
        OpponentsTeamName = $teamLookup[4].TeamName
        Referee = ''
        FixtureDate = $semiDate1
    }
    $semi1_Away = new-object PSObject -property @{
        Round = 20
        TeamCode = $teamLookup[4].TeamCode
        TeamName = $teamLookup[4].TeamName
        FixtureType = 'A'
        OpponentsTeamCode = $teamLookup[1].TeamCode
        OpponentsTeamName = $teamLookup[1].TeamName
        Referee = ''
        FixtureDate = $semiDate1
    }
    
    # Team 2 versus team 3:
    $semi2_Home = new-object PSObject -property @{
        Round = 20
        TeamCode = $teamLookup[2].TeamCode
        TeamName = $teamLookup[2].TeamName
        FixtureType = 'H'
        OpponentsTeamCode = $teamLookup[3].TeamCode
        OpponentsTeamName = $teamLookup[3].TeamName
        Referee = ''
        FixtureDate = $semiDate2
    }
    $semi2_Away = new-object PSObject -property @{
        Round = 20
        TeamCode = $teamLookup[3].TeamCode
        TeamName = $teamLookup[3].TeamName
        FixtureType = 'A'
        OpponentsTeamCode = $teamLookup[2].TeamCode
        OpponentsTeamName = $teamLookup[2].TeamName
        Referee = ''
        FixtureDate = $semiDate2
    }
    
    $futureFixtures = $futureFixtures + @( $semi1_Home, $semi1_Away, $semi2_Home, $semi2_Away )
    
    
    # Estimate round 21 fixtures:
    $finalDate = [DateTime] '2012/08/04'

    # Team 1 versus team 2
    $final_Home = new-object PSObject -property @{
        Round = 21
        TeamCode = $teamLookup[1].TeamCode
        TeamName = $teamLookup[1].TeamName
        FixtureType = 'H'
        OpponentsTeamCode = $teamLookup[2].TeamCode
        OpponentsTeamName = $teamLookup[2].TeamName
        Referee = ''
        FixtureDate = $finalDate
    }
    $final_Away = new-object PSObject -property @{
        Round = 21
        TeamCode = $teamLookup[2].TeamCode
        TeamName = $teamLookup[2].TeamName
        FixtureType = 'A'
        OpponentsTeamCode = $teamLookup[1].TeamCode
        OpponentsTeamName = $teamLookup[1].TeamName
        Referee = ''
        FixtureDate = $finalDate
    }
    
    $futureFixtures = $futureFixtures + @( $final_Home, $final_Away )
}

$futureFixtures | export-csv $futureFixturesFileName -noTypeInformation

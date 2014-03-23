param (
    [int] $season = $( read-host 'Season' ),
    [int] $roundCompleted = $( read-host 'Round completed'),
    [switch] $inferPenaltyTries = $true
    # TODO: Remove... [string] $playerStatsFolder = 'fl:\PrevSeasonAnalysis\PlayerStats',
    # TODO: Remove... [string] $matchResultsFolder = 'fl:\PrevSeasonAnalysis\MatchResults'
)

. FL:\PowershellScripts\Create-UtilityFunctions.ps1

# Input files:
[string] $inputMatchesFile = "FL:\DataByRound\Round$roundCompleted\TeamResults\SeasonToDateMatchResults.csv"
[string] $playerStatsFilePath = "FL:\DataByRound\Round$roundCompleted\PlayerStats\PlayerStatsToDate.csv"

# Output files:
[string] $outputMatchesFilePath = "FL:\DataByRound\Round$roundCompleted\TeamResults\SeasonToDateMatchResultsWithComponentsOfScore.csv"

# Load lookup data:
$teams = import-csv "fl:\MasterData\$season\Teams.csv"
$positionTypes = import-csv "fl:\MasterData\Global\PositionTypes.csv" | % { $_.PositionType }
$positions = import-csv "fl:\MasterData\Global\Positions.csv"

# Load input data:
$allPlayerStats = import-csv $playerStatsFilePath
$matchResults = import-csv $inputMatchesFile 
$currentRound = 0

$resultsByTeam = @{}

$allResults = $matchResults | % {
    $matchResult = $_
    if ($matchResult.Round -ne $currentRound)
    {
        $currentRound = $matchResult.Round
        Write-Host "Calculating results for round $currentRound" -foregroundColor Green
        $playerStatsForRoundFileName = "FL:\DataByRound\Round$currentRound\PlayerStats\PlayerStatsForRound.csv"
        $playerStatsForRound = import-csv $playerStatsForRoundFileName `
            | Select-Properties @{
                FullName = ''
                Position = ''
                FullAppearance = 'int'
                PartAppearance = 'int'
                Tries = 'int'
                Assists = 'int'
                Conversions = 'int'
                DropGoals = 'int'
                Penalties = 'int'
            }
    }
    Write-Host "    Calculating results for match between $($matchResult.HomeTeam) and $($matchResult.AwayTeam)" -foregroundColor Cyan
    
    $homeTeamResult = $matchResult | select-object Season,Round,DatePlayed, `
        @{n='TeamCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
        @{n='TeamName'; e={$_.HomeTeam}}, `
        @{n='RegionCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).RegionCode } }, `
        @{n='ConferenceCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).ConferenceCode } }, `
        @{n='OpponentsTeamCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
        @{n='OpponentsTeamName';e={$_.AwayTeam}}, `
        @{n='OpponentsRegionCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).RegionCode } }, `
        @{n='OpponentsConferenceCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).ConferenceCode } }, `
        @{n='FixtureType';e={'H'}}, `
        Referee, `
        @{n='TotalPointsScored'; e={[int]::Parse($_.HomeScore)}}
        # @{n='TotalPointsConceded';e={[int]::Parse($_.AwayScore)}}
    
    $awayTeamResult = $matchResult | select-object Season,Round,DatePlayed, `
        @{n='TeamCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
        @{n='TeamName'; e={$_.AwayTeam}}, `
        @{n='RegionCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).RegionCode } }, `
        @{n='ConferenceCode'; e={ $teamName = $_.AwayTeam; ($teams | ? { $_.TeamName -eq $teamName }).ConferenceCode } }, `
        @{n='OpponentsTeamCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).TeamCode } }, `
        @{n='OpponentsTeamName';e={$_.HomeTeam}}, `
        @{n='OpponentsRegionCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).RegionCode } }, `
        @{n='OpponentsConferenceCode'; e={ $teamName = $_.HomeTeam; ($teams | ? { $_.TeamName -eq $teamName }).ConferenceCode } }, `
        @{n='FixtureType';e={'A'}}, `
        Referee, `
        @{n='TotalPointsScored'; e={[int]::Parse($_.AwayScore)}}
        # @{n='TotalPointsConceded';e={[int]::Parse($_.HomeScore)}}
    
    $pairOfResults = @( $homeTeamResult, $awayTeamResult )
    $pairOfResults | % {
        $teamResult = $_
        $teamCode = $teamResult.TeamCode
        $fixtureType = $teamResult.FixtureType
        Write-Host "        Calculating $fixtureType team results scored" -foregroundColor Yellow
        
        $playerStatsForPlayersInTeam = $positionTypes | % {
            $positionType = $_
            Write-Host "            Calculating $fixtureType team results scored for position type $positionType" -foregroundColor Magenta
            
            $playersInTeamAndPositionFile = "fl:\MasterData\$season\Players\$($teamCode)_$($positionType)_Players.csv"
            $playersInTeamAndPosition = import-csv $playersInTeamAndPositionFile
            
            $playerStatsForPositionType = $playersInTeamAndPosition | % {
                $playerName = $_.PlayerName
                $playerStatsForRound | ? { $_.FullName -eq $playerName }
            }
            $playerStatsForPositionType
            
            # Additionally calculate the stats for each position type:
            [int] $triesScored = ($playerStatsForPositionType | measure-object Tries -sum).Sum
            [int] $assistsScored = ($playerStatsForPositionType | measure-object Assists -sum).Sum
            $teamResult | Add-Member NoteProperty "$($positionType)TriesScored" $triesScored
            $teamResult | Add-Member NoteProperty "$($positionType)AssistsScored" $assistsScored
            
            # Calculate the stats for each position:
            $positions | ? { $_.PositionType -eq $positionType } | % {
                $positionCode = $_.PositionCode
                Write-Host "                Calculating tries and assists scored for position $positionCode" -foregroundColor Gray
                
                $playerStatsForPosition = $playerStatsForPositionType | ? { $_.Position -eq $positionCode }
                [int] $positionTriesScored = ($playerStatsForPosition | measure-object Tries -sum).Sum
                [int] $positionAssistsScored = ($playerStatsForPosition | measure-object Assists -sum).Sum
                $teamResult | Add-Member NoteProperty "$($positionCode)TriesScored" $positionTriesScored
                $teamResult | Add-Member NoteProperty "$($positionCode)AssistsScored" $positionAssistsScored
                
                if ($positionTriesScored -ne 0)
                {
                    Write-Host "                    Tries scored: $positionTriesScored" -foregroundColor White
                }
                if ($positionAssistsScored -ne 0)
                {
                    Write-Host "                    Assists scored: $positionAssistsScored" -foregroundColor White
                }
            }
        }
        
        [int] $totalTriesScored = ($playerStatsForPlayersInTeam | measure-object Tries -sum).Sum
        [int] $totalAssistsScored = ($playerStatsForPlayersInTeam | measure-object Assists -sum).Sum
        [int] $conversionsScored = ($playerStatsForPlayersInTeam | measure-object Conversions -sum).Sum
        [int] $penaltiesScored = ($playerStatsForPlayersInTeam | measure-object Penalties -sum).Sum
        [int] $dropGoalsScored = ($playerStatsForPlayersInTeam | measure-object DropGoals -sum).Sum
        
        $totalPointsScored = $teamResult.TotalPointsScored
        [int] $penaltyTriesScored = 0
        [int] $unknownPointsScored = $totalPointsScored - 5 * $totalTriesScored - 2 * $conversionsScored - 3 * $penaltiesScored - 3 * $dropGoalsScored
        if ($inferPenaltyTries -and ($unknownPointsScored % 5 -eq 0))
        {
            $penaltyTriesScored = $unknownPointsScored / 5
            $unknownPointsScored = 0
        }
        
        $teamResult | Add-Member NoteProperty 'TotalTriesScored' $totalTriesScored
        $teamResult | Add-Member NoteProperty 'TotalAssistsScored' $totalAssistsScored
        $teamResult | Add-Member NoteProperty 'ConversionsScored' $conversionsScored
        $teamResult | Add-Member NoteProperty 'PenaltiesScored' $penaltiesScored
        $teamResult | Add-Member NoteProperty 'DropGoalsScored' $dropGoalsScored
        $teamResult | Add-Member NoteProperty 'PenaltyTriesScored' $penaltyTriesScored
        $teamResult | Add-Member NoteProperty 'UnknownPointsScored' $unknownPointsScored
        
        # $playerStatsForMatchFileName = "$playerStatsFolder\ByTeamAndRound\$($teamCode)_Round$($currentRound).csv"
        # $playerStatsForPlayersInTeam | export-csv $playerStatsForMatchFileName -noTypeInformation
    }
    0..1 | % {
        Write-Host "        Calculating team $_ results conceded" -foregroundColor Yellow
        $teamResult = $pairOfResults[$_]
        $otherTeamResult = $pairOfResults[1-$_]
        $teamResult | Add-Member NoteProperty 'TotalPointsConceded' $otherTeamResult.TotalPointsScored
        $positionTypes | % {
            $positionType = $_
            Write-Host "            Calculating events conceded for position type $positionType" -foregroundColor Magenta
            
            $triesConceded = $otherTeamResult."$($positionType)TriesScored"
            $assistsConceded = $otherTeamResult."$($positionType)AssistsScored"
            $teamResult | Add-Member NoteProperty "$($positionType)TriesConceded" $triesConceded
            $teamResult | Add-Member NoteProperty "$($positionType)AssistsConceded" $assistsConceded
            
            # Calculate the stats for each position:
            $positions | ? { $_.PositionType -eq $positionType } | % {
                $positionCode = $_.PositionCode
                Write-Host "                Calculating tries and assists conceded to position $positionCode" -foregroundColor Gray
                
                [int] $positionTriesConceded = $otherTeamResult."$($positionCode)TriesScored"
                [int] $positionAssistsConceded = $otherTeamResult."$($positionCode)AssistsScored"
                $teamResult | Add-Member NoteProperty "$($positionCode)TriesConceded" $positionTriesConceded
                $teamResult | Add-Member NoteProperty "$($positionCode)AssistsConceded" $positionAssistsConceded
                
                if ($positionTriesConceded -ne 0)
                {
                    Write-Host "                    Tries conceded: $positionTriesConceded" -foregroundColor White
                }
                if ($positionAssistsConceded -ne 0)
                {
                    Write-Host "                    Assists conceded: $positionAssistsConceded" -foregroundColor White
                }
            }
        }
        [int] $totalTriesConceded = $otherTeamResult.TotalTriesScored
        [int] $totalAssistsConceded = $otherTeamResult.TotalAssistsScored
        [int] $conversionsConceded = $otherTeamResult.ConversionsScored
        [int] $penaltiesConceded = $otherTeamResult.PenaltiesScored
        [int] $dropGoalsConceded = $otherTeamResult.DropGoalsScored
        [int] $penaltyTriesConceded = $otherTeamResult.PenaltyTriesScored
        [int] $unknownPointsConceded = $otherTeamResult.UnknownPointsScored
        $teamResult | Add-Member NoteProperty 'TotalTriesConceded' $totalTriesConceded
        $teamResult | Add-Member NoteProperty 'TotalAssistsConceded' $totalAssistsConceded
        $teamResult | Add-Member NoteProperty 'ConversionsConceded' $conversionsConceded
        $teamResult | Add-Member NoteProperty 'PenaltiesConceded' $penaltiesConceded
        $teamResult | Add-Member NoteProperty 'DropGoalsConceded' $dropGoalsConceded
        $teamResult | Add-Member NoteProperty 'PenaltyTriesConceded' $penaltyTriesConceded
        $teamResult | Add-Member NoteProperty 'UnknownPointsConceded' $unknownPointsConceded
    }
    
    $homeTeamResult
    $awayTeamResult
    
    # Add home team result to hash table by team name:
    $homeTeamCode = $homeTeamResult.TeamCode
    $awayTeamCode = $awayTeamResult.TeamCode
    
    $homeTeamResults = $resultsByTeam.$homeTeamCode
    if ($homeTeamResults)
    {
        $homeTeamResults = $homeTeamResults + @( $homeTeamResult )
    }
    else
    {
        $homeTeamResults = @( $homeTeamResult )
    }
    $resultsByTeam.$homeTeamCode = $homeTeamResults
    
    # Add home team result to hash table by team name:
    $awayTeamResults = $resultsByTeam.$awayTeamCode
    if ($awayTeamResults)
    {
        $awayTeamResults = $awayTeamResults + @( $awayTeamResult )
    }
    else
    {
        $awayTeamResults = @( $awayTeamResult )
    }
    $resultsByTeam.$awayTeamCode = $awayTeamResults
}

$allResults | export-csv $outputMatchesFilePath -noTypeInformation

# $resultsByTeam.Keys | % {
    # $teamCode = $_
    # $teamResults = $resultsByTeam.$teamCode
    # $teamFileName = "$matchResultsFolder\$season\ByTeam\$($teamCode).csv"
    # $teamResults | export-csv $teamFileName -noTypeInformation
# }

# NOTE: This is obsolete.
#       Calculating data per player is too inaccurate due to high variability of player scores and too little correlation to team score.
# 
param (
    [string] $allPlayerResultsFilePath = 'FL:\PrevSeasonAnalysis\PlayerStats\AllPlayerStats.csv',
    [string] $matchResultsFilePath = 'FL:\PrevSeasonAnalysis\MatchResults\2011\AllResultsByTeamAndRound.csv',
    [string] $playerStatsForEstimationModelFilePath = 'FL:\PrevSeasonAnalysis\PlayerStats\PlayerStatsForEstimationModel.csv',
    [int] $season = 2011
)

# =================
# Load master data:
# 
$positions = import-csv fl:\MasterData\Global\Positions.csv

$playersLookup = FL:\PowershellScripts\Get-PlayersLookupForSeason.ps1 $season

# ======================================================================================================
# Load match results as these contain most of the independent variables to use for the estimation model:
# 
$matchResults = import-csv $matchResultsFilePath

$groupedMatchResults = $matchResults | group-object Round,TeamCode

$matchResultsDictionary = @{}
$groupedMatchResults | % {
    $grouping = $_
    $matchResultsDictionary[$grouping.Name] = $grouping.Group[0]
}

# =================================
# Load and filter the player stats:
# 
$playerResults = import-csv $allPlayerResultsFilePath

# Only include player results from the round robin round, and only if the player actually played in the match:
$playerResults = $playerResults | ? {
    ( [int]::Parse( $_.RoundsCompleted ) -le 18 ) `
    -and 
    ( 
        ( [int]::Parse($_.FullAppearance) -eq 1 ) `
        -or 
        ( [int]::Parse($_.PartAppearance) -eq 1 )
    )
}

# ===============================================================
# Transform the player stats into the data useful for estimation:
$playerStatsForEstimation = $playerResults `
    | Select-Object `
        @{n='PlayerName'; e={$_.FullName}}, `
        @{n='PositionCode'; e={$_.Position}}, `
        @{n='PositionType'; e={ $positionCode = $_.Position; ($positions | ? { $_.PositionCode -eq $positionCode }).PositionType }}, `
        @{n='TeamCode'; e={$_.Team}}, `
        @{n='Round'; e={ [int]::Parse( $_.RoundsCompleted ) }}, `
        @{n='MatchResults'; e={ $matchResultsDictionary["$($_.RoundsCompleted), $($_.Team)"] }}, `
        Price, Tries, Assists, Conversions, Penalties, DropGoals, YellowCard, RedCard `
    | Select-Object `
        PlayerName, Round, PositionCode, TeamCode, `
        @{n='Rookie'; 
          e={ 
                if ($playersLookup) 
                {
                    $playersLookup[$_.PlayerName].Rookie
                }
                else
                {
                    'X'
                }
            }
        }, `
        Price, Tries, Assists, Conversions, Penalties, DropGoals, YellowCard, RedCard, `
        @{n='RegionCode'; e={ $_.MatchResults.RegionCode }}, `
        @{n='ConferenceCode'; e={ $_.MatchResults.ConferenceCode }}, `
        @{n='FixtureType'; e={ $_.MatchResults.FixtureType }}, `
        @{n='OpponentsTeamCode'; e={ $_.MatchResults.OpponentsTeamCode }}, `
        @{n='OpponentsRegionCode'; e={ $_.MatchResults.OpponentsRegionCode }}, `
        @{n='OpponentsConferenceCode'; e={ $_.MatchResults.OpponentsConferenceCode }}, `
        @{n='Referee'; e={ $_.MatchResults.Referee }}, `
        @{n='TeamTotalPointsScored'; e={ $_.MatchResults.TotalPointsScored }}, `
        @{n='TeamPositionTypeTriesScored'; e={ $_.MatchResults."$($_.PositionType)TriesScored" }}, `
        @{n='TeamPositionTypeAssistsScored'; e={ $_.MatchResults."$($_.PositionType)AssistsScored" }}, `
        @{n='TeamPositionTriesScored'; e={ $_.MatchResults."$($_.PositionCode)TriesScored" }}, `
        @{n='TeamPositionAssistsScored'; e={ $_.MatchResults."$($_.PositionCode)AssistsScored" }}, `
        @{n='TeamTotalTriesScored'; e={ $_.MatchResults.TotalTriesScored }}, `
        @{n='TeamTotalAssistsScored'; e={ $_.MatchResults.TotalAssistsScored }}, `
        @{n='TeamConversionsScored'; e={ $_.MatchResults.ConversionsScored }}, `
        @{n='TeamPenaltiesScored'; e={ $_.MatchResults.PenaltiesScored }}, `
        @{n='TeamDropGoalsScored'; e={ $_.MatchResults.DropGoalsScored }}, `
        @{n='TeamPenaltyTriesScored'; e={ $_.MatchResults.PenaltyTriesScored }}
#        @{n=''; e={ $_.MatchResults. }}, `
#        @{n=''; e={}}, `

$playerStatsForEstimation | export-csv $playerStatsForEstimationModelFilePath -noTypeInformation
$playerStatsForEstimation

param
(
    [string] $allPlayerStatsFilePath = 'C:\FantasyLeague\PrevSeasonAnalysis\PlayerStats\AllPlayerStats.csv',
    [string] $playersWithPointsWhenTheyDidNotPlayFilePath = 'C:\FantasyLeague\PrevSeasonAnalysis\PlayerStats\DataQuality\PlayersWithPointsWhenTheyDidNotPlay.csv',
    [string] $playersWithNegativePointsInARoundFilePath = 'C:\FantasyLeague\PrevSeasonAnalysis\PlayerStats\DataQuality\PlayersWithNegativePointsInARound.csv'
)

. FL:\PowershellScripts\Create-UtilityFunctions.ps1

$allPlayerStats = import-csv $allPlayerStatsFilePath | select-properties @{
    RoundsCompleted = 'int'
    FullName = ''
    PointsAsNonKicker = 'int'
    KickingPoints = 'int'
    PointsAsKicker = 'int'
    FullAppearance = 'int'
    PartAppearance = 'int'
    Tries = 'int'
    Assists = 'int'
    Conversions = 'int'
    Penalties = 'int'
    DropGoals = 'int'
    HomeWin = 'int'
    HomeDraw = 'int'
    AwayWin = 'int'
    AwayDraw = 'int'
    YellowCard = 'int'
    RedCard = 'int'
} | Select-Object "FullName","RoundsCompleted","FullAppearance","PartAppearance","PointsAsNonKicker","KickingPoints","PointsAsKicker",`
        "Tries","Assists","Penalties","Conversions","DropGoals","YellowCard","RedCard","HomeWin","HomeDraw","AwayWin","AwayDraw"

$playersWithPointsWhenTheyDidNotPlay = $allPlayerStats | ? {
    ($_.FullAppearance -eq 0) -and ($_.PartAppearance -eq 0) `
    -and (
            ($_.PointsAsNonKicker -ne 0) -or ($_.KickingPoints -ne 0) -or ($_.PointsAsKicker -ne 0) `
            -or ($_.Tries -ne 0) -or ($_.Assists -ne 0) -or ($_.Conversions -ne 0) -or ($_.Penalties -ne 0) -or ($_.DropGoals -ne 0) `
            -or ($_.HomeWin -ne 0) -or ($_.HomeDraw -ne 0) -or ($_.AwayWin -ne 0) -or ($_.AwayDraw -ne 0) `
            -or ($_.YellowCard -ne 0) -or ($_.RedCard -ne 0)
         )
}

if ($playersWithPointsWhenTheyDidNotPlay)
{
    Write-Host 'Player with points when they did not play' -foregroundColor Red
    $playersWithPointsWhenTheyDidNotPlay
    Write-Host
}

$playersWithNegativePoints = $allPlayerStats | ? {
    ($_.PointsAsNonKicker -lt 0) -or ($_.KickingPoints -lt 0) -or ($_.PointsAsKicker -lt 0) `
    -or ($_.Tries -lt 0) -or ($_.Assists -lt 0) -or ($_.Conversions -lt 0) -or ($_.Penalties -lt 0) -or ($_.DropGoals -lt 0) `
    -or ($_.HomeWin -lt 0) -or ($_.HomeDraw -lt 0) -or ($_.AwayWin -lt 0) -or ($_.AwayDraw -lt 0) `
    -or ($_.YellowCard -lt 0) -or ($_.RedCard -lt 0)
}

if ($playersWithNegativePoints)
{
    Write-Host 'Player with negative points' -foregroundColor Red
    $playersWithNegativePoints
    Write-Host
}

$playersWithPointsWhenTheyDidNotPlay | Select-Object "FullName","RoundsCompleted","FullAppearance","PartAppearance","PointsAsNonKicker","KickingPoints","PointsAsKicker",`
        "Tries","Assists","Penalties","Conversions","DropGoals","YellowCard","RedCard","HomeWin","HomeDraw","AwayWin","AwayDraw" | export-csv $playersWithPointsWhenTheyDidNotPlayFilePath -noTypeInformation

$playersWithNegativePoints | Select-Object "FullName","RoundsCompleted","FullAppearance","PartAppearance","PointsAsNonKicker","KickingPoints","PointsAsKicker",`
        "Tries","Assists","Penalties","Conversions","DropGoals","YellowCard","RedCard","HomeWin","HomeDraw","AwayWin","AwayDraw" | export-csv $playersWithNegativePointsInARoundFilePath -noTypeInformation

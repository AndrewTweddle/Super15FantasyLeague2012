param (
    [int] $season = $( read-host 'Season' ),
    [int] $round = $( read-host 'Round just completed' )
)

# Input files:
[string] $downloadedPlayerStatsFilePath = "FL:\DataByRound\Round$round\PlayerStats\DownloadedPlayerStatsAfterRound.csv"
[string] $prevRoundDownloadedPlayerStatsFilePath = "FL:\DataByRound\Round$($round-1)\PlayerStats\DownloadedPlayerStatsAfterRound.csv"

# Output files:
[string] $playerStatsForRoundFilePath = "FL:\DataByRound\Round$round\PlayerStats\PlayerStatsForRound.csv"


# Lookup data:
$matchResultRules = import-csv "C:\FantasyLeague\MasterData\$season\Rules\MatchResultRules.csv" `
    | select-object FixtureType,ResultCode,@{
        n='Points'
        e={[int]::Parse($_.Points)}
    }
[int] $pointsForHomeWin = ( $matchResultRules | ? { $_.FixtureType -eq 'H' -and $_.ResultCode -eq 'W' } ).Points
[int] $pointsForAwayWin = ( $matchResultRules | ? { $_.FixtureType -eq 'A' -and $_.ResultCode -eq 'W' } ).Points
[int] $pointsForHomeDraw = ( $matchResultRules | ? { $_.FixtureType -eq 'H' -and $_.ResultCode -eq 'D' } ).Points
[int] $pointsForAwayDraw = ( $matchResultRules | ? { $_.FixtureType -eq 'A' -and $_.ResultCode -eq 'D' } ).Points

$positionRules = import-csv "FL:\MasterData\$season\Rules\PositionRules.csv" `
    | select-object PositionCode,@{
        n='PointsPerTry'
        e={[int]::Parse($_.PointsPerTry)}
    }

$kickerPoints = import-csv "FL:\MasterData\$season\Rules\KickerPoints.csv" `
    | select-object `
        @{ 
            n='EventCode'
            e={ $_.EventTypeCode }  # Because of inconsistent naming of column across rules files. TODO: Fix this in the source file
        },
        @{
            n='Points'
            e={ [int]::Parse($_.Points) }
        }
$pointsPerPenalty = ($kickerPoints | ? { $_.EventCode -eq 'P' }).Points
$pointsPerConversion = ($kickerPoints | ? { $_.EventCode -eq 'C' }).Points

$otherPoints = import-csv "FL:\MasterData\$season\Rules\OtherPoints.csv" `
    | select-object EventCode,@{
        n='Points'
        e={[int]::Parse($_.Points)}
    }
$pointsPerAssist = ($otherPoints | ? { $_.EventCode -eq 'A' }).Points
$pointsPerDropGoal = ($otherPoints | ? { $_.EventCode -eq 'D' }).Points
$pointsPerYellowCard = ($otherPoints | ? { $_.EventCode -eq 'Y' }).Points
$pointsPerRedCard = ($otherPoints | ? { $_.EventCode -eq 'R' }).Points

$appearancePoints = import-csv "FL:\MasterData\$season\Rules\AppearancePoints.csv" `
    | select-object AppearanceCode,@{n='Points';e={ [int]::Parse( $_.Points ) }}
$fullAppearancePoints = ($appearancePoints | ? { $_.AppearanceCode -eq 'F' }).Points
$partAppearancePoints = ($appearancePoints | ? { $_.AppearanceCode -eq 'P' }).Points

# Get previous round player stats to compare against:
if ($round -gt 1)
{
    $prevRoundDownloadedPlayerStats = import-csv $prevRoundDownloadedPlayerStatsFilePath
}
else
{
    $prevRoundDownloadedPlayerStats = $null
}

# Get cumulative player stats for the round just completed:
$downloadedPlayerStats = import-csv $downloadedPlayerStatsFilePath

$downloadedPlayerStatsGroupedByFullName = $downloadedPlayerStats | group-object FullName
$downloadedPlayerStatsGroupedByFullName | ? { 
    $_.Count -gt 1 
} | % {
    throw "Player $($_.Name) has duplicate records ($($_.Count))"
}

$allPlayerNames = $downloadedPlayerStats | % { $_.FullName }

$sourcePropertyNames = @(
    'TotalPoints', 'FullAppearances','PartAppearances','Tries', 'Assists', 'Conversions', 'Penalties', 
    'DropGoals', 'HomeWins', 'HomeDraws', 'AwayWins', 'AwayDraws', 'BonusPoints', 'YellowCards', 'RedCards'
)
$cumPropertyNames = @(
    'TotalPoints', 'FullAppearances','PartAppearances','TotalTries', 'TotalAssists', 'TotalConversions', 'TotalPenalties', 
    'TotalDropGoals', 'HomeWins', 'HomeDraws', 'AwayWins', 'AwayDraws', 'TotalBonusPoints', 'YellowCards', 'RedCards'
)
$diffPropertyNames = @(
    'PointsAsKicker', 'FullAppearance','PartAppearance','Tries', 'Assists', 'Conversions', 'Penalties',
    'DropGoals', 'HomeWin', 'HomeDraw', 'AwayWin', 'AwayDraw', 'BonusPoints', 'YellowCard', 'RedCard'
)
$propertyCount = $sourcePropertyNames.Length

$playerStatsForRound = $downloadedPlayerStats | % {
    $cumStatsForRound = $_
    $playerName = $cumStatsForRound.FullName
    Write-Host -foregroundColor Green "Generating stats for $playerName"
    $totalPointsAsNonKicker = 0
    $totalKickingPoints = 0
    
    # Determine the stats for the previous round (to take difference of cumulatives):
    $prevRoundCumStats = $null
    if ($round -gt 1)
    {
        $prevRoundCumStats = $prevRoundDownloadedPlayerStats | ? { $_.FullName -eq $playerName }
    }
    
    if ($cumStatsForRound)
    {
        if ( $cumStatsForRound | get-member | ? { $_.Name -eq 'Round' } )
        {
            if ($cumStatsForRound.Round -ne $round)
            {
                Write-Error "Player $playerName has round value $($cumStatsForRound.Round) that is wrong. It should be $round ."
            }
        }
        $statsForRound = $cumStatsForRound | select-object `
            @{n='Season';e={$season}},
            @{n='RoundsCompleted';e={$round}},@{n='IsInCompetition';e={1}},
            FullName,FirstName,Surname,Position,Team,Price
        
        if ($prevRoundCumStats -ne $null)
        {
            # Calculate kicking versus non-kicking points:
            $pointsAsKicker = [int]::Parse($cumStatsForRound.TotalPoints) - [int]::Parse($prevRoundCumStats.TotalPoints)
            $kickingPoints = 3 * ([int]::Parse($cumStatsForRound.Penalties) - [int]::Parse($prevRoundCumStats.Penalties)) `
                + 2 * ([int]::Parse($cumStatsForRound.Conversions) - [int]::Parse($prevRoundCumStats.Conversions))
            $pointsAsNonKicker = $pointsAsKicker - $kickingPoints
            $totalPointsAsNonKicker += $pointsAsNonKicker
            $totalKickingPoints += $kickingPoints
            $statsForRound | Add-Member -MemberType NoteProperty -name PointsAsNonKicker -value $pointsAsNonKicker
            $statsForRound | Add-Member -MemberType NoteProperty -name KickingPoints -value $kickingPoints
            
            # Add difference properties to stats:
            0..($propertyCount-1) | % {
                $sourcePropertyName = $sourcePropertyNames[$_]
                $newPropertyName = $diffPropertyNames[$_]
                $value = [int]::Parse($cumStatsForRound.$sourcePropertyName) - [int]::Parse($prevRoundCumStats.$sourcePropertyName)
                $statsForRound | Add-Member -MemberType NoteProperty -name $newPropertyName -value $value
            }
            
            # Add price change property:
            $value = [double]::Parse($cumStatsForRound.Price) - [double]::Parse($prevRoundCumStats.Price)
            $statsForRound | Add-Member -MemberType NoteProperty -name 'PriceChange' -value $value
        }
        else
        {
            # Calculate kicking versus non-kicking points:
            $pointsAsKicker = [int]::Parse($cumStatsForRound.TotalPoints)
            $kickingPoints = 3 * [int]::Parse($cumStatsForRound.Penalties) + 2 * [int]::Parse($cumStatsForRound.Conversions)
            $pointsAsNonKicker = $pointsAsKicker - $kickingPoints
            $totalPointsAsNonKicker += $pointsAsNonKicker
            $totalKickingPoints += $kickingPoints
            $statsForRound | Add-Member -MemberType NoteProperty -name PointsAsNonKicker -value $pointsAsNonKicker
            $statsForRound | Add-Member -MemberType NoteProperty -name KickingPoints -value $kickingPoints
            
            # Add difference properties to stats (same value as cumulative properties, since no previous values):
            0..($propertyCount-1) | % {
                $sourcePropertyName = $sourcePropertyNames[$_]
                $newPropertyName = $diffPropertyNames[$_]
                $value = [int]::Parse($cumStatsForRound.$sourcePropertyName)
                $statsForRound | Add-Member -MemberType NoteProperty -name $newPropertyName -value $value
            }
            
            # Add price change property:
            if ($round)
            {
                $value = [double]::Parse($cumStatsForRound.Price)
            }
            else
            {
                $value = 0.0
            }
            $statsForRound | Add-Member -MemberType NoteProperty -name 'PriceChange' -value $value
        }
        
        # Add cumulative properties to stats:
        $statsForRound | Add-Member -MemberType NoteProperty -name TotalPointsAsNonKicker -value $totalPointsAsNonKicker
        $statsForRound | Add-Member -MemberType NoteProperty -name TotalKickingPoints -value $totalKickingPoints
        
        0..($propertyCount-1) | % {
            $sourcePropertyName = $sourcePropertyNames[$_]
            $newPropertyName = $cumPropertyNames[$_]
            $value = [int]::Parse($cumStatsForRound.$sourcePropertyName)
            $statsForRound | Add-Member -MemberType NoteProperty -name $newPropertyName -value $value
        }
    }
    else
    {
        if ($prevRoundCumStats)
        {
            Write-Error "There are no stats for $playerName in round $round, yet there were stats in the previous round"
        }
        else
        {
            $statsForRound = $cumStatsForRound | select-object @{n='RoundsCompleted';e={$round}},@{n='IsInCompetition';e={0}},`
                FullName,FirstName,Surname,Position,Team,@{n='Price';e={200.0}}
            
            # Add diff stats:
            $statsForRound | Add-Member -MemberType NoteProperty -name PointsAsNonKicker -value 0
            $statsForRound | Add-Member -MemberType NoteProperty -name KickingPoints -value 0
            0..($propertyCount-1) | % {
                $newPropertyName = $diffPropertyNames[$_]
                $statsForRound | Add-Member -MemberType NoteProperty -name $newPropertyName -value 0
            }
            # Add cumulative stats:
            $statsForRound | Add-Member -MemberType NoteProperty -name TotalPointsAsNonKicker -value 0
            $statsForRound | Add-Member -MemberType NoteProperty -name TotalKickingPoints -value 0
            0..($propertyCount-1) | % {
                $newPropertyName = $cumPropertyNames[$_]
                $statsForRound | Add-Member -MemberType NoteProperty -name $newPropertyName -value 0
            }
        }
    }
    
    # ------------------------------
    # Calculate components of score:
    # 
    [double] $matchPoints = `
          $pointsForHomeWin * $statsForRound.HomeWin `
        + $pointsForAwayWin * $statsForRound.AwayWin `
        + $pointsForHomeDraw * $statsForRound.HomeDraw `
        + $pointsForAwayDraw * $statsForRound.AwayDraw
    
    [int] $pointsPerTry = ($positionRules | ? { $_.PositionCode -eq $statsForRound.Position }).PointsPerTry
    [int] $pointsForTries = $pointsPerTry * $statsForRound.Tries
    
    $statsForRound | Add-Member -MemberType NoteProperty -name 'MatchPoints' -value $matchPoints
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForTeamBonusPoints' -value $( 2 * $statsForRound.BonusPoints )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'AppearancePoints' -value $( `
          $fullAppearancePoints * $statsForRound.FullAppearance `
        + $partAppearancePoints * $statsForRound.PartAppearance `
    )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForTries' -value $pointsForTries
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForAssists' -value $( $pointsPerAssist * $statsForRound.Assists )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForConversions' -value $( $pointsPerConversion * $statsForRound.Conversions )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForPenalties' -value $( $pointsPerPenalty * $statsForRound.Penalties )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForDropGoals' -value $( $pointsPerDropGoal * $statsForRound.DropGoals )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForYellowCards' -value $( $pointsPerYellowCard * $statsForRound.YellowCard )
    $statsForRound | Add-Member -MemberType NoteProperty -name 'PointsForRedCards' -value $( $pointsPerRedCard * $statsForRound.RedCard )
    
    # Check that components of score add up to score:
    [int] $sumOfNonKickerComponents = `
          $statsForRound.MatchPoints `
        + $statsForRound.PointsForTeamBonusPoints `
        + $statsForRound.AppearancePoints `
        + $statsForRound.PointsForTries `
        + $statsForRound.PointsForAssists `
        + $statsForRound.PointsForDropGoals `
        + $statsForRound.PointsForYellowCards `
        + $statsForRound.PointsForRedCards
    [int] $sumOfKickerComponents = `
          $sumOfNonKickerComponents `
        + $statsForRound.PointsForConversions `
        + $statsForRound.PointsForPenalties
    
    if ($statsForRound.PointsAsNonKicker -ne $sumOfNonKickerComponents)
    {
        Write-Warning "Discrepancy: PointsAsNonKicker = $($statsForRound.PointsAsNonKicker), but sum of non-kicker components = $sumOfNonKickerComponents"
    }
    
    if ($statsForRound.PointsAsKicker -ne $sumOfKickerComponents)
    {
        Write-Warning "Discrepancy: PointsAsKicker = $($statsForRound.PointsAsKicker), but sum of kicker components = $sumOfKickerComponents"
    }
    
    # Return stats for round:
    $statsForRound
    
    # TODO: Write stats per player:
    # if ($playerStats)
    # {
        # $playerFileName = "$playerStatsFolderName\ByPlayer\$($playerName).csv"
        # $playerStats | export-csv $playerFileName -noTypeInformation
    # }
    # else
    # {
        # Write-Error "No stats for player $playerName"
    # }
}

if ($playerStatsForRound.Count -ne $allPlayerNames.Length)
{
    Write-Error 'Some player files were not created'
}
else
{
    Write-Host 'All player data successfully created!' -foregroundColor Green
}

$playerStatsForRound | sort-object FullName | export-csv $playerStatsForRoundFilePath -noTypeInformation

param (
    [string] $folderPath = 'flarchive:\2011\PlayerStats2011'
)
$fileNames = Get-ChildItem $folderPath -filter *.csv | % { $_.Name } | sort-object
# join-string $fileNames -separator ',' | out-clipboard

$csvFiles = $fileNames | ? { $_ -match 'PlayerStatsRound_(?<year>\d{4})_(?<month>\d{2})_(?<day>\d{2})\.csv' } | 
    select-object @{n='FileName';e={$matches[0] }},@{n='Year';e={$matches.year}},@{n='Month';e={$matches.Month}},@{n='Day';e={$matches.Day}}

$round0File = new-object PSObject
$round0File | add-member -MemberType NoteProperty -Name FileName -value 'PlayerStatsRound0.csv'
$round0File | add-member -MemberType NoteProperty -Name Year -value 2011
$round0File | add-member -MemberType NoteProperty -Name Month -value 2
$round0File | add-member -MemberType NoteProperty -Name Day -value 8

$csvFiles += $round0File
$csvFiles = $csvFiles | select-object FileName,Year,Month,Day,@{n='Date';e={new-object datetime -argumentList $_.Year,$_.Month,$_.Day}} | sort-object Date
# $csvFiles

$friday = [datetime]::Parse('2011-02-18')
$fridays = 0..21 | % { $friday.AddDays( 7 * $_ ) }
# $fridays

$csvFilesByRound =`
    $fridays | % { 
        $friday = $_
        $csvFiles | ? { $_.Date -lt $friday } | sort-object Date -descending | select-object -first 1 | % { $_.FileName }
    }
# $csvFilesByRound

$csvFileContentsByRound = @{}
$round = 0
$csvFilesByRound | % {
    $playerStats = import-csv "$folderPath\$_"
    $csvFileContentsByRound[$round] = $playerStats
    $round++
}
# $csvFileContentsByRound

$finalCsvFile = $csvFilesByRound[-1]
$finalCsvFilePath = "$folderPath\$finalCsvFile"
$finalCsvContents = import-csv $finalCsvFilePath

$allPlayerNames = $finalCsvContents | % { $_.FullName }

$sourcePropertyNames = @('TotalPoints', 'FullAppearances','PartAppearances','Tries', 'Assists', 'Conversions', 'Penalties', 'DropGoals', 'HomeWins', 'HomeDraws', 'AwayWins', 'AwayDraws', 'YellowCards', 'RedCards')
$cumPropertyNames = @('TotalPoints', 'FullAppearances','PartAppearances','TotalTries', 'TotalAssists', 'TotalConversions', 'TotalPenalties', 'TotalDropGoals', 'HomeWins', 'HomeDraws', 'AwayWins', 'AwayDraws', 'YellowCards', 'RedCards')
$diffPropertyNames = @('PointsAsKicker', 'FullAppearance','PartAppearance','Tries', 'Assists', 'Conversions', 'Penalties', 'DropGoals', 'HomeWin', 'HomeDraw', 'AwayWin', 'AwayDraw', 'YellowCard', 'RedCard')
$propertyCount = $sourcePropertyNames.Length
$roundStatsByPlayer = @{}
$roundsWithPriceChanges = @{}

$finalCsvContents | % {
    $finalPlayerDetails = $_
    $playerName = $_.FullName
    Write-Host -foregroundColor Green "Generating stats for $playerName"
    $totalPointsAsNonKicker = 0
    $totalKickingPoints = 0
    
    $prevRoundCumStats = $null
    $playerStats = 0..21 | % {
        $round = $_
        $cumStatsForRound = $csvFileContentsByRound[$round] | ? { $_.FullName -eq $playerName }
        if ($cumStatsForRound)
        {
            if ( $cumStatsForRound | get-member | ? { $_.Name -eq 'Round' } )
            {
                if ($cumStatsForRound.Round -ne $round)
                {
                    Write-Error "Player $playerName has round value $($cumStatsForRound.Round) that is wrong. It should be $round ."
                }
            }
            $statsForRound = $cumStatsForRound | select-object @{n='RoundsCompleted';e={$round}},@{n='IsInCompetition';e={1}},`
                FullName,FirstName,Surname,Position,Team,Price
            
            # Save stats on rounds with price changes:
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
                
                # Track which rounds have price changes:
                if ($prevRoundCumStats.Price -ne $cumStatsForRound.Price)
                {
                    $priceChangeCountInRound = $roundsWithPriceChanges[$round] + 1
                    if ($priceChangeCountInRound -eq 1)
                    {
                        Write-Host -foregroundColor Cyan "  Price change in round $round"
                    }
                    $roundsWithPriceChanges[$round] = $priceChangeCountInRound
                }
                
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
                $statsForRound = $finalPlayerDetails | select-object @{n='RoundsCompleted';e={$round}},@{n='IsInCompetition';e={0}},`
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
        
        $prevRoundCumStats = $cumStatsForRound
        $statsForRound
    }
    if ($playerStats)
    {
        $playerFileName = "fl:\PrevSeasonAnalysis\PlayerStats\ByPlayer\$($playerName).csv"
        $playerStats | export-csv $playerFileName -noTypeInformation
        
        $roundStatsByPlayer.$playerName = $playerStats
    }
    else
    {
        Write-Error "No stats for player $playerName"
    }
}

if ((Get-ChildItem fl:\PrevSeasonAnalysis\PlayerStats\ByPlayer).Length -ne $allPlayerNames.Length)
{
    Write-Error 'Some player files were not created'
}
else
{
    Write-Host 'All player data successfully created!'
}

0..21 | ? { $roundsWithPriceChanges.$_ } | Select-Object @{n='Round';e={$_}},@{n='PriceChanges';e={$roundsWithPriceChanges.$_}} `
    | export-csv fl:\PrevSeasonAnalysis\PlayerStats\RoundsWithPriceChanges.csv -noTypeInformation


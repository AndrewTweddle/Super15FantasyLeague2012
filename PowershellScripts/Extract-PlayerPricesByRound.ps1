$folderPath = 'flarchive:\2011\PlayerStats2011'
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


$roundStatsByPlayer = @{}
$roundsWithPriceChanges = @{}

$allPlayerNames | % {
    $playerName = $_
    Write-Host -foregroundColor Green "Generating stats for $playerName"
    
    $prevRoundStats = $null
    $playerStats = 0..21 | % {
        $round = $_
        $statsForRound = $csvFileContentsByRound[$round] | ? { $_.FullName -eq $playerName }
        if ($statsForRound)
        {
            if ( $statsForRound | get-member | ? { $_.Name -eq 'Round' } )
            {
                if ($statsForRound.Round -ne $round)
                {
                    Write-Error "Player $playerName has round value $($statsForRound.Round) that is wrong. It should be $round ."
                }
            }
            else
            {
                $statsForRound | add-member -MemberType NoteProperty -Name Round -value $round
            }
            $statsForRound
        }
        
        if ($prevRoundStats -ne $null)
        {
            if ($prevRoundStats.Price -ne $statsForRound.Price)
            {
                $priceChangeCountInRound = $roundsWithPriceChanges[$round] + 1
                if ($priceChangeCountInRound)
                {
                    Write-Host -foregroundColor Cyan "  Price change in round $round"
                }
                $roundsWithPriceChanges[$round] = $priceChangeCountInRound
            }
        }
        
        $prevRoundStats = $statsForRound
    }
    if ($playerStats)
    {
        $playerFileName = "fl:\PlayerStats2011\$($playerName).csv"
        $playerStats | export-csv $playerFileName -noTypeInformation
        
        $roundStatsByPlayer.$playerName = $playerStats
    }
    else
    {
        Write-Error "No stats for player $playerName"
    }
}

if ((Get-ChildItem fl:\PlayerStats2011).Length -ne $allPlayerNames.Length)
{
    Write-Error 'Some player files were not created'
}
else
{
    Write-Host 'All player data successfully created!'
}

0..21 | ? { $roundsWithPriceChanges.$_ } | Select-Object @{n='Round';e={$_}},@{n='PriceChanges';e={$roundsWithPriceChanges.$_}} `
    | export-csv fl:\RoundsWithPriceChanges.csv -noTypeInformation

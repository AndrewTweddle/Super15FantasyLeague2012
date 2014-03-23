param (
    [int] $season = 2011,
    [string] $matchResultsFolder = 'FL:\PrevSeasonAnalysis\MatchResults'
)

. fl:\PowershellScripts\Create-UtilityFunctions.ps1

$teams = import-csv 'FL:\MasterData\$season\Teams.csv'
$events = import-csv 'FL:\MasterData\Global\Events.csv' | ? { $_.EventCode -ne 'M' } # Exclude man of the match event

$eventNameMappings = @{
    Tries = 'TotalTriesScored'
    Assists = 'TotalAssistsScored'
    Conversions = 'ConversionsScored'
    Penalties = 'PenaltiesScored'
    DropGoals = 'DropGoalsScored'
    PenaltyTries = 'PenaltyTriesScored'
}

# Exclude Rebels from 2010 season:
if ($season -eq 2010)
{
    $teams = $teams | ? { $_.TeamCode -ne 'RBL' }
}

$propertiesToConvert = @{
    Round = 'int'
}
$events | % {
    $event = $_
    $eventName = $event.StrippedEventNamePlural
    $mappedName = $eventNameMappings.$eventName
    if ($mappedName)
    {
        $propertiesToConvert.$mappedName = 'int'
    }
}

# Calculate aggregates per team:
Write-Host 'Aggregates per team:' -foregroundColor Green

$aggregates = $teams | % {
    $team = $_
    $teamCode = $team.TeamCode
    $teamMatchResultsFilePath = "$matchResultsFolder\$season\ByTeam\$($teamCode).csv"
    $teamMatchResults = import-csv $teamMatchResultsFilePath | select-properties $propertiesToConvert | ? { $_.Round -le 18 }
    $gamesPlayed = $teamMatchResults.Count
        
    $aggregate = new-object PSObject
    $aggregate | Add-Member NoteProperty TeamCode $teamCode
    $aggregate | Add-Member NoteProperty GamesPlayed $gamesPlayed
    
    # Get averages per match:
    $events | % {
        $event = $_
        $strippedEventNamePlural = $event.StrippedEventNamePlural
        $eventName = $eventNameMappings.$strippedEventNamePlural
        if ($eventName)
        {
            $average = ($teamMatchResults | measure-object $eventName -average).Average
            $aggregate | Add-Member NoteProperty $strippedEventNamePlural $average
        }
    }
    
    # Get totals for all round robin matches:
    $events | % {
        $event = $_
        $strippedEventNamePlural = $event.StrippedEventNamePlural
        $eventName = $eventNameMappings.$strippedEventNamePlural
        if ($eventName)
        {
            $sum = ($teamMatchResults | measure-object $eventName -sum).sum
            $aggregate | Add-Member NoteProperty "Total$strippedEventNamePlural" $sum
        }
    }
    
    [double] $conversionRatio = 0.0
    [double] $assistRatio = 0.0
    
    if ($aggregate.TotalTries -ne 0) 
    {
        $conversionRatio = $aggregate.TotalConversions / [double] $aggregate.TotalTries
        $assistRatio = $aggregate.TotalAssists / [double] $aggregate.TotalTries
    }
    
    $aggregate | Add-Member NoteProperty 'ConversionRatio' $conversionRatio
    $aggregate | Add-Member NoteProperty 'AssistRatio' $assistRatio
    
    $aggregate
}

$aggregates
$aggregates | export-csv "$matchResultsFolder\$season\AggregatesByTeam.csv" -noTypeInformation

# Calculate aggregate over all teams:
Write-Host 'Grand aggregate:' -foregroundColor Green

$allMatchResults = import-csv "$matchResultsFolder\$season\AllResultsByTeamAndRound.csv" | `
    select-properties $propertiesToConvert | ? { $_.Round -le 18 }
$gamesPlayed = $allMatchResults.Count / 2

$grandAggregate = new-object PSObject
$grandAggregate | Add-Member NoteProperty 'GamesPlayed' $gamesPlayed

# Calculate averages over all teams and round robin matches:
$events | % {
    $event = $_
    $strippedEventNamePlural = $event.StrippedEventNamePlural
    $eventName = $eventNameMappings.$strippedEventNamePlural
    if ($eventName)
    {
        $average = ($allMatchResults | measure-object $eventName -average).Average
        $grandAggregate | Add-Member NoteProperty $strippedEventNamePlural $average
    }
}
# Calculate sums over all teams and round robin matches:
$events | % {
    $event = $_
    $strippedEventNamePlural = $event.StrippedEventNamePlural
    $eventName = $eventNameMappings.$strippedEventNamePlural
    if ($eventName)
    {
        $sum = ($allMatchResults | measure-object $eventName -sum).Sum
        $grandAggregate | Add-Member NoteProperty "Total$strippedEventNamePlural" $sum
    }
}

# Calculate useful ratios:
if ($grandAggregate.TotalTries -ne 0) 
{
    $conversionRatio = $grandAggregate.TotalConversions / [double] $grandAggregate.TotalTries
    $assistRatio = $grandAggregate.TotalAssists / [double] $grandAggregate.TotalTries
}
$grandAggregate | Add-Member NoteProperty 'ConversionRatio' $conversionRatio
$grandAggregate | Add-Member NoteProperty 'AssistRatio' $assistRatio

$grandAggregate
$grandAggregate | export-csv "$matchResultsFolder\$season\AggregateForAllTeams.csv" -noTypeInformation

param (
    [int] $season = 2011,
    [string] $playerStatsFolder = 'FL:\PrevSeasonAnalysis\PlayerStats',
    [string] $matchResultsFolder = 'FL:\PrevSeasonAnalysis\MatchResults'
)

. fl:\PowershellScripts\Create-UtilityFunctions.ps1

$players = import-csv "FL:\MasterData\$season\Players\Players.csv"
$teams = import-csv 'FL:\MasterData\$season\Teams.csv'
$events = import-csv 'FL:\MasterData\Global\Events.csv' | ? { $_.EventCode -ne 'M' } # Exclude man of the match event
$positionTypes = import-csv 'FL:\MasterData\Global\PositionTypes.csv'
$positions = import-csv "FL:\MasterData\Global\Positions.csv"

$eventNameMappings = @{
    Tries = 'TotalTriesScored'
    Assists = 'TotalAssistsScored'
    Conversions = 'ConversionsScored'
    Penalties = 'PenaltiesScored'
    DropGoals = 'DropGoalsScored'
    # PenaltyTries = 'PenaltyTriesScored'
}

# Exclude Rebels from 2010 season:
if ($season -eq 2010)
{
    $teams = $teams | ? { $_.TeamCode -ne 'RBL' }
}

$propertiesToConvert = @{}
$events | % {
    $event = $_
    $eventName = $event.StrippedEventNamePlural
    $mappedName = $eventNameMappings.$eventName
    if ($mappedName)
    {
        $propertiesToConvert.$mappedName = 'int'
    }
}

$positionTypes | % {
    $positionType = $_.PositionType
    $propertiesToConvert."$($positionType)TriesScored" = 'int'
    $propertiesToConvert."$($positionType)AssistsScored" = 'int'
}

$positions | % {
    $positionCode = $_.PositionCode
    $propertiesToConvert."$($positionCode)TriesScored" = 'int'
    $propertiesToConvert."$($positionCode)AssistsScored" = 'int'
}

$aggregates = $players | % {
    $player = $_
    $playerName = $player.PlayerName
    $teamCode = $player.TeamCode
    $positionCode = $player.PositionCode
    $positionType = $player.PositionType
    $rookie = $player.Rookie
    Write-Host "Calculating aggregates for $playerName" -foregroundColor Green
    
    $unfilteredPlayerStats = import-csv "$playerStatsFolder\ByPlayer\$($playerName).csv"
    $playerStats = $unfilteredPlayerStats | ? {
        [int]::Parse( $_.PartAppearance ) + [int]::Parse( $_.FullAppearance ) -gt 0
    } | ? {
        [int]::Parse( $_.RoundsCompleted ) -le 18
    }
    $roundsPlayed = $playerStats | ? {
        $_.RoundsCompleted
    } | % { 
        [int]::Parse( $_.RoundsCompleted )
    } | ? {
        ($_ -gt 0) -and ($_ -le 18)
    }
    
    if ($roundsPlayed)
    {
        [int] $gamesPlayed = $roundsPlayed.Count
        [int] $fullAppearances = @($playerStats | ? { $_.FullAppearance -eq '1' }).Count
        [int] $partAppearances = @($playerStats | ? { $_.PartAppearance -eq '1' }).Count
        if ($gamesPlayed)
        {
            [double] $fullAppearanceRatio = $fullAppearances / [double] $gamesPlayed
            [double] $partAppearanceRatio = $partAppearances / [double] $gamesPlayed
            $totalAppearanceRatio = $fullAppearanceRatio + $partAppearanceRatio
            if ($totalAppearanceRatio -le 0.99 -or $totalAppearanceRatio -gt 1.01)
            {
                throw "Total appearance ratio is $totalAppearanceRatio instead of 1.0"
            }
        }
        else
        {
            [double] $fullAppearanceRatio = 0
            [double] $partAppearanceRatio = 0
        }
        
        $teamMatchResultsFilePath = "$matchResultsFolder\$season\ByTeam\$($teamCode).csv"
        $teamMatchResults = import-csv $teamMatchResultsFilePath | ? { 
            $roundsPlayed -contains [int]::Parse( $_.Round )
        } | select-properties $propertiesToConvert
        
        $aggregate = new-object PSObject
        $aggregate | Add-Member NoteProperty PlayerName $playerName
        $aggregate | Add-Member NoteProperty TeamCode $teamCode
        $aggregate | Add-Member NoteProperty PositionCode $positionCode
        $aggregate | Add-Member NoteProperty PositionType $positionType
        $aggregate | Add-Member NoteProperty Rookie $rookie
        $aggregate | Add-Member NoteProperty GamesPlayed $gamesPlayed
        $aggregate | Add-Member NoteProperty FullAppearances $fullAppearances
        $aggregate | Add-Member NoteProperty PartAppearances $partAppearances
        $aggregate | Add-Member NoteProperty FullAppearanceRatio $fullAppearanceRatio
        $aggregate | Add-Member NoteProperty PartAppearanceRatio $partAppearanceRatio
        
        $events | % {
            $event = $_
            switch ($event.EventCode)
            {
                # A player can only have 1 yellow card or red card per game.
                'Y' { 
                    $sourcePropertyName = 'YellowCard'
                    $totalsPropertyName = 'TotalYellowCards'
                    $perGamePropertyName = 'YellowCardsPerGame'
                    break
                }
                'R' {
                    $sourcePropertyName = 'RedCard'
                    $totalsPropertyName = 'TotalRedCards'
                    $perGamePropertyName = 'RedCardsPerGame'
                    break
                }
                default { 
                    $sourcePropertyName = $event.StrippedEventNamePlural
                    $totalsPropertyName = "Total$sourcePropertyName"
                    $perGamePropertyName = "$($sourcePropertyName)PerGame"
                }
            }
            
            # Calculate total for player:
            $propertyName = $totalsPropertyName
            Write-Host "    Calculating $propertyName from $sourcePropertyName" -foregroundColor 'Cyan'
            $total = ($playerStats | measure-object $sourcePropertyName -sum).Sum
            $aggregate | Add-Member NoteProperty $propertyName $total
            
            # Calculate average for player:
            $propertyName = $perGamePropertyName
            Write-Host "    Calculating $propertyName from $sourcePropertyName" -foregroundColor 'Cyan'
            $average = ($playerStats | measure-object $sourcePropertyName -average).Average
            $aggregate | Add-Member NoteProperty $propertyName $average
        }
        
        # Determine team's average and get proportion of team points:
        Write-Host "    Calculating proportion of team's average for each event" -foregroundColor 'Cyan'
        $events | % {
            $event = $_
            $strippedEventNamePlural = $event.StrippedEventNamePlural
            $sourcePropertyName = "$($strippedEventNamePlural)PerGame"
            $propertyName = "ProportionOfTeam$sourcePropertyName"
            $average = $aggregate.$sourcePropertyName
            $teamEventName = $eventNameMappings.$strippedEventNamePlural
            if ($teamEventName)
            {
                Write-Host "        Calculating $propertyName from $teamEventName" -foregroundColor 'Yellow'
                $teamAverage = ($teamMatchResults | ? { 
                        $_.$teamEventName -ne 0.0 
                    } | measure-object $teamEventName -average
                ).Average
                if ($teamAverage -eq 0)
                {
                    $proportionOfAverage = [double]::NaN  # was: 0.0
                }
                else
                {
                    $proportionOfAverage = $average / $teamAverage
                }
                $aggregate | Add-Member NoteProperty $propertyName $proportionOfAverage
            }
        }
        
        # Determine position type's average in team and get proportion of team points:
        Write-Host "    Calculating proportion of position type's average for tries and assists" -foregroundColor 'Cyan'
        'Tries','Assists' | % {
            $event = $_
            $sourcePropertyName = "$($event)PerGame"
            $propertyName = "ProportionOfPositionTypes$sourcePropertyName"
            $average = $aggregate.$sourcePropertyName
            
            $positionTypeEventName = "$positionType$($event)Scored"
            Write-Host "        Calculating $propertyName from $positionTypeEventName" -foregroundColor 'Yellow'
            
            $positionTypeAverage = ($teamMatchResults | measure-object $positionTypeEventName -average).Average
            if ($positionTypeAverage -eq 0)
            {
                $proportionOfAverage = 0.0
            }
            else
            {
                $proportionOfAverage = $average / $positionTypeAverage
            }
            $aggregate | Add-Member NoteProperty $propertyName $proportionOfAverage
            
            # Calculate proportion of position's score:
            $propertyName = "ProportionOfPositions$sourcePropertyName"
            $positionEventName = "$positionCode$($event)Scored"
            Write-Host "            Calculating $propertyName from $positionEventName" -foregroundColor Magenta
            
            $positionAverage = ($teamMatchResults | measure-object $positionEventName -average).Average
            if ($positionAverage -eq 0)
            {
                $proportionOfAverage = 0.0
            }
            else
            {
                $proportionOfAverage = $average / $positionAverage
            }
            $aggregate | Add-Member NoteProperty $propertyName $proportionOfAverage
        }
        
        $aggregate
    }
}

$playerAggregatesFileName = "$playerStatsFolder\AggregateStatsByPlayer.csv"
$aggregates | export-csv $playerAggregatesFileName -noTypeInformation

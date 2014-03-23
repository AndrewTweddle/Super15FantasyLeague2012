param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' )
)

. fl:\PowershellScripts\Create-UtilityFunctions.ps1

# Input files:
[string] $allPlayerStatsFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\AllPlayerStatsToDate.csv"
[string] $allMatchResultsFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\AllMatchResultsToDate.csv"

# Output files:
$playerAggregatesFileName = "FL:\DataByRound\Round$upcomingRound\Inputs\AggregateStatsByPlayer.csv"


# Load lookup data:
$players = import-csv "FL:\MasterData\$season\Players\Players.csv"
$teams = import-csv "FL:\MasterData\$season\Teams.csv"
$events = import-csv 'FL:\MasterData\Global\Events.csv' | ? { $_.EventCode -ne 'M' } # Exclude man of the match event
$positionTypes = import-csv 'FL:\MasterData\Global\PositionTypes.csv'
$positions = import-csv "FL:\MasterData\Global\Positions.csv"

$prevSeasonPlayers = import-csv "FL:\MasterData\$($season-1)\Players\Players.csv"

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

$propertiesToConvert = @{
    'Season' = 'int'
    'Round' = 'int'
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

# Load input data
$allMatchResults = import-csv $allMatchResultsFilePath
$allPlayerStats = import-csv $allPlayerStatsFilePath
$allPlayerStatsByPlayer = $allPlayerStats | group-object FullName

$aggregates = $players | % {
    $player = $_
    $playerName = $player.PlayerName
    $teamCode = $player.TeamCode
    $positionCode = $player.PositionCode
    $positionType = $player.PositionType
    $rookie = $player.Rookie
    Write-Host "Calculating aggregates for $playerName" -foregroundColor Green
    
    $prevSeasonPlayer = $prevSeasonPlayers | ? { $_.PlayerName -eq $playerName }
    if ($prevSeasonPlayer)
    {
        [string] $prevTeamCode = $prevSeasonPlayer.TeamCode
    }
    else
    {
        [string] $prevTeamCode = [string]::Empty
    }
    
    $unfilteredPlayerStats = @( 
        $allPlayerStatsByPlayer | ? { $_.Name -eq $playerName } | % { $_.Group } 
    )
    $playerStats = @( 
        $unfilteredPlayerStats | ? {
            [int]::Parse( $_.PartAppearance ) + [int]::Parse( $_.FullAppearance ) -gt 0
        } | ? {
            [int]::Parse( $_.RoundsCompleted ) -le 18
        } | % {
            $_ | Add-Member NoteProperty Weighting -value $( 
                if ([int]::Parse($_.Season) -lt $season ) 
                {
                    0.25
                } 
                else
                {
                    [Math]::Pow( 1.05, [int]::Parse( $_.RoundsCompleted ) - 1 )
                } 
            ) -passThru
        }
    )
    $roundsPlayed = @(
        $playerStats | % { 
            new-object PSObject -property @{
                Season = [int]::Parse( $_.Season )
                Round = [int]::Parse( $_.RoundsCompleted )
            }
        } | ? {
            ($_.Round -gt 0) -and ($_.Round -le 18)
        } | select-object Season,Round
    )
    
    if ($roundsPlayed)
    {
        [int] $gamesPlayed = $roundsPlayed.Count
        [int] $fullAppearances = @($playerStats | ? { $_.FullAppearance -eq '1' }).Count
        [int] $partAppearances = @($playerStats | ? { $_.PartAppearance -eq '1' }).Count
        [double] $weightedFullAppearances = ($playerStats | ? { $_.FullAppearance -eq '1' } | % { $_.Weighting } | measure-object -sum).Sum
        [double] $weightedPartAppearances = ($playerStats | ? { $_.PartAppearance -eq '1' } | % { $_.Weighting } | measure-object -sum).Sum
        [double] $weightingDenominator = ($playerStats | ? { 
            $_.FullAppearance -eq '1' -or $_.PartAppearance -eq '1'
        } | % { $_.Weighting } | measure-object -sum).Sum
        
        if ($gamesPlayed)
        {
            [double] $fullAppearanceRatio = $weightedFullAppearances / $weightingDenominator
            [double] $partAppearanceRatio = $weightedPartAppearances / $weightingDenominator
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
        
        $teamMatchResults = $allMatchResults | ? { 
            $matchResult = $_
            if ($matchResult.Season -eq $season)
            {
                [string] $teamCodeForSeason = $teamCode
            }
            else
            {
                [string] $teamCodeForSeason = $prevTeamCode
            }
            if ($matchResult.TeamCode -eq $teamCodeForSeason)
            {
                $roundPlayed = $roundsPlayed | ? {
                    ($_.Season -eq $matchResult.Season) -and ($_.Round -eq $matchResult.Round)
                }
                if ($roundPlayed) { $true } else { $false }  # for readability - not strictly necessary to explicitly convert to a bool
            }
            else
            {
                $false
            }
        } `
        | select-properties $propertiesToConvert `
        | % {
            $_ | Add-Member NoteProperty Weighting -value $( 
                if ([int]::Parse($_.Season) -lt $season ) 
                {
                    0.25
                } 
                else
                {
                    [Math]::Pow( 1.05, [int]::Parse( $_.Round ) - 1 )
                } 
            ) -passThru
        }
        
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
            $numerator = ( 
                $playerStats | % { 
                    [double]::Parse( $_.$sourcePropertyName ) * $_.Weighting
                } | measure-object -sum 
            ).Sum
            $average = $numerator / $weightingDenominator 
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
                $weightedTeamNumerator = (
                    $teamMatchResults | ? { 
                        $_.$teamEventName -ne 0.0 
                    } | % {
                        [double]::Parse( $_.$teamEventName ) * $_.Weighting
                    } | measure-object -sum
                ).Sum
                $weightedTeamAverage = $weightedTeamNumerator / $weightingDenominator
                if ($teamAverage -eq 0)
                {
                    $proportionOfAverage = [double]::NaN  # was: 0.0
                }
                else
                {
                    $proportionOfAverage = $average / $weightedTeamAverage
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

$aggregates | export-csv $playerAggregatesFileName -noTypeInformation

#Beauden Barrett:
$playerName = 'Beauden Barrett'
get-childitem -path flarchive:\2011\PlayerStats2011 -filter *.csv | select-string $playerName

$pattern = '"Beauden\ Barrett",Beauden,Barrett,6,FLH,HUR,(?<TotalPoints>\d+),0,(?<PartGames>\d+),0,0,0'
$selections = Get-ChildItem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $pattern
$selections | % {
    $selection = $_
    $path = $selection.Path
    $contents = [System.IO.File]::ReadAllText($path)
    if ($contents -match $pattern) {
        $matchingText = $matches[0]
        $totalPoints = [int]::Parse( $matches.TotalPoints ) + 2
        $partGames = $matches.PartGames
        $replacementText = "`"Beauden Barrett`",Beauden,Barrett,6,FLH,HUR,$totalPoints,0,$partGames,0,0,1"
        $newContents = $contents -replace $pattern,$replacementText
        [System.IO.File]::WriteAllText($path, $newContents)
    }
    else
    {
        throw 'No match'
    }
}

# Kurt Coleman
$playerName = 'Kurt Coleman'
get-childitem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $playerName

# Add lines before Kurtis Haiu...

# line to add to rounds 11 - 14:
"Kurt Coleman",Kurt,Coleman,8,FLH,STO,8,0,1,0,0,1,0,0,1,0,0,0,0,0,0

# line to add to round 15:
"Kurt Coleman",Kurt,Coleman,8,FLH,STO,26,0,2,0,0,2,2,0,1,0,1,0,0,0,0
#                             R16 is: 51,0,2,1,0,3,5,0,0,0,2,0,0,0,0
#                          Should be: 59,0,3,1,0,4,5,0,1,0,2,0,0,0,0
#                          Generated: 59,0,3,1,0,4,5,0,1,0,2,0,0,0,0

# Columns: FullName	FirstName	Surname	Price	Position	Team	TotalPoints	FullAppearances	PartAppearances	Tries	Assists	Conversions	Penalties	DropGoals   HomeWins	HomeDraws	AwayWins	AwayDraws

# '"Kurt Coleman",Kurt,Coleman,8,FLH,STO,51,0,2,1,0,3,5,0,0,0,2,0,0,0,0'
$pattern = '"Kurt\ Coleman",Kurt,Coleman,(?<Price>\d+(\.\d+)?),FLH,STO,(?<TotalPoints>\d+),(?<FullGames>\d+),(?<PartGames>\d+),(?<Tries>\d+),(?<Assists>\d+),(?<Conversions>\d+),(?<Penalties>\d+),(?<DropGoals>\d+),(?<HomeWins>\d+),(?<HomeDraws>\d+),(?<AwayWins>\d+),(?<AwayDraws>\d+),0,0,0'
$totalPointsAdjustment = 8
$homeWinAdjustment = 1
$partGameAdjustment = 1
$conversionAdjustment = 1

$selections = Get-ChildItem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $pattern
$selections = $selections | ? {
    ($_.Path -match 'PlayerStats_Round(?<Round>\d+)_.+.csv') -and ([int]::Parse($matches.Round) -ge 16)
}

$selections | % {
    $selection = $_
    $path = $selection.Path
    $contents = [System.IO.File]::ReadAllText($path)
    if ($contents -match $pattern) {
        $matchingText = $matches[0]
        $price = [int]::Parse( $matches.Price )
        $totalPoints = [int]::Parse( $matches.TotalPoints ) + $totalPointsAdjustment
        $fullGames = [int]::Parse( $matches.FullGames )
        $partGames = [int]::Parse( $matches.PartGames ) + $partGameAdjustment
        $tries = $matches.Tries
        $assists = $matches.Assists
        $conversions = [int]::Parse( $matches.Conversions ) + $conversionAdjustment
        $penalties = $matches.penalties
        $dropGoals = $matches.dropGoals
        $homeWins = [int]::Parse( $matches.homeWins ) + $homeWinAdjustment
        $homeDraws = $matches.homeDraws
        $awayWins = $matches.awayWins
        $awayDraws = $matches.awayDraws
        $replacementText = "`"Kurt Coleman`",Kurt,Coleman,$price,FLH,STO,$totalPoints,$fullGames,$PartGames,$tries,$assists,$conversions,$penalties,$dropGoals,$homeWins,$homeDraws,$awayWins,$awayDraws,0,0,0"
        $newContents = $contents -replace $pattern,$replacementText
        [System.IO.File]::WriteAllText($path, $newContents)
    }
    else
    {
        throw 'No match'
    }
}


# Quade Cooper
$playerName = 'Quade Cooper'
get-childitem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $playerName

# Columns: FullName	FirstName	Surname	Price	Position	Team	TotalPoints	FullAppearances	PartAppearances	
#          Tries	Assists	Conversions	Penalties	DropGoals   HomeWins	HomeDraws	AwayWins	AwayDraws

# Round 20: "Quade Cooper",Quade,Cooper,12,FLH,RED,447,16,1,5,11,30,41,4,8,0,6,0,0,0,0
# Round 21: "Quade Cooper",Quade,Cooper,12,FLH,RED,467,16,1,5,12,31,41,4,9,0,6,0,0,0,0

#  Replace: "Quade Cooper",Quade,Cooper,12,FLH,RED,467,17,1,5,12,31,43,4,9,0,6,0,0,0,0
# Points are correct: 4 for home win, 4 for full game, 4 for an assist, 8 points for 2 penalties and a conversion
# Full games and penalty count needed to be updated.


# Elton Jantjes
$playerName = 'Elton Jantjes'
get-childitem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $playerName

#  Round 12: "Elton Jantjes",Elton,Jantjes,8.5,FLH,LIO,102,3,5,0,1,4,18,1,0,0,1,0,0,0,0
#  Round 13: "Elton Jantjes",Elton,Jantjes,8.5,FLH,LIO,133,4,5,0,3,5,21,1,0,0,2,0,0,0,0

# Change to: "Elton Jantjes",Elton,Jantjes,8.5,FLH,LIO,131,4,5,0,3,7,19,1,0,0,2,0,0,0,0
#     Check: "Elton Jantjes",Elton,Jantjes,8.5,FLH,LIO,131,4,5,0,3,7,19,1,0,0,2,0,0,0,0
# 
# Score: 
# Lions away win = 8, full game = 4, 2 assists = 8, 3 (not 1) conversions, 1 (not 3) penalties
#       So 29 points, not 31


$pattern = '"Elton\ Jantjes",Elton,Jantjes,(?<Price>\d+(\.\d+)?),FLH,LIO,(?<TotalPoints>\d+),(?<FullGames>\d+),(?<PartGames>\d+),(?<Tries>\d+),(?<Assists>\d+),(?<Conversions>\d+),(?<Penalties>\d+),(?<DropGoals>\d+),(?<HomeWins>\d+),(?<HomeDraws>\d+),(?<AwayWins>\d+),(?<AwayDraws>\d+),0,0,0'
$totalPointsAdjustment = -2
$homeWinAdjustment = 0
$partGameAdjustment = 0
$conversionAdjustment = 2
$penaltyAdjustment = -2
$firstRoundToFix = 13

$selections = Get-ChildItem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $pattern
$selections = $selections | ? {
    ($_.Path -match 'PlayerStats_Round(?<Round>\d+)_.+.csv') -and ([int]::Parse($matches.Round) -ge $firstRoundToFix)
}

if ($selections.Count -ne $(22 - $firstRoundToFix))
{
    throw 'The pattern does not match all rows to fix'
}
else
{
    $selections | % {
        $selection = $_
        $path = $selection.Path
        $contents = [System.IO.File]::ReadAllText($path)
        if ($contents -match $pattern) {
            $matchingText = $matches[0]
            $price = $matches.Price
            $totalPoints = [int]::Parse( $matches.TotalPoints ) + $totalPointsAdjustment
            $fullGames = [int]::Parse( $matches.FullGames )
            $partGames = [int]::Parse( $matches.PartGames ) + $partGameAdjustment
            $tries = $matches.Tries
            $assists = $matches.Assists
            $conversions = [int]::Parse( $matches.Conversions ) + $conversionAdjustment
            $penalties = [int]::Parse( $matches.penalties ) + $penaltyAdjustment
            $dropGoals = $matches.dropGoals
            $homeWins = [int]::Parse( $matches.homeWins ) + $homeWinAdjustment
            $homeDraws = $matches.homeDraws
            $awayWins = $matches.awayWins
            $awayDraws = $matches.awayDraws
            $replacementText = "`"Elton Jantjes`",Elton,Jantjes,$price,FLH,LIO,$totalPoints,$fullGames,$PartGames,$tries,$assists,$conversions,$penalties,$dropGoals,$homeWins,$homeDraws,$awayWins,$awayDraws,0,0,0"
            $newContents = $contents -replace $pattern,$replacementText
            [System.IO.File]::WriteAllText($path, $newContents)
        }
        else
        {
            throw "No match in $path"
        }
    }
}


# Earl Rose
$playerName = 'Earl Rose'
get-childitem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $playerName

#  Round 15: "Earl Rose",Earl,Rose,6.5,FLH,CHE,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
#  Round 16: "Earl Rose",Earl,Rose,6.5,FLH,STO,12,0,1,0,0,1,0,0,0,0,1,0,0,0,0

# The problem is that Earl Rose became a Stormers player, not a Cheetahs player (he was with Griquas until called on tour).

$replacementText = '"Earl Rose",Earl,Rose,6.5,FLH,STO'
$pattern = '"Earl\ Rose",Earl,Rose,6.5,FLH,CHE'
$lastRoundToFix = 15

$selections = Get-ChildItem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $pattern
$selections = $selections | ? {
    ($_.Path -match 'PlayerStats_Round(?<Round>\d+)_.+.csv') -and ([int]::Parse($matches.Round) -le $lastRoundToFix)
}

if ($selections.Count -ne $($lastRoundToFix + 1))
{
    throw 'The pattern does not match all rows to fix'
}
else
{
    $selections | % {
        $selection = $_
        $path = $selection.Path
        $contents = [System.IO.File]::ReadAllText($path)
        if ($contents -match $pattern) {
            $newContents = $contents -replace $pattern,$replacementText
            [System.IO.File]::WriteAllText($path, $newContents)
        }
        else
        {
            throw "No match in $path"
        }
    }
}


# Other discrepancies:
# Andries van Rensburg was given the points for Deon van Rensburg's try and full appearance in round 6
# This was reversed in round 7.
# Updated round 6 data accordingly.
# Deon ran Rensburg's points went from 2 to 16
# Andries van Rensburg's points went from 18 to 0

# Kurtley Beale had -1 penalty in round 3.
# Berrick Barnes had 2 penalties in round 3, but no appearance points.
# The solution was to transfer Kurtley Beale's 2 penalties in round 2 to Berrick Barnes (who actually scored them).
# This automatically makes the round 3 data come right.

# James Paterson of the Highlanders had a home win in round 7, but no appearance points.
# He had a part appearance in round 7. 
# Increase his part games by 1 for round 7 onwards.

# Matthew Luamanu of the Blues had a home win in round 7, but no appearance points. He did play a part game however.
# Increase his part games by 1 for round 7 onwards

[string[]] $firstNames = 'James','Matthew '
[string[]] $lastNames = 'Paterson', 'Luamanu'

$totalPointsAdjustment = 2
$homeWinAdjustment = 0
$partGameAdjustment = 1
$conversionAdjustment = 0
$penaltyAdjustment = 0
$firstRoundToFix = 7

0..1 | % {
    $i = $_
    $firstName = $firstNames[$i]
    $lastName = $lastNames[$i]
    
    $pattern = '"?' + $firstName + '\ +' + $lastName + '"?,"?' + $firstName + '\ *"?,"?' + $lastName + `
        '"?,(?<Price>\d+(\.\d+)?),(?<Position>[^,]+),(?<TeamCode>[^,]+),(?<TotalPoints>\d+),(?<FullGames>\d+),(?<PartGames>\d+),(?<Tries>\d+),(?<Assists>\d+),(?<Conversions>\d+),(?<Penalties>\d+),(?<DropGoals>\d+),(?<HomeWins>\d+),(?<HomeDraws>\d+),(?<AwayWins>\d+),(?<AwayDraws>\d+),'

    $selections = Get-ChildItem -path fl:\PrevSeasonAnalysis\PlayerStats\CleanedPlayerStats -filter *.csv | select-string $pattern
    $selections = $selections | ? {
        ($_.Path -match 'PlayerStats_Round(?<Round>\d+)_.+.csv') -and ([int]::Parse($matches.Round) -ge $firstRoundToFix)
    }

    if ($selections.Count -ne $(22 - $firstRoundToFix))
    {
        throw 'The pattern does not match all rows to fix'
    }
    else
    {
        $selections | % {
            $selection = $_
            $path = $selection.Path
            $contents = [System.IO.File]::ReadAllText($path)
            if ($contents -match $pattern) {
                $matchingText = $matches[0]
                $price = $matches.Price
                $position = $matches.Position
                $teamCode = $matches.TeamCode
                $totalPoints = [int]::Parse( $matches.TotalPoints ) + $totalPointsAdjustment
                $fullGames = [int]::Parse( $matches.FullGames )
                $partGames = [int]::Parse( $matches.PartGames ) + $partGameAdjustment
                $tries = $matches.Tries
                $assists = $matches.Assists
                $conversions = [int]::Parse( $matches.Conversions ) + $conversionAdjustment
                $penalties = [int]::Parse( $matches.penalties ) + $penaltyAdjustment
                $dropGoals = $matches.dropGoals
                $homeWins = [int]::Parse( $matches.homeWins ) + $homeWinAdjustment
                $homeDraws = $matches.homeDraws
                $awayWins = $matches.awayWins
                $awayDraws = $matches.awayDraws
                $replacementText = "`"$firstName $lastName`",$firstName,$lastName,$price,$position,$teamCode,$totalPoints,$fullGames,$PartGames,$tries,$assists,$conversions,$penalties,$dropGoals,$homeWins,$homeDraws,$awayWins,$awayDraws,"
                $newContents = $contents -replace $pattern,$replacementText
                [System.IO.File]::WriteAllText($path, $newContents)
            }
            else
            {
                throw "No match in $path"
            }
        }
    }
}
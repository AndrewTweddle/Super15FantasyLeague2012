param
(
    [string] $jsonFilePath = $( throw 'Please provide the path to the json file exported with Fiddler' ),
    [string] $pattern = @'
\[(?<id>\d+),"(?<FirstName>[^"]+)","(?<Surname>[^"]+)",(?<Price>\d+(\.\d+)?),(?<Age>[^,]+),
(?<PositionId>[^,]+),"(?<Position>[^"]+)","(?<TeamName>[^"]+)","(?<Team>[^"]+)",
"(?<Country>[^"]+)","(?<PointsLastRound>[^"]+)",(?<Captain>[^,]*),(?<Kicker>[^,]*),
"(?<FullName>[^"]+)","?(?<PlayerImageFileName>[^",]*)"?,(?<AutoBench>[^,]*),
(?<TotalPoints>-?\d+),(?<FullAppearances>\d+),(?<PartAppearances>\d+),
(?<Tries>\d+),(?<Assists>[^,]+),(?<Conversions>\d+),(?<Penalties>\d+),(?<DropGoals>\d+),
(?<HomeWins>\d+),(?<HomeDraws>\d+),(?<AwayWins>\d+),(?<AwayDraws>\d+),(?<YellowCards>\d+),(?<RedCards>\d+),
(?<ManOfTheMatch>\d+),(?<BonusPoints>\d+)]
'@,
    [string[]] $propertyNames = ('FullName','FirstName', 'Surname', 'Price', 'Position', 'Team', 'TotalPoints', 'FullAppearances', 'PartAppearances', 'Tries', `
      'Assists','Conversions', 'Penalties', 'DropGoals', 'HomeWins', 'HomeDraws', 'AwayWins', 'AwayDraws', 'YellowCards', 'RedCards', 'ManOfTheMatch', 'BonusPoints' )
)

# /superrugby/scripts/statistics.js contains code giving the meaning of the various fields.
# This is currently (2012-02-21 not showing the name of an extra column.
# This column is probably the number of points scored from team bonus points.

$unfilteredContent = Get-Content $jsonFilePath

# Skip alternate lines
[int] $i = 0
$contents = $unfilteredContent | % { 
    if (-not ($i % 2)) 
    { 
        $_ 
    }
    $i++
} | join-string -Separator '' 

$countPattern = '\],\['
$regex = new-object System.Text.RegularExpressions.Regex -argumentList $countPattern
$matches = $regex.Matches($contents)
$expectedPlayers = $matches.Count + 1

$regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace
$regex = new-object System.Text.RegularExpressions.Regex -argumentList $pattern,$regexOptions
$matches = $regex.Matches($contents)
$playersFound = $matches.Count

[bool] $checkNames = $false

$teamMapping = @{
	BRU='BRM'
	CHI='CHF'
	'FOR'='WFR'
	REB='RBL'
	SHA='SHK'
}

$positionMapping = @{
	'Outside Back'='OB'
	Centre='CT'
	'Fly Half'='FLH'
	'Scrum Half'='SCH'
	'Loose Forward'='FL8'
	'Lock'='LOCK'
	'Front Row'='FRF'
}

$mappings = @{
	Team = $teamMapping
	Position = $positionMapping
}

$lastPos = -1
$seq = 1

$players = $matches | % {
    $match = $_
    
    $pos = $match.Captures[0].Index
    if ($lastPos -ge 0) {
        if ($pos - $lastPos -ge 10) {
            Write-Host "MISSING!!!" -foregroundColor Red
        }
    }
    
    $lastPos = $pos + $match.Captures[0].Length
    $seq++
    
    $player = new-object Management.Automation.PSObject
    
    $propertyNames | % {
        $propertyName = $_
        $value = $match.Groups[$propertyName].Value
		$mapping = $mappings[$propertyName]
		if ($mapping -and $mapping[$value]) {
			$value = $mapping[$value]
		}
        $player | Add-Member NoteProperty $propertyName $value
    }
    
    Write-Host "Imported player $($player.FullName)" -foregroundColor Green
    
    $player.Team = $player.Team.ToUpper()
    $player
    
    if ($checkNames)
    {
        $names = $names | ? { $_ -ne $player.FullName }
    }
}
Write-Host

$players

if ($playersFound -ne $expectedPlayers) {
    Write-Warning "Only $playersFound found. $expectedPlayers expected."
    Write-Host
}

param (
    [int] $season = $( read-host 'Season' ),
    [string] $teamCode = $( read-host 'Team code' ),
    [string] $playerName = $( read-host 'Player name' ),
    [int] $startRound = $( read-host 'From round' ),
    [int] $endRound = $( read-host 'To round' ),
    [int] $expectedReturn = $( read-host 'Expected return round (-1) to treat injury as indefinite / permanent' ),
    [string] $reason = $( read-host 'Reason' )
)

$rows = $startRound..$endRound | % {
    [int] $round = $_
    
    # Calculate probability of playing:
    if ($expectedReturn -eq -1)
    {
        [double] $probabilityOfPlaying = 0.0
    }
    else
    {
        [int] $relativeToExpectedRound = $round - $expectedReturn
        if ($expectedReturn - $startRound -le 2)
        {
            # Minor injury:
            [double] $probabilityOfPlaying = switch ($relativeToExpectedRound)
            {
                -1 { 0.1 }
                0 { 0.5 }
                1 { 0.9 }
                default { 0.0 }
            }
        }
        else
        {
            # Major injury:
            [double] $probabilityOfPlaying = switch ($relativeToExpectedRound)
            {
                -1 { 0.25 }
                0 { 0.5 }
                1 { 0.75 }
                2 { 0.9 }
                default { 0.0 }
            }
        }
    }
    
    if ($round -eq $expectedReturn)
    {
        [string] $notes = '"Expected return"'
    }
    else
    {
        [string] $notes = ''
    }
    
    "$season,$round,$teamCode,`"$playerName`",$probabilityOfPlaying,`"$reason`",$notes"
}

$injuryRecords = join-string -strings $rows -newline
$injuryRecords
$injuryRecords | out-clipboard

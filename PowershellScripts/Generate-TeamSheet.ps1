param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $teamCode = $( read-host 'Team code' ),
    [switch] $reverse = $false,
    [int[]] $positionNumbers = $( if ($reverse) {
            15..1 + 16..22
        }
        else {
            1..22
        }
    )
    #  Code sample to do positions in reverse order: 
    #  $pos = 15..1 + 16..22
    #  . FL:\PowershellScripts\Generate-TeamSheet.ps1 2012 4 WAR $pos
)

$teamSheetFilePath = "FL:\DataByRound\Round$upcomingRound\TeamSheets\$($teamCode)_TeamSheet.csv"

if (test-path $teamSheetFilePath)
{
    $replaceTeamsheetOption = read-host "The team sheet already exists for $teamCode. Replace it (Y/N)?"
    [bool] $canContinue = $replaceTeamsheetOption -eq 'Y'
}
else
{
    [bool] $canContinue = $true
}

if ($canContinue)
{
    $dummy = read-host 'Copy the players to the clipboard and press any key to continue'
    
    $clipboardText = Get-Clipboard
    $players = split-string -input $clipboardText -NewLine

    $team = @(
        for ($i = 0; $i -lt 22; $i++)
        {
            $positionNumber = $positionNumbers[$i]
            if ($positionNumber -le 15)
            {
                [string] $roleCode = 'P'
            }
            else
            {
                [string] $roleCode = 'S'
            }
            $playerName = $players[$i]
            new-object PSObject -property @{
                TeamCode = $teamCode
                PlayerNumber = $positionNumber
                PlayerName = $playerName
                RoleCode = $roleCode
                ProbabilityOfPlaying = 1.0
            }
        }
    )
}

$team | select-object TeamCode,PlayerNumber,PlayerName,RoleCode,ProbabilityOfPlaying | export-csv $teamSheetFilePath -noTypeInformation

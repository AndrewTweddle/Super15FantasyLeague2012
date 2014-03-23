param (
    [int] $season = $( read-host 'Season' ),
    [int] $round = $( read-host 'Rounds completed' )
)

# Input files:
[string] $url = 'http://livescores.ninemsn.com.au/rugby/super15.html'

if ($round -gt 1)
{
    [string] $prevRoundMatchResultsFilePath = "FL:\DataByRound\Round$($round - 1)\TeamResults\SeasonToDateMatchResults.csv"
}

# Output files:
[string] $matchResultsFileName = join-path $( convert-path "fl:\DataByRound\Round$round\TeamResults" ) "NineMsn_$season.htm"
[string] $matchResultsThisRoundFilePath = "FL:\DataByRound\Round$round\TeamResults\MatchResultsThisRound.csv"
[string] $seasonToDateMatchResultsFilePath = "FL:\DataByRound\Round$round\TeamResults\SeasonToDateMatchResults.csv"

# Download match results from web site:
Write-Host 'Downloading contents from web site...' -foregroundColor Green
$wc = New-Object System.Net.WebClient
[string] $pageContents = $wc.DownloadString($url)

# Save match results to file:
Write-Host 'Saving web page to a local file...' -foregroundColor Green
[System.IO.File]::WriteAllText( $matchResultsFileName, $pageContents )

# Get lookup data for data conversions:
$teams = import-csv "FL:\MasterData\$season\Teams.csv"

$teamCodeLookup = @{}
$teamNameLookup = @{}
$teams | % {
    $teamCodeLookup[$_.TeamName] = $_.TeamCode
    $teamNameLookup[$_.TeamName] = $_.TeamName
}
$teamCodeLookup.Force = 'WFR'
$teamNameLookup.Force = 'Western Force'

$fixtures = import-csv "FL:\MasterData\$season\Fixtures\Fixtures.csv" | select-object `
    @{ n='Round'; e={ [int]::Parse($_.Round) }},
    HomeTeamCode,
    AwayTeamCode,
    @{ n='FixtureDate'; e={ [DateTime]::Parse($_.FixtureDate) }} | ? {
        $_.Round -eq $round
    }
$expectedFixtureCount = $fixtures.Count

# Extracting data from web page:    
Write-Host 'Extracting match results for the current round from the web page...' -foregroundColor Green

$matchPattern = @'
(?x)
    <div\ class="r\d">
        <a\ href="/matches/rugby/match(?<MatchId>\d+)\.html">
            <strong>(?<HomeTeam>(?:(?!\ v\ ).)+)\ v\ (?<AwayTeam>(?:(?!</strong>).)+)</strong>
            ,\ Full\ Time\ (?<HomeScore>\d+)-(?<AwayScore>\d+)
        </a>
    </div>
'@

$roundPattern = @"
(?x)
<div\ class="m_h">
    <span>Round\ $round</span>
</div>\s*
<div\ class="m_b">\s*
    (?<Match>
        $matchPattern
        \s*
    )*
</div>
"@

# Match details sample:
# <tr class="r0"><td><strong>Weather:</strong> Fine</td><td><strong>Surface:</strong> Fine</td></tr>
# <tr class="r0"><td colspan="2"><strong>Referee:</strong> Steve Walsh &nbsp;<strong>
$matchDetailsPattern = '<tr\ class="r0"><td><strong>Weather:</strong>\s*(?<Weather>(?:(?!</td>).)*)</td><td><strong>Surface:</strong>\s*(?<Surface>(?:(?!</td>).)*)</td></tr>\s*<tr\ class="r0"><td\ colspan="2"><strong>Referee:</strong>\s*(?<Referee>(?:(?!(?:&nbsp;)?<strong>).)*)(?:&nbsp;)?<strong>'

if ($pageContents -notmatch $roundPattern)
{
    throw 'No match for round data!'
}
else
{
    $roundContents = $matches[0]
    $matchLines = $roundContents | split-string -newline
    $matchResultsThisRound = @(
        $matchLines | ? { 
            $_ -match $matchPattern
        } | % {
            # Calculate team codes of home and away teams:
            [string] $homeTeamName = $teamNameLookup[$matches.HomeTeam]
            [string] $awayTeamName = $teamNameLookup[$matches.AwayTeam]
            
            Write-Host "    Match between $homeTeamName and $awayTeamName" -foregroundColor Cyan
            
            [int] $homeScore = [int]::Parse( $matches.HomeScore )
            [int] $awayScore = [int]::Parse( $matches.AwayScore )
            [string] $homeTeamCode = $teamCodeLookup.$homeTeamName
            [string] $awayTeamCode = $teamCodeLookup.$awayTeamName
            [int] $matchId = [int]::Parse( $matches.MatchId )
            
            $fixture = $fixtures | ? { $_.Round -eq $round -and $_.HomeTeamCode -eq $homeTeamCode -and $_.AwayTeamCode -eq $awayTeamCode }
            if (-not $fixture)
            {
                Write-Warning "Could not find a fixture for the match between $homeTeamCode and $awayTeamCode"
                $date = [DateTime]::MinValue
            }
            else
            {
                $date = [DateTime]::Parse( $fixture.FixtureDate )
            }
            
            $newObject = new-object PSObject
            if ($homeScore -gt $awayScore) { $homeWin = 1 } else { $homeWin = 0 }
            if ($homeScore -eq $awayScore) { $homeDraw = 1 } else { $homeDraw = 0 }
            $awayDraw = $homeDraw
            $awayWin = 1 - $homeWin
            $referee = ''
            # Determine $referee
            # TODO: get from http://livescores.ninemsn.com.au/matches/rugby/match$($matchId).html
            # Also get: weather, surface, venue
            # Pattern: $matchDetailsPattern
            
            $newObject | add-Member NoteProperty Season $season
            $newObject | add-Member NoteProperty Round $round
            $newObject | add-Member NoteProperty DatePlayed $date
            $newObject | add-Member NoteProperty HomeTeamCode $homeTeamCode
            $newObject | add-Member NoteProperty HomeTeam $homeTeamName
            $newObject | add-Member NoteProperty HomeScore $homeScore
            $newObject | add-Member NoteProperty AwayTeam $awayTeamName
            $newObject | add-Member NoteProperty AwayTeamCode $awayTeamCode
            $newObject | add-Member NoteProperty AwayScore $awayScore
            $newObject | add-Member NoteProperty HomeWin $homeWin
            $newObject | add-Member NoteProperty HomeDraw $homeDraw
            $newObject | add-Member NoteProperty AwayWin $awayWin
            $newObject | add-Member NoteProperty AwayDraw $awayDraw
            $newObject | add-Member NoteProperty Referee $referee
            $newObject | add-Member NoteProperty MatchId $matchId
            $newObject
        }
    )
    
    if ($matchResultsThisRound.Count -ne $expectedFixtureCount)
    {
        Write-Warning "$($matchResultsThisRound.Count) match results found, but $expectedFixtureCount expected!"
    }
    
    # Save the current round's match results:
    Write-Host 'Saving the current round''s match results...' -foregroundColor Green
    $matchResultsThisRound | export-csv $matchResultsThisRoundFilePath -noTypeInformation
    
    # Generate the season to date match results:
    Write-Host 'Generating the season to date match results...' -foregroundColor Green
    if ($round -eq 1)
    {
        $seasonToDateMatchResults = $matchResultsThisRound
    }
    else
    {
        $seasonToDateMatchResults = import-csv $prevRoundMatchResultsFilePath
        $seasonToDateMatchResults = $seasonToDateMatchResults + $matchResultsThisRound
    }
    
    # Export the season to date match results:
    $seasonToDateMatchResults | export-csv $seasonToDateMatchResultsFilePath -noTypeInformation
    Write-Host "Exported the season to date match results to $seasonToDateMatchResultsFilePath" -foregroundColor Green
}

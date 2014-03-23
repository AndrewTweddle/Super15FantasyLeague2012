param ( 
    [string] $url = 'http://en.wikipedia.org/wiki/Super_rugby_2011'
)

$str = @'
<table cellspacing="0" style="width: 100%; background-color: transparent" class="vevent">
<tr class="summary">
<td width="15%" valign="top" align="right" rowspan="3">9 April 2011<br />
19:35</td>
<th width="24%" valign="top" align="right" class="vcard"><span class="fn org">Crusaders <span class="flagicon"><a href="/wiki/New_Zealand" title="New Zealand"><img alt="New Zealand" src="http://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/22px-Flag_of_New_Zealand.svg.png" width="22" height="11" class="thumbborder" /></a></span></span></th>
<th width="13%" valign="top" align="center">27–0</th>
<th width="24%" valign="top" align="left" class="vcard"><span class="fn org"><span class="flagicon"><a href="/wiki/South_Africa" title="South Africa"><img alt="South Africa" src="http://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Flag_of_South_Africa.svg/22px-Flag_of_South_Africa.svg.png" width="22" height="15" class="thumbborder" /></a></span> Bulls</span></th>
<td style="font-size: 85%" rowspan="2" valign="top"><span class="location"><a href="/wiki/Alpine_Energy_Stadium" title="Alpine Energy Stadium">Alpine Energy Stadium</a>, <a href="/wiki/Timaru" title="Timaru">Timaru</a></span><br />
Attendance: 11,000<br />
Referee: <span class="attendee">Jonathon White <span class="flagicon"><a href="/wiki/New_Zealand" title="New Zealand"><img alt="New Zealand" src="http://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/22px-Flag_of_New_Zealand.svg.png" width="22" height="11" class="thumbborder" /></a></span></span></td>
</tr>
<tr style="font-size:85%">
<td valign="top" align="right"><b>Try:</b> <a href="/wiki/Sonny_Bill_Williams" title="Sonny Bill Williams">Sonny Bill Williams</a>, <a href="/wiki/Israel_Dagg" title="Israel Dagg">Israel Dagg</a>, <a href="/w/index.php?title=Tom_Marshall_(rugby_union)&amp;action=edit&amp;redlink=1" class="new" title="Tom Marshall (rugby union) (page does not exist)">Tom Marshall</a><br />
<b>Pen:</b> <a href="/wiki/Matt_Berquist" title="Matt Berquist">Matt Berquist</a> (4)<br /></td>
<td valign="top" align="center"><a href="http://www.superxv.com/news/super15_rugby_news.asp?id=29705" class="external text" rel="nofollow">Report</a></td>
<td valign="top"></td>
</tr>
</table>
'@

$pattern1 = [regex]::Escape($str)

$fileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2011.htm'
$pageContents = [System.IO.File]::ReadAllText( $fileName )
$regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace

$pattern = @'
<table\ cellspacing="0"\ style="width:\ 100%;\ background-color:\ transparent"\ class="vevent">\n
    <tr\ class="summary">\n
        <td\ width="15%"\ valign="top"\ align="right"\ rowspan="3">
            (?<Date>(?:(?!<br).)+)<br\ />\n
            (?<Time>\d+:\d+)
        </td>\n
        <th\ width="24%"\ valign="top"\ align="right"\ class="vcard">
            <span\ class="fn\ org">\s*(?<HomeTeam>\w(?:\w|\s)+\w)\s*
                <span(?:(?!</span>).)+
                </span>
            </span>
        </th>\n
        <th\ width="13%"\ valign="top"\ align="center">(?<HomeScore>\d+)–(?<AwayScore>\d+)</th>\n
        <th\ width="24%"\ valign="top"\ align="left"\ class="vcard">
            <span\ class="fn\ org">
                <span(?:(?!</span>).)+
                </span>\s*(?<AwayTeam>\w(?:\w|\s)+\w)\s*
            </span>
        </th>\n?
        <td\ style="font-size:\ 85%"\ rowspan="2"\ valign="top">
            <span\ class="location">(?:(?!</span>).)+</span>
            <br\ />\n?
                (?:
                    (?:
                        Attendance:\ (?<Attendance>(?:\d|,)+)(?:(?!<br />).)*<br\ />
                    )
                    |
                    (?:
                        (?!Attendance)
                        (?<Attendance>)
                    )
                )
                (?:
                    (?:
                        \nReferee:\s*
                        (?:
                            <span\ class="attendee">
                                <a\ (?:(?!>).)+>\s*(?<Referee>(?:(?!\s*</a>).)+)\s*</a>\s*
                                (?:<span\ class="flagicon">(?:(?!</span>).)+</span>)?
                            </span>
                            |
                            <span\ class="attendee">
                                <span\ class="flagicon">(?:(?!</span>).)+</span>\s*
                                <a\ (?:(?!>).)+>\s*(?<Referee>(?:(?!\s*</a>).)+)\s*</a>
                            </span>
                            |
                            <span\ class="attendee">
                                (?!<a)(?<Referee>(?:(?!\s*<span>).)+)\s*
                                <span\ class="flagicon">(?:(?!</span>).)+</span>
                            </span>
                            |
                            <span\ class="attendee">
                                <span\ class="flagicon">(?:(?!</span>).)+</span>\s*
                                (?!<a)(?<Referee>(?:(?!</span>).)+)
                            </span>
                            |
                            <span\ class="attendee">
                                (?!<span)(?!<a)(?<Referee>(?:(?!</span>).)+)
                            </span>
                        )
                    )
                    |
                    (?:
                        (?!Referee)
                        (?<Referee>)
                    )
                )
        </td>\n?
    </tr>\n?
'@

# Convert following to regex as well to get the points scorers per side:
$pointScorers = @'
    <tr\ style="font-size:85%">\n
        <td\ valign="top"\ align="right">
            <b>Try:</b>\ 
                <a\ href="/wiki/Sonny_Bill_Williams"\ title="Sonny\ Bill\ Williams">Sonny\ Bill\ Williams</a>,\ 
                <a\ href="/wiki/Israel_Dagg"\ title="Israel\ Dagg">Israel\ Dagg</a>,\ 
                <a\ href="/w/index\.php\?title=Tom_Marshall_\(rugby_union\)&amp;action=edit&amp;redlink=1"\ class="new"\ title="Tom\ Marshall\ \(rugby\ union\)\ \(page\ does\ not\ exist\)">Tom\ Marshall</a><br\ />\n
            <b>Pen:</b>\ 
                <a\ href="/wiki/Matt_Berquist"\ title="Matt\ Berquist">Matt\ Berquist</a>\ \(4\)<br\ />
        </td>\n
        <td\ valign="top"\ align="center">
            <a\ href="http://www\.superxv\.com/news/super15_rugby_news\.asp\?id=29705"\ class="external\ text"\ rel="nofollow">Report</a>
        </td>\n
        <td\ valign="top"></td>\n
    </tr>\n
</table>
'@

$firstMonday = [datetime]::Parse('2011-02-14')
$weeks = 0..20 | % { $firstMonday.AddDays( 7 * $_ ) }

$regex = new-object System.Text.RegularExpressions.Regex -argumentList $pattern,$regexOptions
$m = $regex.Matches( $pageContents )
$results = $m | % {
    $dateString = $_.Groups['Date'].Value
    $date = [DateTime]::Parse($dateString)
    
    0..20 | % { if ($date -gt $weeks[$_]) { $round = $_ + 1 } }
    
    $newObject = new-object PSObject
    $homeScore = [int]::Parse($_.Groups['HomeScore'].Value)
    $awayScore = [int]::Parse($_.Groups['AwayScore'].Value)
    if ($homeScore -gt $awayScore) { $homeWin = 1 } else { $homeWin = 0 }
    if ($homeScore -eq $awayScore) { $homeDraw = 1 } else { $homeDraw = 0 }
    $awayDraw = $homeDraw
    $awayWin = 1 - $homeWin
    $referee = $_.Groups['Referee'].Value.Trim()
    $newObject | add-Member NoteProperty Round $round
    $newObject | add-Member NoteProperty DatePlayed $date
    $newObject | add-Member NoteProperty HomeTeam $_.Groups['HomeTeam'].Value 
    $newObject | add-Member NoteProperty HomeScore $homeScore
    $newObject | add-Member NoteProperty AwayTeam $_.Groups['AwayTeam'].Value 
    $newObject | add-Member NoteProperty AwayScore $awayScore
    $newObject | add-Member NoteProperty HomeWin $homeWin
    $newObject | add-Member NoteProperty HomeDraw $homeDraw
    $newObject | add-Member NoteProperty AwayWin $awayWin
    $newObject | add-Member NoteProperty AwayDraw $awayDraw
    $newObject | add-Member NoteProperty Referee $referee
    $newObject
}

$results.Count 
# TODO: Remove above after getting pattern working
# History (since 2011-11-20): 117, 123

# Use following to work way through, checking everything parses:
cls
$okayDate = [datetime]::Parse('2011-07-04')
$results | ? { $_.DatePlayed -ge $okayDate -and $_.DatePlayed -le $($okayDate.AddDays(7)) }

# Matches without referees recorded:
$results | ? { -not $_.Referee } | % { "$($_.DatePlayed.ToString('yyyy-MM-dd')): $($_.HomeTeam) vs $($_.AwayTeam)" }
# Save to file:
# $results | ? { -not $_.Referee } | select-object DatePlayed,HomeTeam,AwayTeam,Referee | export-csv fl:\PrevSeasonAnalysis\MatchResults\RefereesFor2011Matches.csv -noTypeInformation

# TODO: Also get stadium and city (latter for weather predictions)...

$homeAverages = $results | group-object HomeTeam | select-object Name,@{n='AverageScore';e={$_.Group | measure-object HomeScore -average | % { $_.Average } } } | sort-object Name
$awayAverages = $results | group-object AwayTeam | select-object Name,@{n='AverageScore';e={$_.Group | measure-object AwayScore -average | % { $_.Average } } } | sort-object Name
$homeAverages | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$awayAverages | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$homeAverages | sort-object AverageScore -descending | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$awayAverages | sort-object AverageScore -descending | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
# TODO: See why different, and what to do about it...
# $fileName = "flarchive:\2011\MatchResults\Super_rugby_2011.htm"
# $pageContents = [System.IO.File]::ReadAllText( $fileName )

$matchReferees = Import-Csv "fl:\PrevSeasonAnalysis\MatchResults\RefereesFor2011Matches.csv"
$matchReferees | % {
    $datePlayed = [datetime]::Parse( $_.DatePlayed )
    $homeTeam = $_.HomeTeam
    $awayTeam = $_.AwayTeam
    $referee = $_.Referee
    $results | ? { 
        ($_.DatePlayed -eq $datePlayed) -and ($_.HomeTeam -eq $homeTeam) -and ($_.AwayTeam -eq $awayTeam)
    } | % { 
        if ($_.Referee -ne '' -and $_.Referee -ne $referee)
        {
            Write-Warning "Match between $homeTeam and $awayTeam on $($datePlayed.ToString('yyyy-MM-dd')): replacing referee `"$($_.Referee)`" with `"$referee`""
        }
        $_.Referee = $referee
    }
}

$exportFileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2011.csv'
$results | export-csv $exportFileName -noTypeInformation

$exportFileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2011.RoundRobinOnly.csv'
$results[0..118] | export-csv $exportFileName -noTypeInformation

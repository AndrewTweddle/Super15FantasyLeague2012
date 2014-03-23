param ( 
    [string] $url = 'http://en.wikipedia.org/wiki/Super_rugby_2011'
)

$str = @'
<table cellspacing="0" class="collapsible collapsed" style="border-top:0px solid 000000; border-bottom:1px solid #e0e0e0; width: 100%; background-color:transparent">
<tr>
<td width="11%" valign="top" align="left" style="font-size:85%"></td>
<td width="12%" valign="top" align="right">2 April 2011</td>
<td width="22%" valign="top" align="right">Blues <span class="flagicon"><a href="/wiki/New_Zealand" title="New Zealand"><img alt="New Zealand" src="http://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/22px-Flag_of_New_Zealand.svg.png" width="22" height="11" class="thumbborder" /></a></span></td>
<td width="13%" valign="top" align="center"><b>29 – 22</b></td>
<td width="22%" valign="top" align="left"><span class="flagicon"><a href="/wiki/South_Africa" title="South Africa"><img alt="South Africa" src="http://upload.wikimedia.org/wikipedia/commons/thumb/a/af/Flag_of_South_Africa.svg/22px-Flag_of_South_Africa.svg.png" width="22" height="15" class="thumbborder" /></a></span> Cheetahs</td>
<td style="font-size: 85%" valign="top"><a href="/wiki/Okara_Park" title="Okara Park">Toll Stadium</a>, <a href="/wiki/Whangarei">Whangarei</a></td>
<th width="4%" valign="top" rowspan="2">&#160;</th>

</tr>
<tr style="font-size:85%">
<td width="11%" valign="top" align="left"></td>
<td valign="top" align="right">17:30</td>
<td valign="top" align="right"><b>Try:</b> <a href="/wiki/Joe_Rokocoko" class="mw-redirect" title="Joe Rokocoko">Joe Rokocoko</a>, <a href="/wiki/Stephen_Brett">Stephen Brett</a>, <a href="/wiki/Peter_Saili">Peter Saili</a>, <a href="/wiki/Isaia_Toeava">Isaia Toeava</a><br />
<b>Con:</b> <a href="/wiki/Luke_McAlister">Luke McAlister</a> (3)<br />

<b>Pen:</b> <a href="/wiki/Luke_McAlister">Luke McAlister</a><br /></td>
<td valign="top" align="center"><a href="http://www.superxv.com/news/super15_rugby_news.asp?id=29609" class="external text" rel="nofollow">Report</a></td>
<td valign="top" align="left"><b>Try:</b> <a href="/w/index.php?title=Sarel_Pretorius&amp;action=edit&amp;redlink=1" class="new" title="Sarel Pretorius (page does not exist)">Sarel Pretorius</a> (2), <a href="/w/index.php?title=Coenraad_Oosthuizen&amp;action=edit&amp;redlink=1" class="new" title="Coenraad Oosthuizen (page does not exist)">Coenraad Oosthuizen</a><br />
<b>Con:</b> <a href="/w/index.php?title=Naas_Olivier&amp;action=edit&amp;redlink=1" class="new" title="Naas Olivier (page does not exist)">Naas Olivier</a> (2)<br />

<b>Pen:</b> <a href="/w/index.php?title=Sias_Ebersohn&amp;action=edit&amp;redlink=1" class="new" title="Sias Ebersohn (page does not exist)">Sias Ebersohn</a><br /></td>
<td valign="top" rowspan="2" align="left">Attendance: 9,100<br />
Referee: <a href="/wiki/Bryce_Lawrence">Bryce Lawrence</a> <span class="flagicon"><a href="/wiki/New_Zealand" title="New Zealand"><img alt="New Zealand" src="http://upload.wikimedia.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand.svg/22px-Flag_of_New_Zealand.svg.png" width="22" height="11" class="thumbborder" /></a></span></td>
</tr>
</table>
'@

$pattern1 = [regex]::Escape($str)

# $url = 'http://en.wikipedia.org/wiki/Super_rugby_2011'
# $url = 'http://en.wikipedia.org/wiki/2010_Super_14_season'
# $webClient = new-object System.Net.WebClient
# $pageContents = $webClient.DownloadString( $url )

$pattern = '<table\ cellspacing="0"\ class="collapsible\ collapsed"\ style="border-top:0px\ solid\ 000000;\ border-bottom:1px\ solid\ \#e0e0e0;\ width:\ 100%;\ background-color:transparent">\n<tr>\n<td\ width="11%"\ valign="top"\ align="left"\ style="font-size:85%"></td>\n<td\ width="12%"\ valign="top"\ align="right">2\ April\ 2011</td>\n<td\ width="22%"\ valign="top"\ align="right">Blues\ <span\ class="flagicon"><a\ href="/wiki/New_Zealand"\ title="New\ Zealand"><img\ alt="New\ Zealand"\ src="http://upload\.wikimedia\.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand\.svg/22px-Flag_of_New_Zealand\.svg\.png"\ width="22"\ height="11"\ class="thumbborder"\ /></a></span></td>\n<td\ width="13%"\ valign="top"\ align="center"><b>29\ –\ 22</b></td>\n<td\ width="22%"\ valign="top"\ align="left"><span\ class="flagicon"><a\ href="/wiki/South_Africa"\ title="South\ Africa"><img\ alt="South\ Africa"\ src="http://upload\.wikimedia\.org/wikipedia/commons/thumb/a/af/Flag_of_South_Africa\.svg/22px-Flag_of_South_Africa\.svg\.png"\ width="22"\ height="15"\ class="thumbborder"\ /></a></span>\ Cheetahs</td>\n<td\ style="font-size:\ 85%"\ valign="top"><a\ href="/wiki/Okara_Park"\ title="Okara\ Park">Toll\ Stadium</a>,\ <a\ href="/wiki/Whangarei">Whangarei</a></td>\n<th\ width="4%"\ valign="top"\ rowspan="2">&\#160;</th>\n</tr>\n<tr\ style="font-size:85%">\n<td\ width="11%"\ valign="top"\ align="left"></td>\n<td\ valign="top"\ align="right">17:30</td>\n<td\ valign="top"\ align="right"><b>Try:</b>\ <a\ href="/wiki/Joe_Rokocoko"\ class="mw-redirect"\ title="Joe\ Rokocoko">Joe\ Rokocoko</a>,\ <a\ href="/wiki/Stephen_Brett">Stephen\ Brett</a>,\ <a\ href="/wiki/Peter_Saili">Peter\ Saili</a>,\ <a\ href="/wiki/Isaia_Toeava">Isaia\ Toeava</a><br\ />\n<b>Con:</b>\ <a\ href="/wiki/Luke_McAlister">Luke\ McAlister</a>\ \(3\)<br\ />\n<b>Pen:</b>\ <a\ href="/wiki/Luke_McAlister">Luke\ McAlister</a><br\ /></td>\n<td\ valign="top"\ align="center"><a\ href="http://www\.superxv\.com/news/super15_rugby_news\.asp\?id=29609"\ class="external\ text"\ rel="nofollow">Report</a></td>\n<td\ valign="top"\ align="left"><b>Try:</b>\ <a\ href="/w/index\.php\?title=Sarel_Pretorius&amp;action=edit&amp;redlink=1"\ class="new"\ title="Sarel\ Pretorius\ \(page\ does\ not\ exist\)">Sarel\ Pretorius</a>\ \(2\),\ <a\ href="/w/index\.php\?title=Coenraad_Oosthuizen&amp;action=edit&amp;redlink=1"\ class="new"\ title="Coenraad\ Oosthuizen\ \(page\ does\ not\ exist\)">Coenraad\ Oosthuizen</a><br\ />\n<b>Con:</b>\ <a\ href="/w/index\.php\?title=Naas_Olivier&amp;action=edit&amp;redlink=1"\ class="new"\ title="Naas\ Olivier\ \(page\ does\ not\ exist\)">Naas\ Olivier</a>\ \(2\)<br\ />\n<b>Pen:</b>\ <a\ href="/w/index\.php\?title=Sias_Ebersohn&amp;action=edit&amp;redlink=1"\ class="new"\ title="Sias\ Ebersohn\ \(page\ does\ not\ exist\)">Sias\ Ebersohn</a><br\ /></td>\n<td\ valign="top"\ rowspan="2"\ align="left">Attendance:\ 9,100<br\ />\nReferee:\ <a\ href="/wiki/Bryce_Lawrence">Bryce\ Lawrence</a>\ <span\ class="flagicon"><a\ href="/wiki/New_Zealand"\ title="New\ Zealand"><img\ alt="New\ Zealand"\ src="http://upload\.wikimedia\.org/wikipedia/commons/thumb/3/3e/Flag_of_New_Zealand\.svg/22px-Flag_of_New_Zealand\.svg\.png"\ width="22"\ height="11"\ class="thumbborder"\ /></a></span></td>\n</tr>\n</table>'

$pattern = @'
<tr>\r?\n
<td\ width="11%"\ valign="top"\ align="left"\ style="font-size:85%"></td>\r?\n
<td\ width="12%"\ valign="top"\ align="right">
(?<Date>(?:(?!</td>).)+)</td>\r?\n
<td\ width="22%"\ valign="top"\ align="right">
(?<HomeTeam>(?:(?!\ <span).)+)\ <span\ (?:(?!</span>).)+</span>
</td>\r?\n
<td\ width="13%"\ valign="top"\ align="center"><b>
(?<HomeScore>\d+)\ (?:â€“|-)\ (?<AwayScore>\d+)
</b></td>\r?\n
<td\ width="22%"\ valign="top"\ align="left"><span\ (?:(?!</span>).)+</span>
\ (?<AwayTeam>(?:(?!</td>).)+)</td>
'@

# better...
$pattern = @'
<tr>\r?\n
<td\ width="11%"\ valign="top"\ align="left"\ style="font-size:85%"></td>\r?\n
<td\ width="12%"\ valign="top"\ align="right">
(?<Date>(?:(?!</td>).)+)</td>\r?\n
<td\ width="22%"\ valign="top"\ align="right">
(?<HomeTeam>(?:(?!\ <span).)+)\ <span\ (?:(?!</span>).)+</span>
</td>\r?\n
<td\ width="13%"\ valign="top"\ align="center"><b>
(?<HomeScore>\d+)\ ?(?:(?!\d).)+(?<AwayScore>\d+)
</b></td>\r?\n
<td\ width="22%"\ valign="top"\ align="left"><span\ (?:(?!</span>).)+</span>
\ (?<AwayTeam>(?:(?!</td>).)+)</td>
'@

# new pattern, to get referee too:
$pattern = @'
<tr>\r?\n
<td\ width="11%"\ valign="top"\ align="left"\ style="font-size:85%"></td>\r?\n
<td\ width="12%"\ valign="top"\ align="right">
(?<Date>(?:(?!</td>).)+)</td>\r?\n
<td\ width="22%"\ valign="top"\ align="right">
(?<HomeTeam>(?:(?!\ <span).)+)\ <span\ (?:(?!</span>).)+</span>
</td>\r?\n
<td\ width="13%"\ valign="top"\ align="center"><b>
(?<HomeScore>\d+)\ ?(?:(?!\d).)+(?<AwayScore>\d+)
</b></td>\r?\n
<td\ width="22%"\ valign="top"\ align="left"><span\ (?:(?!</span>).)+</span>
\ (?<AwayTeam>(?:(?!</td>).)+)</td>
(?:(?!</tr>).|\r|\n)+(?:\s|\r|\n)*
</tr>
(?:(?!</tr>|Referee:).|\r|\n)+
(?:
Referee:\s*
    (?:
        (?:
            <span (?:(?!</span>).|\r|\n)+</span>\s*
            (?:
                (?<Referee>\w(?:(?!</td>).|\r|\n)+)
                |
                (?:
                    \s*<a (?:(?!>).)+>\s*
                        (?<Referee>(?:(?!</a>).)+)
                    </a>
                )
            )
        )
        |
        (
            <a (?:(?!>).)+>\s*
                (?<Referee>(?:(?!</a>).)+)
            </a>\s*
            <span (?:(?!</span>).|\r|\n)+</span>\s*
        )
    )
</td>
)?
'@

$firstMonday = [DateTime]::Parse('2010-02-08')
$weeks = 0..20 | % { $firstMonday.AddDays( 7 * $_ ) }

$fileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2010.htm'
$pageContents = [System.IO.File]::ReadAllText( $fileName )
$regexOptions = [System.Text.RegularExpressions.RegexOptions]::IgnorePatternWhitespace
$regex = new-object System.Text.RegularExpressions.Regex -argumentList $pattern,$regexOptions
$m = $regex.Matches( $pageContents )
$results = $m | % { 
    $date = [DateTime]::Parse($_.Groups['Date'].Value)
    0..20 | % { if ($date -gt $weeks[$_]) { $round = $_ + 1 } }
    
    $newObject = new-object PSObject
    $homeScore = [int]::Parse($_.Groups['HomeScore'].Value)
    $awayScore = [int]::Parse($_.Groups['AwayScore'].Value)
    if ($homeScore -gt $awayScore) { $homeWin = 1 } else { $homeWin = 0 }
    if ($homeScore -eq $awayScore) { $homeDraw = 1 } else { $homeDraw = 0 }
    $awayDraw = $homeDraw
    $awayWin = 1 - $homeWin
    
    $referee = $_.Groups['Referee'].Value.Trim()
    $replacedByPos = $referee.IndexOf(' replaced by ')
    if ($replacedByPos -gt 0)
    {
        $referee = $referee.SubString(0, $replacedByPos + 1).Trim()
    }
    
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

$homeAverages = $results | group-object HomeTeam | select-object Name,@{n='AverageScore';e={$_.Group | measure-object HomeScore -average | % { $_.Average } } } | sort-object Name
$awayAverages = $results | group-object AwayTeam | select-object Name,@{n='AverageScore';e={$_.Group | measure-object AwayScore -average | % { $_.Average } } } | sort-object Name
$homeAverages | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$awayAverages | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$homeAverages | sort-object AverageScore -descending | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
$awayAverages | sort-object AverageScore -descending | % { "{0,20} {1,5:##0.00}" -f @($_.Name,$_.AverageScore) }
# TODO: See why different, and what to do about it...
# $fileName = "flarchive:\2011\MatchResults\Super_rugby_2011.htm"
# $pageContents = [System.IO.File]::ReadAllText( $fileName )

$exportFileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2010.csv'
$results | export-csv $exportFileName -noTypeInformation

$exportFileName = 'fl:\PrevSeasonAnalysis\MatchResults\Super_rugby_2010.RoundRobinOnly.csv'
$results[0..90] | export-csv $exportFileName -noTypeInformation

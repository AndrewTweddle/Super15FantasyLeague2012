param (
    [string] $homePredictionsFilePath = 'FL:\RScripts\ScratchPad\Results\Test\glm.nb.TotalPointsScored.Home.NoReferees.PredProb.csv',
    [string] $awayPredictionsFilePath = 'FL:\RScripts\ScratchPad\Results\Test\glm.nb.TotalPointsScored.Away.NoReferees.PredProb.csv',
    [string] $predictionsFilePath = 'FL:\RScripts\ScratchPad\Results\Test\glm.nb.TotalPointsScored.NoReferees.Predictions.csv'
)

$predictions = import-csv $predictionsFilePath
$ppHome = import-csv $homePredictionsFilePath
$ppAway = import-csv $awayPredictionsFilePath

$maxRowNumber = 5  # TODO: ($ppHome.Count - 1)

0..$maxRowNumber | % {
    $matchIndex = $_
    $winProb = 0.0
    
    if ($matchIndex % 2 -eq 0)
    {
        Write-Host '======================================================================='
        
        $homeTeamPrediction = $predictions[$matchIndex]
        $awayTeamPrediction = $predictions[$matchIndex + 1]
        $homeTeamCode = $homeTeamPrediction.TeamCode
        $awayTeamCode = $awayTeamPrediction.TeamCode
        
        $ppHomeForMatch = $ppHome[ $matchIndex ]
        $ppAwayForMatch = $ppAway[ $matchIndex + 1 ]
        
        $matchIndex = $matchIndex / 2 + 1
        Write-Host "Calculation for home team $homeTeamCode in match $matchIndex against $awayTeamCode :" -foregroundColor Green
        $h = 0..53 | % {
            $score = $_
            $probOfScore = $ppHomeForMatch.$score
            try
            {
                [double]::Parse( $probOfScore ) 
            }
            catch
            {
                Write-Error "Could not parse $probOfScore for home team score of $score in match $matchIndex"
            }
        }
        $a = 0..53 | % { [double]::Parse( $ppAwayForMatch.$_ ) }
        $winProb = 0.0
        1..53 | % {
            $homePoints = $_
            $homeProbability = $h[$homePoints]
            Write-Host "        Probability of home team scoring $homePoints is $homeProbability" -foregroundColor Yellow
            $awayProbabilityLess = 0.0
            0..($homePoints-1) | % {
                $awayProbabilityLess += $a[$_]
            }
            Write-Host "        Probability of away team scoring less than $homePoints is $awayProbabilityLess" -foregroundColor Gray
            $probWinWithHomePoints = $homeProbability * $awayProbabilityLess
            Write-Host "        Probability of home team winning with $homePoints is $probWinWithHomePoints" -foregroundColor Magenta
            $winProb += $probWinWithHomePoints
            Write-Host "        Probability of home team winning with $homePoints or less is $winProb" -foregroundColor White
            Write-Host
        }
        Write-Host "    Probability of home team winning is $winProb" -foregroundColor Cyan
    }
    else
    {
        Write-Host '----------------------------------------------------------------------='
        
        $homeTeamPrediction = $predictions[$matchIndex - 1]
        $awayTeamPrediction = $predictions[$matchIndex]
        $homeTeamCode = $homeTeamPrediction.TeamCode
        $awayTeamCode = $awayTeamPrediction.TeamCode
        
        $ppHomeForMatch = $ppHome[ $matchIndex - 1 ]
        $ppAwayForMatch = $ppAway[ $matchIndex ]
        
        $matchIndex = ($matchIndex + 1 )/ 2
        Write-Host "Calculation for away team $awayTeamCode in match $matchIndex against $homeTeamCode :" -foregroundColor Cyan
        
        $h = 0..53 | % {
            $score = $_
            $probOfScore = $ppHomeForMatch.$score
            try
            {
                [double]::Parse( $probOfScore ) 
            }
            catch
            {
                Write-Error "Could not parse $probOfScore for home team score of $score in match $matchIndex"
            }
        }
        $a = 0..53 | % { [double]::Parse( $ppAwayForMatch.$_ ) }
        
        $winProb = 0.0
        1..53 | % {
            $awayPoints = $_
            $awayProbability = $a[$awayPoints]
            Write-Host "        Probability of away team scoring $awayPoints is $awayProbability" -foregroundColor Yellow
            $homeProbabilityLess = 0.0
            0..($awayPoints-1) | % {
                $homeProbabilityLess += $h[$_]
            }
            Write-Host "        Probability of home team scoring less than $awayPoints is $homeProbabilityLess" -foregroundColor Gray
            $probWinWithAwayPoints = $awayProbability * $homeProbabilityLess
            Write-Host "        Probability of away team winning with $awayPoints is $probWinWithAwayPoints" -foregroundColor Magenta
            $winProb += $probWinWithAwayPoints
            Write-Host "        Probability of away team winning with $awayPoints or less is $winProb" -foregroundColor White
            Write-Host
        }
        Write-Host "    Probability of away team winning is $winProb" -foregroundColor Cyan
    }
    Write-Host
}

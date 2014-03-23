[string] $csvFilePath = 'fl:\PrevSeasonAnalysis\EstimationModels\EstimationModelUsedIn2011\SourceData\PlayerEstimationModelCopiedFromExcelSpreadsheet.csv'
$records = import-csv $csvFilePath
[string] $outputPath = 'fl:\PrevSeasonAnalysis\EstimationModels'

# Standard estimation file format:
# 
# File for player and upcoming round N is named: <PlayerName>_AfterRound<N>_EstimatedScoresForFutureRounds.csv
# 
# Columns are: FullName,Round,PredictedPrice,PredictedAppearanceScore,PredictedTeamResultScore,PredictedNonKickingScore,PredictedKickingScore,PredictedCaptainScore
# These are for that component only (i.e. PredictedNonKickingScore excludes PredictedAppearancePoints and PredictedTeamResultScore)
# 
$propertyNames = @(
    'FullName',
    'Round',
    'PredictedPrice',
    'PredictedAppearanceScore',
    'PredictedTeamResultScore',
    'PredictedNonKickingScore',
    'PredictedKickingScore',
    'PredictedCaptainScore'
)

$records | % {
    $record = $_
    [int] $roundsCompleted = [int]::Parse( $record.Round )
    [int] $upcomingRound = $roundsCompleted + 1
    
    if ($roundsCompleted -ne 21)
    {
        $fullName = $record.FullName
        $PredictedPrice = [double]::Parse( $record.Price )
        
        $estimates = $upcomingRound..21 | % {
            $round = $_
            
            $propertyName = "ProbabilityPlayerWillPlayThisRound_Round$round"
            $willPlay = ($record.$propertyName -ne '0%')
            
            if ($willPlay)
            {
                $PredictedAppearanceScore = [double]::Parse( $record.Appearance )
                
                $propertyName = "EstimatedTeamPoints_Round$round"
                $PredictedTeamResultScore = [double]::Parse( $record.$propertyName )
                
                $propertyName = "R$($round)_PlayerScorePerRound"
                $playerScoreForRound = [double]::Parse( $record.$propertyName )
                $PredictedNonKickingScore = $playerScoreForRound - $predictedAppearanceScore - $PredictedTeamResultScore
                
                $propertyName = "R$($round)_KickerScorePerRound"
                $PredictedKickingScore = [double]::Parse( $record.$propertyName ) - $playerScoreForRound
                
                $PredictedCaptainScore = $predictedAppearanceScore + $predictedTeamResultScore + $PredictedNonKickingScore
            }
            else
            {
                $PredictedAppearanceScore = 0.0
                $PredictedTeamResultScore = 0.0
                $PredictedNonKickingScore = 0.0
                $PredictedKickingScore = 0.0
                $PredictedCaptainScore = 0.0
            }
            
            $estimate = new-object PSObject
            $propertyNames | % {
                $value = (Get-Variable $_).Value
                $estimate | Add-Member NoteProperty $_ -Value $value
            }
            $estimate
        }
        
        # Write outputs to csv file:
        $outputFileName = "$outputPath\EstimationModelUsedIn2011\$($fullName)_AfterRound$($roundsCompleted)_EstimatedScoresForFutureRounds.csv"
        $estimates | export-csv $outputFileName -noTypeInformation
    }
}

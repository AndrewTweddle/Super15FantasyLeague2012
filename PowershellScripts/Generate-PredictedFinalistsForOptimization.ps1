param (
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $optimizationModelSubPath = $( read-host 'Model sub-path (without leading or trailing slashes)' ),
    [string] $forecastingModel = 'NegBin'
)

# Input file paths:
[string] $predictedFinalLogTableFilePath = "FL:\DataByRound\Round$upcomingRound\Forecasts\$forecastingModel\PredictedFinalLogTable_$($forecastingModel).csv"

# Output file paths:
[string] $predictedFinalistsFilePath = "FL:\DataByRound\Round$upcomingRound\OptimisationModels\$optimizationModelSubPath\PredictedFinalists.csv"

# Calculate positions:
$teams = import-csv "FL:\MasterData\Global\Teams.csv"

$predictedFinalLogTableWithPositions = import-csv $predictedFinalLogTableFilePath `
    | select-object `
        TeamCode,`
        @{ n='ConferenceCode'
           e={ 
                $teamCode = $_.TeamCode
                $teams | ? { $_.TeamCode -eq $teamCode} | % { $_.ConferenceCode } 
             }
        }, `
        @{ n='PredictedLogPoints'
           e={ [double]::Parse($_.PredictedLogPoints) }
         }, `
        @{ n='Position'; e={ 0 }}, `
        @{ n='AdjustedPosition'; e={ 0 }}

$conferenceGroupings = $predictedFinalLogTableWithPositions | Group-Object ConferenceCode
$conferenceLeaders = $conferenceGroupings | % {
    $conferenceCode = $_.Name
    $leader = $_.Group | sort-object PredictedLogPoints -descending | select-object -first 1
    $leader
}

# Set the positions (ignoring conference):
[int] $position = 1
$predictedFinalLogTableWithPositions | ? { $_.Position -eq 0 } | sort-object PredictedLogPoints -descending | % {
    $_.Position = $position
    $position++
}

# Set the adjusted positions (taking conference into account, so that each conference has a team in the top 3):
[int] $adjustedPosition = 1
$conferenceLeaders | sort-object PredictedLogPoints -descending | % {
    $_.AdjustedPosition = $adjustedPosition
    $adjustedPosition++
}

$predictedFinalLogTableWithPositions | ? { $_.AdjustedPosition -eq 0 } | sort-object PredictedLogPoints -descending | % {
    $_.AdjustedPosition = $adjustedPosition
    $adjustedPosition++
}

# Calculate the predicted finalists:
$predictedFinalists = 1..6 | % {
    $position = $_
    $teamCode = $predictedFinalLogTableWithPositions | ? { $_.Position -eq $position } | % { $_.TeamCode }
    $adjustedTeamCode = $predictedFinalLogTableWithPositions | ? { $_.AdjustedPosition -eq $position } | % { $_.TeamCode }
    new-object PSObject -property @{
        Position = $position
        TeamCode = $teamCode
        AdjustedTeamCode = $adjustedTeamCode
    }
}

# Export results:
$predictedFinalists | export-csv $predictedFinalistsFilePath -noTypeInformation

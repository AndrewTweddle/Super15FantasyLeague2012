param (
    [int] $season = $( read-host 'Season' ),
    [int] $upcomingRound = $( read-host 'Upcoming round' ),
    [string] $optimizationModelSubPath = 'SingleForwardRun',
    [int[]] $roundsAheadToGenerateScriptsFor = @(  7, 8, 9, 10, 11, 12, 13, 14 ),
    [int[]] $transferOffsets = @( 0, -1, -2, 1, 2, 3, 4 ),
    [switch] $reduceAll = $false
)

# Input paths:
[string] $transfersFilePath = "FL:\DataByRound\Round$upcomingRound\Inputs\Transfers.csv"
[string] $budgetFilePath = "FL:\DataByRound\Round$($upcomingRound-1)\FantasyTeamResults\FantasyTeamBudgetByRound.csv"

# Output paths:
[string] $scriptFilePath = join-path $( convert-path "FL:\DataByRound\Round$upcomingRound\PowershellScripts" ) "Run-OptimizationModels.ps1"

# Load input data:
$transfers = import-csv $transfersFilePath `
    | select-object @{
            n='UpcomingRound'
            e={ [int]::Parse($_.UpcomingRound) }
        }, 
        @{
            n='CumTransfersAvailable'
            e={ [int]::Parse( $_.CumTransfersAvailable ) }
        }

$lastBudgetRecord = import-csv $budgetFilePath `
    | select-object @{
            n='RoundCompleted'
            e={ [int]::Parse( $_.RoundCompleted ) }
        }, `
        @{
            n='Budget'
            e={ [double]::Parse( $_.Budget ) }
        } `
    | ? {
        $_.RoundCompleted -eq $upcomingRound - 1
    }

[double] $budget = $lastBudgetRecord.Budget

# Generate commands:
$commands = $transferOffsets | % {
    $transferOffset = $_
    $roundsAheadToGenerateScriptsFor | % {
        $roundOffset = $_
        $maxRound = $upcomingRound + $roundOffset - 1
        if ($maxRound -le 21)
        {
            $transfersString = ''
            [string[]] $transfersInWindow = $transfers | ? {
                ($_.UpcomingRound -ge $upcomingRound) -and ($_.UpcomingRound -le $maxRound)
            } | % {
                if ($transferOffset -ge 0)
                {
                    # If increasing transfers, increase them in every round:
                    $cumTransfersAvailable = $_.CumTransfersAvailable + $transferOffset
                }
                elseif ($reduceAll -or ($_.UpcomingRound -eq $maxRound))
                {
                    # If reducing transfers, and -reduceAll is not specified, then only reduce the last transfer constraint:
                    $cumTransfersAvailable = [Math]::Max( 0, $_.CumTransfersAvailable + $transferOffset )
                }
                else
                {
                    # If reducing transfers, don't reduce any but the last transfer constraint:
                    $cumTransfersAvailable = $_.CumTransfersAvailable
                }
                
                if ($transfersString)
                {
                    $transfersString = "$transfersString,$($_.UpcomingRound),$cumTransfersAvailable"
                }
                else
                {
                    $transfersString = "$($_.UpcomingRound),$cumTransfersAvailable"
                }
            }
            # $transfersString = join-string -strings $transfersInWindow -separator ','
            
            $expandedOptimizationModelSubPath = "$optimizationModelSubPath$($roundOffset)Rounds"
            
            if ($transferOffset -eq 0)
            {
                $suffix = ''
            }
            elseif ($transferOffset -gt 0)
            {
                $suffix = "_Plus$($transferOffset)Transfers"
            }
            else
            {
                $suffix = "_Less$(-$transferOffset)Transfers"
            }
            $expandedOptimizationModelSubPath = "$($expandedOptimizationModelSubPath)$suffix"
            $command = ". FL:\PowershellScripts\Invoke-Optimization.ps1 $expandedOptimizationModelSubPath $season $upcomingRound $maxRound $budget '$transfersString'"
            $command
        }
    }
    
    # Add a separator:
    ''
}

[string] $scriptFileContents = join-string -Strings $commands -newLine

# Save script:
[System.IO.File]::WriteAllText( $scriptFilePath, $scriptFileContents )

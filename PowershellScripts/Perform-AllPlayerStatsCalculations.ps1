param (
    [int] $roundForGeneratingPlayerStatsFor2012Season = 0
)

Invoke-PromptingAction 'Perform all player stats calculations' {
    Invoke-PromptingAction 'Extract player stats by round' {
        . fl:\PowershellScripts\Extract-PlayerStatsByRound.ps1
    }
    Invoke-PromptingAction 'Save all player stats to a single file' {
        . fl:\PowershellScripts\Aggregate-PlayerStatsByRound.ps1
    }
    Invoke-PromptingAction 'Generate players for 2010 season' {
        . fl:\PowershellScripts\Get-PlayersFor2010Season.ps1 | out-null
    }
    Invoke-PromptingAction 'Generate players for 2011 season' {
        . fl:\PowershellScripts\Generate-PlayersForSeason.ps1
    }
    Invoke-PromptingAction 'Generate Players for 2012 season' {
        . fl:\PowershellScripts\Generate-PlayersForSeasonFromDownloadedPlayerStats.ps1 `
            -round $roundForGeneratingPlayerStatsFor2012Season
    }

    # After match results also calculated:
    Invoke-PromptingAction 'Calculate results by team and round' {
        . fl:\PowershellScripts\Calculate-ResultsByTeamAndRound.ps1
    }
    
    Invoke-PromptingAction 'Calculate aggregate statistics per team' {
        FL:\PowershellScripts\Calculate-TeamAggregatesForSeason.ps1
    }

    Invoke-PromptingAction 'Calculate aggregate statistics per player' {
        FL:\PowershellScripts\Calculate-PlayerAggregatesForSeason.ps1
    }
}

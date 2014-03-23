param (
    [string] $playerStatsFor2010SeasonFilePath = 'FLArchive:\2011\PlayerStats2010\PlayerStats2010.csv',
    [string] $playersFilePath = 'FL:\MasterData\2010\Players\Players.csv'
)

# =================
# Load master data:
# 
$positions = import-csv fl:\MasterData\Global\Positions.csv

# Create mappings for teams to team codes, since western force wasn't listed under its own code yet:
$teams = import-csv FL:\MasterData\Global\Teams.csv
$teamCodeMappings = @{}
$teams | % {
    $teamCodeMappings[$_.TeamCode] = $_.TeamCode
}
$teamCodeMappings['westernforce'] = 'WFR'

# ==============================
# Load and convert player stats:
# 
$playerStats = import-csv $playerStatsFor2010SeasonFilePath

$players = $playerStats | select-object `
    @{ n='PlayerName'; e={ $_.FullName }}, `
    @{ n='TeamCode'; e={ $teamCodeMappings[$_.Team] }}, `
    @{ n='PositionCode'; e={ $_.Position }}, `
    @{n='PositionType'; e={ $positionCode = $_.Position; ($positions | ? { $_.PositionCode -eq $positionCode }).PositionType }}, `
    @{n='Rookie'; e={ 'X' }}  # Y = yes, N = no, X = unknown

$players | export-csv $playersFilePath -noTypeInformation

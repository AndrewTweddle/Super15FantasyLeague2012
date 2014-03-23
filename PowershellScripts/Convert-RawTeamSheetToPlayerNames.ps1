param (
    [string] $splitPattern = '\s*(?:\(WTG\)\s*|\(v?c\)\s*)?(?:,\s*)?\d+\.?\s*',  # Alternately: '\s*,\s*'
    [string] $rawTeamSheet = $( get-clipboard )
)

$players = $rawTeamSheet -split $splitPattern | ? { $_ }

if ($players)
{
    $players
    $players | out-clipboard
}
else
{
    throw 'No player strings found'
}

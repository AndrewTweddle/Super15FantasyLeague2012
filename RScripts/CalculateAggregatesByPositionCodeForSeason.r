library(stats)

# ====================
# Initialize settings:
# 

# Input paths:

# playerStatsFilePath <- "C:\\FantasyLeague\\PrevSeasonAnalysis\\PlayerStats\\AllPlayerStats.csv"
aggregateStatsByPlayerFilePath <- "C:\\FantasyLeague\\PrevSeasonAnalysis\\PlayerStats\\AggregateStatsByPlayer.csv"

# Output paths:

aggregateStatsByPositionFilePath = "C:\\FantasyLeague\\PrevSeasonAnalysis\\PlayerStats\\AggregateStatsByPosition.csv"

# Load data
# playerStats <- read.table( playerStatsFilePath, header=TRUE, sep=",")
# playerStats <- subset( playerStats, (FullAppearance == 1) | (PartAppearance == 1) )

aggregateStatsByPlayer <- read.table( aggregateStatsByPlayerFilePath, header=TRUE, sep=",")
aggregateStatsByPlayer <- subset( aggregateStatsByPlayer, GamesPlayed != 0 )

# ========================================================
# Analyze data:
#

# -----------------------------------------
# Get average points per match by position:
#

# attach(playerStats)

# head(playerStats)

# agg <- aggregate( 
#     formula =
#         cbind( FullAppearance, PartAppearance, Tries, Assists, Penalties, DropGoals, YellowCard, RedCard) 
#         ~ Position, 
#     FUN = mean,
#     data=playerStats
# )

# The problem here is that there are multiple players per position!

# head(agg)

# detach()

# -----------------------------------------------------
# Get average proportion of team's points per position:
# 

attach( aggregateStatsByPlayer )

aggregateStatsByPosition <- aggregate(
    formula =
        cbind( FullAppearanceRatio, PartAppearanceRatio, 
               TriesPerGame, AssistsPerGame, PenaltiesPerGame, DropGoalsPerGame, YellowCardsPerGame, RedCardsPerGame,
               ProportionOfTeamTriesPerGame, ProportionOfTeamAssistsPerGame, ProportionOfTeamConversionsPerGame, 
               ProportionOfTeamPenaltiesPerGame
             )
        ~ PositionCode,
    FUN = mean,
    data=aggregateStatsByPlayer
)

detach()

# aggregateStatsByPosition <- merge( agg2, agg, by.x="PositionCode", by.y="Position", all=TRUE, sort=TRUE)

# ---------------------------
# Write outputs to csv files:
# 
write.csv(aggregateStatsByPosition, file=aggregateStatsByPositionFilePath, row.names=FALSE)

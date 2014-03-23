# TODO's:
# -------
# 
# 1. Read in and use weightings file
#

# ================================================================
# Load required libraries:
# 
library(stats)

# ================================================================
# Initialize various settings:
# 
# The command line arguments (after --args switch) are:
#    1: season          (default 2012)
#    2: upcoming round  (default 1)

args <- commandArgs(TRUE)

if (length(args) >= 1)
{
    season <- as.integer( args[1] )
} else
{
    season <- 2012
}

if (length(args) >= 2)
{
    upcomingRound <- as.integer( args[2] )
} else
{
    upcomingRound <- 1
}


# =================================
# Initialize file and folder paths:
# 

# Input paths:
aggregateStatsByPlayerFilePath <- paste( "C:\\FantasyLeague\\DataByRound\\Round", upcomingRound, "\\Inputs\\AggregateStatsByPlayer.csv", sep="")

# Output paths:

aggregateStatsByPositionFilePath = paste( "C:\\FantasyLeague\\DataByRound\\Round", upcomingRound, "\\Inputs\\AggregateStatsByPosition.csv", sep="")

# Load data
# playerStats <- read.table( playerStatsFilePath, header=TRUE, sep=",")
# playerStats <- subset( playerStats, (FullAppearance == 1) | (PartAppearance == 1) )

aggregateStatsByPlayer <- read.table( aggregateStatsByPlayerFilePath, header=TRUE, sep=",")
aggregateStatsByPlayer <- subset( aggregateStatsByPlayer, GamesPlayed != 0 )

# ========================================================
# Analyze data:
#

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

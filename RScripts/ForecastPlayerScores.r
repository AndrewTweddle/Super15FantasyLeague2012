# ================================================================
# Initialize various settings:
# 
# The command line arguments (after --args switch) are:
#    1: season          (default 2012)
#    2: upcoming round  (default 1)
#    3: model to use    (default "NegBin")
# 
# TODO:
#    1. KickerRules.csv uses EventTypeCode instead of EventCode. Fix the source data and this script.
# 

cat("Reading arguments...", fill=TRUE)

args <- commandArgs(TRUE)

if (length(args) >= 1)
{
    seasonToForecastFor <- as.integer( args[1] )
} else
{
    seasonToForecastFor <- 2012
}

if (length(args) >= 2)
{
    roundToForecastFor <- as.integer( args[2] )
} else
{
    roundToForecastFor <- 1
}

if (length(args) >= 3)
{
    model <- args[3]
} else
{
    model <- "NegBin"
    # Options: 
    #    model <- "lm"
    #    model <- "NegBin"
    #    model <- "poisson"
    #    model <- "binomial"
}


# ===============================
# Generate folder and file paths:
# 
cat("Generating folder and file paths...", fill=TRUE)
            
seasonMasterDataFolderPath <- paste( "C:\\FantasyLeague\\MasterData\\", seasonToForecastFor, "\\", sep="")

upcomingRoundFolderPath <- paste( "C:\\FantasyLeague\\DataByRound\\Round", roundToForecastFor, "\\", sep="")
inputsFolderPath <- paste( upcomingRoundFolderPath, "Inputs\\", sep="")
parametersFolderPath <- paste( upcomingRoundFolderPath, "Parameters\\", sep="")
forecastsFolderPath <- paste( upcomingRoundFolderPath, "Forecasts\\", model, "\\", sep="")

# Redirect console to a file (as well as the console):
sinkFilePath <- paste( forecastsFolderPath, "sink_", model, "_PlayerForecast.txt", sep="")
sink(file = sinkFilePath, split=TRUE, type="output")

# Input file paths:
playersFilePath <- paste( inputsFolderPath, "PlayerPrices.csv", sep="")
futureTeamFixturesFilePath <- paste( inputsFolderPath, "FutureTeamFixtures.csv", sep="" )
matchForecastsFilePath <- paste( forecastsFolderPath, "Forecasts_", model, ".csv", sep="")
aggregateStatsByPlayerFilePath <- paste(inputsFolderPath, "AggregateStatsByPlayer.csv", sep="")
aggregateStatsByPositionFilePath <- paste(inputsFolderPath, "AggregateStatsByPosition.csv", sep="")
estimationWeightsFilePath <- paste( parametersFolderPath, "EstimationWeights.csv", sep="")
positionRulesFilePath <- paste( seasonMasterDataFolderPath, "Rules\\PositionRules.csv", sep="")
kickerPointsFilePath <- paste( seasonMasterDataFolderPath, "Rules\\KickerPoints.csv", sep="")
otherPointsFilePath <- paste( seasonMasterDataFolderPath, "Rules\\OtherPoints.csv", sep="")
matchResultRulesFilePath <- paste( seasonMasterDataFolderPath, "Rules\\MatchResultRules.csv", sep="")
otherRulesFilePath <-  paste( seasonMasterDataFolderPath, "Rules\\OtherRules.csv", sep="")
appearancePointsFilePath <- paste( seasonMasterDataFolderPath, "Rules\\AppearancePoints.csv", sep="")
probabilitiesOfPlayingFilePath <- paste( inputsFolderPath, "\\ProbabilitiesOfPlaying.csv", sep="")

# Output file paths:
playerEstimatesBeforeInjuriesFilePath <- paste( forecastsFolderPath, "PlayerEstimates_BeforeInjuries_", model, ".csv", sep="")
playerEstimatesBeforeInjuriesWithInputsFilePath <- paste( forecastsFolderPath, "PlayerEstimates_BeforeInjuries_WithInputs_", model, ".csv", sep="")
playerEstimatesFilePath <- paste( forecastsFolderPath, "PlayerEstimates_", model, ".csv", sep="")
playerEstimatesWithInputsFilePath <- paste( forecastsFolderPath, "PlayerEstimates_WithInputs_", model, ".csv", sep="")

# ==================================================
# Define transforms of input data:
# 
cat("Defining columns to include in data sets...", fill=TRUE)

playerColumns <- c("PlayerName","TeamCode", "PositionCode", "Price") # "Rookie", "PositionType"
playerEstimateColumnsWithoutId <- c("Round", playerColumns)
playerEstimateColumns <- c("id", playerEstimateColumnsWithoutId )

primaryMatchForecastColumns <- c(
    "FixtureType", 
    "OpponentsTeamCode"
)

secondaryMatchForecastColumns <- c( 
    "WinProbability",
    "DrawProbability",
    "BonusPointLossProbability",
    "TryBonusPointProbability",
    "PredictedTriesForTeam",      # transform of: "PredictedTotalTriesScored"
    "PredictedPenaltiesForTeam",  # transform of: "PredictedPenaltiesScored"
    "PredictedAssistsFromTeamAssistRatio",
    "PredictedConversionsFromTeamConversionRatio"
)
# Other fields not included:   
    # "PredictedConversionsScored"
    # "PredictedTotalPointsScored"
    # "PredictedDropGoalsScored"
    # "PredictedPenaltyTriesScored"
    # "PredictedTotalPointsScoredFromTotalTries"             
    # "PredictedTotalPointsConcededFromTotalTries"
    # "PredictedWinFromTotalTries"
    # "PredictedTightForwardTriesScored"
    # "PredictedFRFTriesScored"
    # "PredictedLOCKTriesScored"
    # "PredictedLooseForwardTriesScored"
    # "PredictedFL8TriesScored"
    # "PredictedBackTriesScored"
    # "PredictedSCHTriesScored"
    # "PredictedFLHTriesScored"
    # "PredictedCTTriesScored"
    # "PredictedOBTriesScored"                               

matchForecastColumns <- c( primaryMatchForecastColumns, secondaryMatchForecastColumns )
    
aggregatePlayerStatsColumns <- c(
    "GamesPlayed",
    "FullAppearanceRatio",
    "PartAppearanceRatio",
    "DropGoalsPerGame",
    "YellowCardsPerGame",
    "RedCardsPerGame",
    "ProportionOfTeamTriesPerGame",
    "ProportionOfTeamAssistsPerGame",
    "ProportionOfTeamConversionsPerGame",
    "ProportionOfTeamPenaltiesPerGame"
)
    
aggregatePositionStatsColumns <- c(
    "FullAppearanceRatioForPosition",
    "PartAppearanceRatioForPosition",
    "DropGoalsPerGameForPosition",
    "YellowCardsPerGameForPosition",
    "RedCardsPerGameForPosition",
    "ProportionOfTeamTriesPerGameForPosition",
    "ProportionOfTeamAssistsPerGameForPosition",
    "ProportionOfTeamConversionsPerGameForPosition",
    "ProportionOfTeamPenaltiesPerGameForPosition"
)

otherInputColumns <- c(
    "MatchResultPointsForAWin",
    "MatchResultPointsForADraw"
)

secondaryInputColumns <- c( secondaryMatchForecastColumns, aggregatePlayerStatsColumns, aggregatePositionStatsColumns, otherInputColumns )
allInputColumns <- c( primaryMatchForecastColumns, secondaryInputColumns )

# Build up the output columns as each new column is added to the forecast:
nonKickerOutputColumns <- NULL
kickerOutputColumns <- NULL
secondaryOutputColumns <- NULL

# ==================================================
# Load input data:
# 
cat("Loading input data...", fill=TRUE)

rounds <- data.frame(Round = roundToForecastFor:21 )
players <- read.table( playersFilePath, header=TRUE, sep=",")[ playerColumns ]

futureTeamFixtures <- read.table( futureTeamFixturesFilePath, header=TRUE, sep=",")
# TODO: Filter this further

matchForecasts <- read.table( matchForecastsFilePath, header=TRUE, sep=",")
matchForecasts <- transform( matchForecasts,
    PredictedTriesForTeam = PredictedTotalTriesScored,
    PredictedPenaltiesForTeam = PredictedPenaltiesScored
)[ c("Round", "TeamCode", matchForecastColumns) ]

aggregatePlayerStats <- read.table( aggregateStatsByPlayerFilePath, header=TRUE, sep=",")
# TODO: Transform column names here
aggregatePlayerStats <- aggregatePlayerStats[
    c(
        "PlayerName",
        aggregatePlayerStatsColumns
     )
]

aggregatePositionStats <- read.table( aggregateStatsByPositionFilePath, header=TRUE, sep=",")
aggregatePositionStats <- transform( aggregatePositionStats,
    FullAppearanceRatioForPosition = FullAppearanceRatio,
    PartAppearanceRatioForPosition = PartAppearanceRatio,
    DropGoalsPerGameForPosition = DropGoalsPerGame,
    YellowCardsPerGameForPosition = YellowCardsPerGame,
    RedCardsPerGameForPosition = RedCardsPerGame,
    ProportionOfTeamTriesPerGameForPosition = ProportionOfTeamTriesPerGame,
    ProportionOfTeamAssistsPerGameForPosition = ProportionOfTeamAssistsPerGame,
    ProportionOfTeamConversionsPerGameForPosition = ProportionOfTeamConversionsPerGame,
    ProportionOfTeamPenaltiesPerGameForPosition = ProportionOfTeamPenaltiesPerGame
)[ c( "PositionCode", aggregatePositionStatsColumns ) ]

estimationWeights <- read.table( estimationWeightsFilePath, header=TRUE, sep=",")
positionRules <- read.table( positionRulesFilePath, header=TRUE, sep=",")[c("PositionCode", "PointsPerTry")]

kickerPoints <- read.table( kickerPointsFilePath, header=TRUE, sep=",")[c("EventTypeCode", "Points")]
pointsPerConversion <- kickerPoints[kickerPoints$EventTypeCode == "C",]$Points
pointsPerPenalty <- kickerPoints[kickerPoints$EventTypeCode == "P",]$Points

otherPoints <- read.table( otherPointsFilePath, header=TRUE, sep=",")[c("EventCode", "Points")]
pointsPerDropGoal <- otherPoints[otherPoints$EventCode == "D",]$Points
pointsPerYellowCard <- otherPoints[otherPoints$EventCode == "Y",]$Points
pointsPerRedCard <- otherPoints[otherPoints$EventCode == "R",]$Points
pointsPerAssist <- otherPoints[otherPoints$EventCode == "A",]$Points

matchResultRules <- read.table( matchResultRulesFilePath, header=TRUE, sep=",")[c("FixtureType", "Result", "Points")]

matchWinResultRules <- subset( matchResultRules, Result == "Win" )
matchWinResultRules <- transform( matchWinResultRules,
    MatchResultPointsForAWin = Points 
)[c("FixtureType", "MatchResultPointsForAWin")]

matchDrawResultRules <- subset( matchResultRules, Result == "Draw" )
matchDrawResultRules <- transform( matchDrawResultRules,
    MatchResultPointsForADraw = Points 
)[c("FixtureType", "MatchResultPointsForADraw")]

otherRules <- read.table( otherRulesFilePath, header=TRUE, sep=",")[c("PointsPerTeamBonusPoint")]
pointsPerTeamBonusPoint <- otherRules$PointsPerTeamBonusPoint

appearancePoints <- read.table( appearancePointsFilePath, header=TRUE, sep=",")[c("AppearanceCode", "Points")]
fullAppearancePoints <- appearancePoints[appearancePoints$AppearanceCode == "F",]$Points
partAppearancePoints <- appearancePoints[appearancePoints$AppearanceCode == "P",]$Points

probabilitiesOfPlaying <- read.table( probabilitiesOfPlayingFilePath, header=TRUE, sep=",")[
    c("Round", "PlayerName", "ProbabilityOfPlaying" )
]


# ===========================================================================================
# Perform calculations before injuries:
# 
# This makes the assumption that all players will play (if their team is playing).
# The probability of a player playing will be incorporated into a second set of calculations.
# 

cat("Performing calculations without applying injury information...", fill=TRUE)

# Set up subset of columns we are interested in:

# ---------------------------------------------------------------
# Generate a combined data frame with all required fields:
# 
playerEstimates <- merge( players, rounds, by=NULL, sort=TRUE)
playerEstimates$id <- seq_len(nrow(playerEstimates))  # Use for restoring sort order after a merge

pest1 <- merge( aggregatePlayerStats, playerEstimates, all.y = TRUE, sort=TRUE )
pest2 <- merge( aggregatePositionStats, pest1, all.y = TRUE, sort=TRUE )
pest3 <- merge( matchForecasts, pest2, all.y = TRUE, sort=TRUE )
pest4 <- merge( matchWinResultRules, pest3, all.y = TRUE, sort=TRUE )
pest5 <- merge( matchDrawResultRules, pest4, all.y = TRUE, sort=TRUE )
pest6 <- transform( pest5,
    FullAppearanceRatio = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(FullAppearanceRatio),
            0,
            FullAppearanceRatio
        )
    ),
    PartAppearanceRatio = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(PartAppearanceRatio),
            0,
            PartAppearanceRatio
        )
    ),
    DropGoalsPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(DropGoalsPerGame),
            0,
            DropGoalsPerGame
        )
    ),
    YellowCardsPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(YellowCardsPerGame),
            0,
            YellowCardsPerGame
        )
    ),
    RedCardsPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(RedCardsPerGame),
            0,
            RedCardsPerGame
        )
    ),
    ProportionOfTeamTriesPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(ProportionOfTeamTriesPerGame),
            0,
            ProportionOfTeamTriesPerGame
        )
    ),
    ProportionOfTeamAssistsPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(ProportionOfTeamAssistsPerGame),
            0,
            ProportionOfTeamAssistsPerGame
        )
    ),
    ProportionOfTeamConversionsPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(ProportionOfTeamConversionsPerGame),
            0,
            ProportionOfTeamConversionsPerGame
        )
    ),
    ProportionOfTeamPenaltiesPerGame = ifelse( 
        is.na(GamesPlayed), 
        0, 
        ifelse( 
            is.na(ProportionOfTeamPenaltiesPerGame),
            0,
            ProportionOfTeamPenaltiesPerGame
        )
    ),
    GamesPlayed = ifelse( is.na(GamesPlayed), 0, GamesPlayed )
)
playerEstimates <- pest6[
    c(playerEstimateColumns, allInputColumns) 
]


# ---------------------------------------------------------------
# Estimate points per player for match outcome and bonus points:
#
cat("    Estimating points per player for match outcomes and bonus points...", fill=TRUE)

pestMatchOutcome1 <- transform( playerEstimates,
    EstimatedPointsForAWin = ifelse( is.na(FixtureType), 0, 
        MatchResultPointsForAWin * WinProbability
    ),
    EstimatedPointsForADraw = ifelse( is.na(FixtureType), 0, 
        MatchResultPointsForADraw * DrawProbability
    ),
    EstimatedPointsForANarrowLossBonusPoint = ifelse( is.na(FixtureType), 0, 
        pointsPerTeamBonusPoint * BonusPointLossProbability
    ),
    EstimatedPointsForATryBonusPoint = ifelse( is.na(FixtureType), 0, 
        pointsPerTeamBonusPoint * TryBonusPointProbability
    )
)
pestMatchOutcome2 <- transform( pestMatchOutcome1,
    EstimatedMatchPoints = EstimatedPointsForAWin + EstimatedPointsForADraw,
    EstimatedPointsForTeamBonusPoints = EstimatedPointsForANarrowLossBonusPoint + EstimatedPointsForATryBonusPoint
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedMatchPoints", "EstimatedPointsForTeamBonusPoints" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedPointsForAWin", "EstimatedPointsForADraw", 
    "EstimatedPointsForANarrowLossBonusPoint", "EstimatedPointsForATryBonusPoint" )
playerEstimates <- pestMatchOutcome2[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]


# ---------------------------------------------------------------
# Estimate appearance points per player:
#
cat("    Estimating appearance points per player...", fill=TRUE)

pestAppearance1 <- transform( playerEstimates,
    EstimatedFullAppearanceProbabilityForPlayer = ifelse( is.na(FixtureType), 0, FullAppearanceRatio ),
    EstimatedPartAppearanceProbabilityForPlayer = ifelse( is.na(FixtureType), 0, PartAppearanceRatio ),
    EstimatedFullAppearanceProbabilityForPosition = ifelse( is.na(FixtureType), 0, FullAppearanceRatioForPosition ),
    EstimatedPartAppearanceProbabilityForPosition = ifelse( is.na(FixtureType), 0, PartAppearanceRatioForPosition )
)
pestAppearance2 <- transform( pestAppearance1,
    EstimatedFullAppearanceProbability = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedFullAppearanceProbabilityForPlayer * GamesPlayed
            + EstimatedFullAppearanceProbabilityForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    ),
    EstimatedPartAppearanceProbability = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedPartAppearanceProbabilityForPlayer * GamesPlayed
            + EstimatedPartAppearanceProbabilityForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)
pestAppearance3 <- transform( pestAppearance2,
    EstimatedPointsForFullAppearance = EstimatedFullAppearanceProbability * fullAppearancePoints,
    EstimatedPointsForPartAppearance = EstimatedPartAppearanceProbability * partAppearancePoints
)
pestAppearance4 <- transform( pestAppearance3,
    EstimatedAppearancePoints = EstimatedPointsForFullAppearance + EstimatedPointsForPartAppearance
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedAppearancePoints" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedFullAppearanceProbability", "EstimatedPartAppearanceProbability", 
    "EstimatedPointsForFullAppearance", "EstimatedPointsForPartAppearance" )
playerEstimates <- pestAppearance4[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]


# ---------------------------------------------------------------
# Estimate tries scored per player:
#
cat("    Estimating tries scored and try points per player...", fill=TRUE)

pestTries1 <- transform( playerEstimates,
    EstimatedTriesForPlayer = ifelse( is.na(FixtureType), 0, 
        ProportionOfTeamTriesPerGame * PredictedTriesForTeam
    ),
    EstimatedTriesForPosition = ifelse( is.na(FixtureType), 0,
        ProportionOfTeamTriesPerGameForPosition * PredictedTriesForTeam
    )
)
pestTries2 <- transform( pestTries1,
    EstimatedTries = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedTriesForPlayer * GamesPlayed
            + EstimatedTriesForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestTries3 <- merge( positionRules, pestTries2, all.y = TRUE, sort=TRUE )
pestTries4 <- transform( pestTries3,
    EstimatedPointsForTries = EstimatedTries * PointsPerTry
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedTries", "EstimatedPointsForTries" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedTriesForPlayer", "EstimatedTriesForPosition" )
playerEstimates <- pestTries4[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]


# ---------------------------------------------------------------
# Estimate assists scored per player:
#
cat("    Estimating assists scored and assist points per player...", fill=TRUE)

pestAssists1 <- transform( playerEstimates,
    EstimatedAssistsForPlayer = ifelse( is.na(FixtureType), 0, 
        ProportionOfTeamAssistsPerGame * PredictedAssistsFromTeamAssistRatio
    ),
    EstimatedAssistsForPosition = ifelse( is.na(FixtureType), 0,
        ProportionOfTeamAssistsPerGameForPosition * PredictedAssistsFromTeamAssistRatio
    )
)
pestAssists2 <- transform( pestAssists1,
    EstimatedAssists = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedAssistsForPlayer * GamesPlayed
            + EstimatedAssistsForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestAssists3 <- transform( pestAssists2,
    EstimatedPointsForAssists = EstimatedAssists * pointsPerAssist
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedAssists", "EstimatedPointsForAssists" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedAssistsForPlayer", "EstimatedAssistsForPosition" )
playerEstimates <- pestAssists3[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]



# ---------------------------------------------------------------
# Estimate conversions scored per player:
#
cat("    Estimating conversions scored and conversion points per player...", fill=TRUE)

pestConversions1 <- transform( playerEstimates,
    EstimatedConversionsForPlayer = ifelse( is.na(FixtureType), 0, 
        ProportionOfTeamConversionsPerGame * PredictedConversionsFromTeamConversionRatio
    ),
    EstimatedConversionsForPosition = ifelse( is.na(FixtureType), 0,
        ProportionOfTeamConversionsPerGameForPosition * PredictedConversionsFromTeamConversionRatio
    )
)
pestConversions2 <- transform( pestConversions1,
    EstimatedConversions = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedConversionsForPlayer * GamesPlayed
            + EstimatedConversionsForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestConversions3 <- transform( pestConversions2,
    EstimatedPointsForConversions = EstimatedConversions * pointsPerConversion
)

kickerOutputColumns <- c( kickerOutputColumns, "EstimatedConversions", "EstimatedPointsForConversions" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedConversionsForPlayer", "EstimatedConversionsForPosition" )
playerEstimates <- pestConversions3[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]



# ---------------------------------------------------------------
# Estimate penalties scored per player:
#
cat("    Estimating penalties scored and penalty points per player...", fill=TRUE)

pestPenalties1 <- transform( playerEstimates,
    EstimatedPenaltiesForPlayer = ifelse( is.na(FixtureType), 0, 
        ProportionOfTeamPenaltiesPerGame * PredictedPenaltiesForTeam
    ),
    EstimatedPenaltiesForPosition = ifelse( is.na(FixtureType), 0,
        ProportionOfTeamPenaltiesPerGameForPosition * PredictedPenaltiesForTeam
    )
)
pestPenalties2 <- transform( pestPenalties1,
    EstimatedPenalties = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedPenaltiesForPlayer * GamesPlayed
            + EstimatedPenaltiesForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestPenalties3 <- merge( positionRules, pestPenalties2, all.y = TRUE, sort=TRUE )
pestPenalties4 <- transform( pestPenalties3,
    EstimatedPointsForPenalties = EstimatedPenalties * pointsPerPenalty
)

kickerOutputColumns <- c( kickerOutputColumns, "EstimatedPenalties", "EstimatedPointsForPenalties" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedPenaltiesForPlayer", "EstimatedPenaltiesForPosition" )
playerEstimates <- pestPenalties4[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]


# ---------------------------------------------------------------
# Estimate drop goals scored per player:
#
cat("    Estimating drop goals scored and drop goal points per player...", fill=TRUE)

pestDropGoals1 <- transform( playerEstimates,
    EstimatedDropGoalsForPlayer = ifelse( is.na(FixtureType), 0, DropGoalsPerGame ),
    EstimatedDropGoalsForPosition = ifelse( is.na(FixtureType), 0, DropGoalsPerGameForPosition )
)
pestDropGoals2 <- transform( pestDropGoals1,
    EstimatedDropGoals = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedDropGoalsForPlayer * GamesPlayed
            + EstimatedDropGoalsForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestDropGoals3 <- transform( pestDropGoals2,
    EstimatedPointsForDropGoals = EstimatedDropGoals * pointsPerDropGoal
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedDropGoals", "EstimatedPointsForDropGoals" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedDropGoalsForPlayer", "EstimatedDropGoalsForPosition" )
playerEstimates <- pestDropGoals3[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]



# ---------------------------------------------------------------
# Estimate yellow cards scored per player:
#
cat("    Estimating yellow cards incurred and yellow card points per player...", fill=TRUE)

pestYellowCards1 <- transform( playerEstimates,
    EstimatedYellowCardsForPlayer = ifelse( is.na(FixtureType), 0, YellowCardsPerGame ),
    EstimatedYellowCardsForPosition = ifelse( is.na(FixtureType), 0, YellowCardsPerGameForPosition )
)
pestYellowCards2 <- transform( pestYellowCards1,
    EstimatedYellowCards = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedYellowCardsForPlayer * GamesPlayed
            + EstimatedYellowCardsForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestYellowCards3 <- transform( pestYellowCards2,
    EstimatedPointsForYellowCards = EstimatedYellowCards * pointsPerYellowCard
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedYellowCards", "EstimatedPointsForYellowCards" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedYellowCardsForPlayer", "EstimatedYellowCardsForPosition" )
playerEstimates <- pestYellowCards3[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]



# ---------------------------------------------------------------
# Estimate red cards scored per player:
#
cat("    Estimating red cards incurred and red card points per player...", fill=TRUE)

pestRedCards1 <- transform( playerEstimates,
    EstimatedRedCardsForPlayer = ifelse( is.na(FixtureType), 0, RedCardsPerGame ),
    EstimatedRedCardsForPosition = ifelse( is.na(FixtureType), 0, RedCardsPerGameForPosition )
)
pestRedCards2 <- transform( pestRedCards1,
    EstimatedRedCards = ifelse( is.na(FixtureType), 0, 
        ( 
            EstimatedRedCardsForPlayer * GamesPlayed
            + EstimatedRedCardsForPosition * estimationWeights$WeightingForPrevSeasonPositionScores
        ) / ( GamesPlayed + estimationWeights$WeightingForPrevSeasonPositionScores )
    )
)

pestRedCards3 <- transform( pestRedCards2,
    EstimatedPointsForRedCards = EstimatedRedCards * pointsPerRedCard
)

nonKickerOutputColumns <- c( nonKickerOutputColumns, "EstimatedRedCards", "EstimatedPointsForRedCards" )
secondaryOutputColumns <- c( secondaryOutputColumns, "EstimatedRedCardsForPlayer", "EstimatedRedCardsForPosition" )
playerEstimates <- pestRedCards3[c( playerEstimateColumns, allInputColumns, nonKickerOutputColumns, kickerOutputColumns, secondaryOutputColumns )]


# ---------------------------------------------------------------
# Estimate kicking and non-kicking points per player:
#
cat("    Estimating kicking and non-kicking points per player...", fill=TRUE)

playerEstimates <- transform( playerEstimates,
    EstimatedNonKickingPoints = EstimatedPointsForTries + EstimatedPointsForAssists 
        + EstimatedPointsForDropGoals + EstimatedPointsForYellowCards + EstimatedPointsForRedCards,
    EstimatedKickingPoints = EstimatedPointsForPenalties + EstimatedPointsForConversions
)
secondaryOutputColumns <- c( "EstimatedKickingPoints", "EstimatedNonKickingPoints", secondaryOutputColumns )


# ---------------------------------------------------------------
# Estimate overall points for player as kicker and as a normal player:
#
cat("    Estimating overall points as kicker and as a normal player...", fill=TRUE)

playerEstimates <- transform( playerEstimates,
    EstimatedPointsAsPlayer = EstimatedMatchPoints + EstimatedPointsForTeamBonusPoints
        + EstimatedAppearancePoints + EstimatedNonKickingPoints
)
playerEstimates <- transform( playerEstimates,
    EstimatedPointsAsKicker = EstimatedPointsAsPlayer + EstimatedKickingPoints
)
nonKickerOutputColumns <- c( "EstimatedPointsAsPlayer", "EstimatedPointsAsKicker", nonKickerOutputColumns )
    # EstimatedPointsAsKicker is added to non-kicker output columns as we want it as one of the early columns


# ---------------------------------------------------------------
# Save player estimates before injuries to file:
#

cat("    Saving player estimates (before injuries)...", fill=TRUE)

# Restore original sort order:
playerEstimates <- with( playerEstimates, playerEstimates[order(id),] )

# Choose columns to output in most convenient order:
playerEstimatesBeforeInjuriesWithInputs <- playerEstimates[
    c( playerEstimateColumns, primaryMatchForecastColumns, "GamesPlayed", 
       nonKickerOutputColumns, kickerOutputColumns, 
       secondaryOutputColumns, secondaryInputColumns 
    )
]
playerEstimatesBeforeInjuries <- playerEstimates[
    c( playerEstimateColumnsWithoutId, primaryMatchForecastColumns, nonKickerOutputColumns, kickerOutputColumns )
]

# Write to file:
write.csv(playerEstimatesBeforeInjuries, file=playerEstimatesBeforeInjuriesFilePath, row.names=FALSE)
write.csv(playerEstimatesBeforeInjuriesWithInputs, file=playerEstimatesBeforeInjuriesWithInputsFilePath, row.names=FALSE)


# ===========================================================================================
# Perform calculations including "injuries":
# 
# This incorporates the probability of a player playing into the estimates.
# Although injuries are the most important reason for a player not playing,
# other reasons will be included as well, such as:
#   * players being rested
#   * players on the bench who may not play
#   * players who are not the first choice starters
#   * players who are not the first choice starts, but where the first choice player is injured.
# 

cat("Calculating player estimates including injuries / probabilities of playing...", fill=TRUE)


# ---------------------------------------------------------------
# Calculate probability of playing per player and round:
pinj1 <- merge( probabilitiesOfPlaying, playerEstimates, all.y = TRUE, sort=TRUE )

# Players excluded from the table are assumed to be playing:
pinj2 <- transform( pinj1, 
    ProbabilityOfPlaying = ifelse(
        is.na(FixtureType),
        0.0,
        ifelse( 
            is.na(ProbabilityOfPlaying),
            1.0, 
            ProbabilityOfPlaying 
        )
    )
)

# Update all stats to take probability of playing into account:
cat("    Updating player estimates to incorporate the probability of playing...", fill=TRUE)

pinj3 <- transform( pinj2,
    EstimatedPointsAsPlayer = ProbabilityOfPlaying * EstimatedPointsAsPlayer,
    EstimatedPointsAsKicker = ProbabilityOfPlaying * EstimatedPointsAsKicker,
    EstimatedMatchPoints = ProbabilityOfPlaying * EstimatedMatchPoints,
    EstimatedPointsForTeamBonusPoints = ProbabilityOfPlaying * EstimatedPointsForTeamBonusPoints,
    EstimatedAppearancePoints = ProbabilityOfPlaying * EstimatedAppearancePoints,
    EstimatedTries = ProbabilityOfPlaying * EstimatedTries,
    EstimatedPointsForTries = ProbabilityOfPlaying * EstimatedPointsForTries,
    EstimatedAssists = ProbabilityOfPlaying * EstimatedAssists,
    EstimatedPointsForAssists = ProbabilityOfPlaying * EstimatedPointsForAssists,
    EstimatedDropGoals = ProbabilityOfPlaying * EstimatedDropGoals,
    EstimatedPointsForDropGoals = ProbabilityOfPlaying * EstimatedPointsForDropGoals,
    EstimatedYellowCards = ProbabilityOfPlaying * EstimatedYellowCards,
    EstimatedPointsForYellowCards = ProbabilityOfPlaying * EstimatedPointsForYellowCards,
    EstimatedRedCards = ProbabilityOfPlaying * EstimatedRedCards,
    EstimatedPointsForRedCards = ProbabilityOfPlaying * EstimatedPointsForRedCards,
    EstimatedConversions = ProbabilityOfPlaying * EstimatedConversions,
    EstimatedPointsForConversions = ProbabilityOfPlaying * EstimatedPointsForConversions,
    EstimatedPenalties = ProbabilityOfPlaying * EstimatedPenalties,
    EstimatedPointsForPenalties = ProbabilityOfPlaying * EstimatedPointsForPenalties,
    EstimatedKickingPoints = ProbabilityOfPlaying * EstimatedKickingPoints,
    EstimatedNonKickingPoints = ProbabilityOfPlaying * EstimatedNonKickingPoints,
    EstimatedPointsForAWin = ProbabilityOfPlaying * EstimatedPointsForAWin,
    EstimatedPointsForADraw = ProbabilityOfPlaying * EstimatedPointsForADraw,
    EstimatedPointsForANarrowLossBonusPoint = ProbabilityOfPlaying * EstimatedPointsForANarrowLossBonusPoint,
    EstimatedPointsForATryBonusPoint = ProbabilityOfPlaying * EstimatedPointsForATryBonusPoint,
    EstimatedFullAppearanceProbability = ProbabilityOfPlaying * EstimatedFullAppearanceProbability,
    EstimatedPartAppearanceProbability = ProbabilityOfPlaying * EstimatedPartAppearanceProbability,
    EstimatedPointsForFullAppearance = ProbabilityOfPlaying * EstimatedPointsForFullAppearance,
    EstimatedPointsForPartAppearance = ProbabilityOfPlaying * EstimatedPointsForPartAppearance,
    EstimatedTriesForPlayer = ProbabilityOfPlaying * EstimatedTriesForPlayer,
    EstimatedTriesForPosition = ProbabilityOfPlaying * EstimatedTriesForPosition,
    EstimatedAssistsForPlayer = ProbabilityOfPlaying * EstimatedAssistsForPlayer,
    EstimatedAssistsForPosition = ProbabilityOfPlaying * EstimatedAssistsForPosition,
    EstimatedConversionsForPlayer = ProbabilityOfPlaying * EstimatedConversionsForPlayer,
    EstimatedConversionsForPosition = ProbabilityOfPlaying * EstimatedConversionsForPosition,
    EstimatedPenaltiesForPlayer = ProbabilityOfPlaying * EstimatedPenaltiesForPlayer,
    EstimatedPenaltiesForPosition = ProbabilityOfPlaying * EstimatedPenaltiesForPosition,
    EstimatedDropGoalsForPlayer = ProbabilityOfPlaying * EstimatedDropGoalsForPlayer,
    EstimatedDropGoalsForPosition = ProbabilityOfPlaying * EstimatedDropGoalsForPosition,
    EstimatedYellowCardsForPlayer = ProbabilityOfPlaying * EstimatedYellowCardsForPlayer,
    EstimatedYellowCardsForPosition = ProbabilityOfPlaying * EstimatedYellowCardsForPosition,
    EstimatedRedCardsForPlayer = ProbabilityOfPlaying * EstimatedRedCardsForPlayer,
    EstimatedRedCardsForPosition = ProbabilityOfPlaying * EstimatedRedCardsForPosition
)

playerEstimates <- pinj3


# Restore original sort order:
playerEstimates <- with( playerEstimates, playerEstimates[order(id),] )

# ---------------------------------------------------------------
# Save player estimates with injuries to file:
#

cat("    Saving player estimates (after injuries)...", fill=TRUE)

playerEstimatesAfterInjuries <- playerEstimates[
    c( playerEstimateColumnsWithoutId, primaryMatchForecastColumns,
       "GamesPlayed", "ProbabilityOfPlaying", 
       nonKickerOutputColumns, kickerOutputColumns
     )
]
playerEstimatesAfterInjuriesWithInputs <- playerEstimates[
    c( playerEstimateColumns, primaryMatchForecastColumns,
       "ProbabilityOfPlaying",
       nonKickerOutputColumns, kickerOutputColumns,
       secondaryOutputColumns, secondaryInputColumns
     )
]

write.csv( playerEstimatesAfterInjuries, file=playerEstimatesFilePath, row.names=FALSE)
write.csv( playerEstimatesAfterInjuriesWithInputs, file=playerEstimatesWithInputsFilePath, row.names=FALSE)

# ------------------------------------------
# Stop redirecting console output to a file:
sink()

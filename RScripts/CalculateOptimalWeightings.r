# TODO's:
# -------
# 

# ================================================================
# Load required libraries:
# 
library(MASS)
library(pscl)

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
    upcomingRound <- 15
}

if (length(args) >= 3)
{
    model <- args[3]
} else
{
    model <- "NegBin"
    # Options: 
    #    model <- "lm" # predprob doesn't work for this, not even with Gaussian family
    #    model <- "NegBin"   # For negative binomial - seems best for total points scored
    #    model <- "poisson"  # Poisson is probably best for estimating tries, penalties, etc. (but Neg Binomial gets close enough)
    #    model <- "binomial" # This is not suitable, since it can only be used to model probabilities (results between 0 and 1)
}

# ===============================
# Generate folder and file paths:
# 
analysisFolderPath <- paste( "C:\\FantasyLeague\\DataByRound\\Round", upcomingRound, "\\Analysis\\", sep="")
allMatchResultsToDateFilePath <- paste( "C:\\FantasyLeague\\DataByRound\\Round", upcomingRound, "\\Inputs\\AllMatchResultsToDate.csv", sep="")


# ================================================================
# Load input data and calculate which results were wins and draws:
# 
allMatchResultsToDate <- read.table( allMatchResultsToDateFilePath, header=TRUE, sep=",")
allMatchResultsToDate <- subset( allMatchResultsToDate, Season != 2012 | Round > 1 )  # Eliminate round 1, which was clearly an anomaly
allMatchResultsToDate <- allMatchResultsToDate[c("Season", "Round","TeamCode", "OpponentsTeamCode", "FixtureType", "TotalPointsScored", "TotalPointsConceded")]
allMatchResultsToDate <- transform( allMatchResultsToDate, Win = as.numeric( TotalPointsScored > TotalPointsConceded ) )
allMatchResultsToDate <- transform( allMatchResultsToDate, Draw = as.numeric( TotalPointsScored == TotalPointsConceded ) )


# =================
# Create functions:
# 
matchesInRoundEstimator <- function( roundToEstimate, allMatchResultsWithWeightings ) {
    cat("+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++", fill=TRUE)
    cat(paste("+ Round:", roundToEstimate), fill=TRUE)
    cat("", fill=TRUE)
    
    allMatchResults <- allMatchResultsWithWeightings[ (allMatchResultsWithWeightings$Season < season) | (allMatchResultsWithWeightings$Round < roundToEstimate ), ]
    matchesToForecast <- allMatchResultsWithWeightings[ (allMatchResultsWithWeightings$Season == season) & (allMatchResultsWithWeightings$Round == roundToEstimate ), ]
    
    # ================================================================
    # Configure constants:
    # 
    fieldToEstimate <- "TotalPointsScored"
    concededFieldToEstimate <- "TotalPointsConceded"
    
    cat("=====================================================================================", fill=TRUE)
    cat(paste("*** Estimating", "TotalPointsScored"), fill=TRUE)
    cat("", fill=TRUE)
    
    # ================================================================
    # Configure the temporary estimation field:
    # 
    allMatchResults$ToEstimate <- allMatchResults[,fieldToEstimate]
    
    # ======================================================
    # Home team estimates:
    # 
    cat("-------------------------------------------------------------------------------------", fill=TRUE)
    cat("Home team", fieldToEstimate, ":", fill=TRUE)
    cat("", fill=TRUE)
    
    fixtureType <- "H"
    homeResults <- subset( allMatchResults, FixtureType == fixtureType & Round <= 18)
    attach(homeResults)
    
    if (model == "lm")
    {
        model.Home <- lm( ToEstimate ~ TeamCode + OpponentsTeamCode )
    } 
    if (model == "NegBin")
    {
        model.Home <- glm.nb( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE) #, control=glm.control(maxit=100))
    }
    if (model == "poisson")
    {
        model.Home <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE, family = poisson() ) #, control=glm.control(maxit=100))
    }
    if (model == "binomial")
    {
        model.Home <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE, family = binomial() ) #, control=glm.control(maxit=100))
    }
    
    detach()
    
    # ======================================================
    # Away team estimates:
    # 
    cat("-------------------------------------------------------------------------------------", fill=TRUE)
    cat("Away team", fieldToEstimate, ":", fill=TRUE)
    cat("", fill=TRUE)
    
    fixtureType <- "A"
    awayResults <- subset( allMatchResults, FixtureType == fixtureType & Round <= 18)
    attach(awayResults)
    
    if (model == "lm")
    {
        model.Away <- lm( ToEstimate ~ TeamCode + OpponentsTeamCode )
    }
    if (model == "NegBin")
    {
        model.Away <- glm.nb( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE) #, control=glm.control(maxit=100))
    }
    if (model == "poisson")
    {
        model.Away <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE, family = poisson() ) #, control=glm.control(maxit=100))
    }
    if (model == "binomial")
    {
        model.Away <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=FALSE, family = binomial() ) #, control=glm.control(maxit=100))
    }
    
    detach()
    
    # =======================================================================
    # Create estimates and forecasts:
    # 
    cat("-------------------------------------------------------------------------------------", fill=TRUE)
    cat("Create estimates and forecasts...", fill=TRUE)
    
    estimatedFieldName <- paste( "Predicted", fieldToEstimate, sep="" )
    estimatedConcededFieldName <- paste( "Predicted", concededFieldToEstimate, sep="" )
    
    # =======================================================================
    # Create estimates and add as fields:
    # 
    allMatchResults <- transform(allMatchResults, EstimateScored = 
        ifelse( FixtureType == "H", 
                exp( predict(model.Home,data.frame(TeamCode=TeamCode,OpponentsTeamCode=OpponentsTeamCode)) ),
                exp( predict(model.Away,data.frame(TeamCode=TeamCode,OpponentsTeamCode=OpponentsTeamCode)) )
              )
    )
    allMatchResults <- transform(allMatchResults, EstimateConceded = 
        ifelse( FixtureType == "H", 
                exp( predict(model.Away,data.frame(TeamCode=OpponentsTeamCode,OpponentsTeamCode=TeamCode)) ),
                exp( predict(model.Home,data.frame(TeamCode=OpponentsTeamCode,OpponentsTeamCode=TeamCode)) )
              )
    )
    
    allMatchResults[[estimatedFieldName]] <- allMatchResults$EstimateScored
    allMatchResults[[estimatedConcededFieldName]] <- allMatchResults$EstimateConceded
    
    # =======================================================================
    # Forecast points and add as fields:
    # 
    cat("Calculating forecasts...", fill=TRUE)
    
    matchesToForecast <- transform(matchesToForecast, EstimateScored = 
        ifelse( FixtureType == "H", 
                exp( predict(model.Home,data.frame(TeamCode=TeamCode,OpponentsTeamCode=OpponentsTeamCode)) ),
                exp( predict(model.Away,data.frame(TeamCode=TeamCode,OpponentsTeamCode=OpponentsTeamCode)) )
              )
    )
    matchesToForecast <- transform(matchesToForecast, EstimateConceded = 
        ifelse( FixtureType == "H", 
                exp( predict(model.Away,data.frame(TeamCode=OpponentsTeamCode,OpponentsTeamCode=TeamCode)) ),
                exp( predict(model.Home,data.frame(TeamCode=OpponentsTeamCode,OpponentsTeamCode=TeamCode)) )
              )
    )
    
    matchesToForecast[[estimatedFieldName]] <- matchesToForecast$EstimateScored
    matchesToForecast[[estimatedConcededFieldName]] <- matchesToForecast$EstimateConceded
    
    # =======================================================================
    # Calculate predicted scores:
    # 
    cat("Calculating predicted scores...", fill=TRUE)
    
    allMatchResults <- transform(allMatchResults, PredictedWin = as.numeric(PredictedTotalPointsScored > PredictedTotalPointsConceded))
    allMatchResults <- transform(allMatchResults, IsCorrectResult = as.numeric( PredictedWin == Win ))
    allMatchResults <- transform(allMatchResults, AbsDiffOfTotalPointsScored = abs( TotalPointsScored - PredictedTotalPointsScored ))
    allMatchResults <- transform(allMatchResults, AbsDiffOfTotalPointsConceded = abs( TotalPointsConceded - PredictedTotalPointsConceded ))
    
    # =======================================================================
    # Forecast outcome of match:
    # 
    cat("Calculating predicted wins...", fill=TRUE)
    
    # Calculate deviations and squared deviations of estimated to actual scores:
    matchesToForecast <- transform(matchesToForecast, PredictedWin = as.numeric(PredictedTotalPointsScored > PredictedTotalPointsConceded))
    matchesToForecast <- transform(matchesToForecast, IsCorrectResult = as.numeric( PredictedWin == Win ))
    matchesToForecast <- transform(matchesToForecast, AbsDiffOfTotalPointsScored = abs( TotalPointsScored - PredictedTotalPointsScored ))
    matchesToForecast <- transform(matchesToForecast, AbsDiffOfTotalPointsConceded = abs( TotalPointsConceded - PredictedTotalPointsConceded ))
    matchesToForecast <- transform(matchesToForecast, SquaredDeviation = (TotalPointsScored - PredictedTotalPointsScored) * (TotalPointsScored - PredictedTotalPointsScored) )
    
    matchesToForecast
}

roundEstimator <- function( parameters ) {
    cat("~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~", fill=TRUE)
    cat("Parameters", fill=TRUE)
    cat(paste("          WeightingOfEachGameLastSeason:", parameters$WeightingOfEachGameLastSeason), fill=TRUE)
    cat(paste("  WeightingOfGameRelativeToPreviousGame:", parameters$WeightingOfGameRelativeToPreviousGame), fill=TRUE)
    cat("", fill=TRUE)
    
    allMatchResultsWithWeightings <- transform( allMatchResultsToDate, 
        Weighting = ifelse( 
            Season < season, 
            parameters$WeightingOfEachGameLastSeason,
            parameters$WeightingOfGameRelativeToPreviousGame ^ ( Round - 1 )
        )
    )
    
    roundCount <- upcomingRound - 2
    
    roundEstimates <- data.frame(
        Round = numeric(roundCount),
        SumOfSquaredDeviations = numeric(roundCount),
        SumOfAbsoluteDeviations = numeric(roundCount),
        CorrectResultCount = numeric(roundCount),
        MatchCount = numeric(roundCount)
    )
    
    for (roundToEstimate in 1:roundCount)
    {
        matchEstimates <- matchesInRoundEstimator( roundToEstimate, allMatchResultsWithWeightings )
        sumOfSquaredDeviations <- sum( matchEstimates$SquaredDeviation )
        sumOfAbsoluteDeviations <- sum( matchEstimates$AbsDiffOfTotalPointsScored )
        correctResultCount <- sum( matchEstimates$IsCorrectResult ) / 2
        matchCount <- nrow( matchEstimates ) / 2
        roundEstimates[roundToEstimate,] <- c( roundToEstimate, sumOfSquaredDeviations, sumOfAbsoluteDeviations, correctResultCount, matchCount )
    }
    
    # Save to file...
    outputFilePath <- paste( analysisFolderPath, "NegBin_RoundEstimates_", 
        parameters$WeightingOfEachGameLastSeason, "_", 
        parameters$WeightingOfGameRelativeToPreviousGame, ".csv", 
        sep="" )
    write.csv(roundEstimates, file=outputFilePath, row.names=FALSE)
    
    roundEstimates
}

allRoundsEstimator <- function( parameters ) {
    roundEstimates <- roundEstimator( parameters )
    
    sumOfSquaredDeviations <- sum( roundEstimates$SumOfSquaredDeviations )
    sumOfAbsoluteDeviations <- sum( roundEstimates$SumOfAbsoluteDeviations )
    correctResultCount <- sum( roundEstimates$CorrectResultCount )
    matchCount <- sum( roundEstimates$MatchCount )
    accuracyRatio <- correctResultCount / matchCount
    
    data.frame( SumOfSquaredDeviations = sumOfSquaredDeviations, SumOfAbsoluteDeviations = sumOfAbsoluteDeviations, 
        CorrectResultCount = correctResultCount, MatchCount = matchCount, AccuracyRatio = accuracyRatio
    )
}

allParametersEstimator <- function( parameterSets ) {
    parameterSetCount <- nrow( parameterSets )
    
    calculations <- data.frame(
        WeightingOfEachGameLastSeason = numeric(parameterSetCount),
        WeightingOfGameRelativeToPreviousGame = numeric( parameterSetCount ),
        SumOfSquaredDeviations = numeric(parameterSetCount),
        SumOfAbsoluteDeviations = numeric(parameterSetCount),
        CorrectResultCount = numeric(parameterSetCount),
        MatchCount = numeric(parameterSetCount),
        AccuracyRatio = numeric(parameterSetCount)
    )
    
    for ( i in 1:parameterSetCount )
    {
        parameters <- parameterSets[i,]
        calculation <- allRoundsEstimator( parameters )
        calculations[i,"WeightingOfEachGameLastSeason"] <- parameterSets$WeightingOfEachGameLastSeason[[i]]
        calculations[i,"WeightingOfGameRelativeToPreviousGame"] <- parameterSets$WeightingOfGameRelativeToPreviousGame[[i]]
        calculations[i,"SumOfSquaredDeviations"] <- calculation$SumOfSquaredDeviations[[1]]
        calculations[i,"SumOfAbsoluteDeviations"] <- calculation$SumOfAbsoluteDeviations[[1]]
        calculations[i,"CorrectResultCount"] <- calculation$CorrectResultCount[[1]]
        calculations[i,"MatchCount"] <- calculation$MatchCount[[1]]
        calculations[i,"AccuracyRatio"] <- calculation$AccuracyRatio[[1]]
    }
    
    # Save to file...
    outputFilePath <- paste( analysisFolderPath, "NegBin_Calculations.csv", sep="" )
    write.csv(calculations, file=outputFilePath, row.names=FALSE)
    
    calculations
}

# Create the output data frame:
parameterSets <- expand.grid( 
    WeightingOfEachGameLastSeason = seq( 0.1, 1.3, 0.05),  # c( 0.25, 1, 1.5, 2), #seq( 0.25, 1.50, 0.05),  # c( 0.25, 1, 1.5, 2),
    WeightingOfGameRelativeToPreviousGame = seq( 1.00, 1.50, 0.05)
)

# parameterSets <- data.frame( WeightingOfEachGameLastSeason = 0.4, WeightingOfGameRelativeToPreviousGame = 1.05 )
calculations <- allParametersEstimator( parameterSets )
print( calculations )

# Display rows that are most suitable:
print( calculations[order(calculations$SumOfAbsoluteDeviations),][1,] )
print( calculations[order(calculations$SumOfSquaredDeviations),][1,] )

# Results for upcomingRound <- 5:
   # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 41                             1                                   1.4                4324.86                366.1153                 16         27     0.5925926
  # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 8                             1                                  1.07               4321.814                366.7769                 16         27     0.5925926

# With...
# parameterSets <- expand.grid( 
#     WeightingOfEachGameLastSeason = seq( 0.1, 1.0, 0.1), 
#     WeightingOfGameRelativeToPreviousGame = seq( 1.0, 1.2, 0.02)
# )
# ...
# Sum of squared deviations minimized by...
#   WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 50                             1                                  1.08               4321.814                 366.754                 16         27     0.5925926
# 

# parameterSets <- expand.grid( 
    # WeightingOfEachGameLastSeason = seq( 0.9, 1.1, 0.01), 
    # WeightingOfGameRelativeToPreviousGame = seq( 1.06, 1.1, 0.01)
# )
    # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 105                           1.1                                   1.1               4320.865                366.8944                 16         27     0.5925926
   # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 85                           0.9                                   1.1               4323.737                366.5003                 16         27     0.5925926


# parameterSets <- expand.grid( 
    # WeightingOfEachGameLastSeason = seq( 0.1, 1.5, 0.1),
    # WeightingOfGameRelativeToPreviousGame = seq( 1.09, 1.19, 0.01)
# )
    # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 159                           0.9                                  1.19               4324.559                366.3097                 16         27     0.5925926
    # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 163                           1.3                                  1.19                4320.14                367.0139                 16         27     0.5925926

# parameterSets <- expand.grid( 
    # WeightingOfEachGameLastSeason = seq( 0.8, 1.5, 0.05),
    # WeightingOfGameRelativeToPreviousGame = seq( 1.20, 1.40, 0.01)
# )
    # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 145                           0.9                                  1.31               4326.476                 366.082                 16         27     0.5925926
    # WeightingOfEachGameLastSeason WeightingOfGameRelativeToPreviousGame SumOfSquaredDeviations SumOfAbsoluteDeviations CorrectResultCount MatchCount AccuracyRatio
# 181                           1.4                                  1.33               4319.957                 366.864                 16         27     0.5925926


# Results for upcoming round = 7:

#    WeightingOfEachGameLastSeason = seq( 0.8, 1.5, 0.05),
#     WeightingOfGameRelativeToPreviousGame = seq( 1.00, 1.40, 0.01)


# TODO's:
# -------
# 
# 1. Check losing bonus point probability. It seems wrong (43 predicted versus 53 actual bonus point loss points).
# 2. Consider refactoring to use FixtureType as an estimator, instead of having separate home and away models
#    [But then need to make an interaction factor on most other columns]. NO: Better to have a separate model.

# ================================================================
# Load required libraries:
# 
library(MASS)
library(pscl)


# ================================================================
# Initialize various settings:
# 
# The command line arguments (after --args switch) are:
#    1: season          (default 2012)
#    2: upcoming round  (default 1)
#    3: model to use    (default "NegBin")
#    4: weighting of previous season game to first game of current season  (default 0.25)
#    5: weighting of a game in the current season to a game in the previous round (default 1.05)
#    6: based field name to estimate/forecast (default "" => estimate all fields)

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
    #    model <- "lm" # predprob doesn't work for this, not even with Gaussian family
    #    model <- "NegBin"   # For negative binomial - seems best for total points scored
    #    model <- "poisson"  # Poisson is probably best for estimating tries, penalties, etc. (but Neg Binomial gets close enough)
    #    model <- "binomial" # This is not suitable, since it can only be used to model probabilities (results between 0 and 1)
}

if (length(args) >= 4)
{
    weightingOfEachGameLastSeason <- as.double( args[4] )
} else
{
    weightingOfEachGameLastSeason <- 0.55  # was 0.25, then 0.8, then 0.55 from round 15
}

if (length(args) >= 5)
{
    weightingOfGameRelativeToPreviousGame <- as.double( args[5] )
} else
{
    weightingOfGameRelativeToPreviousGame <- 1.1  # was 1.05, then 1.1, then 1.15 from round 15
}

if (length(args) >= 6)
{
    baseFieldNameToEstimateFilter <- args[6]
} else
{
    baseFieldNameToEstimateFilter <- ""  # => Estimate all fields
    # baseFieldNameToEstimateFilter <- "TotalPoints"
}


# ===============================
# Generate folder and file paths:
# 
upcomingRoundFolderPath <- paste( "C:\\FantasyLeague\\DataByRound\\Round", roundToForecastFor, "\\", sep="")
inputsFolderPath <- paste( upcomingRoundFolderPath, "Inputs\\", sep="")
outputsFolderPath <- paste( upcomingRoundFolderPath, "Predictions\\", model, "\\", sep="")
forecastsFolderPath <- paste( upcomingRoundFolderPath, "Forecasts\\", model, "\\", sep="")

# Redirect console to a file (as well as the console):
sinkFilePath <- paste( outputsFolderPath, "sink_", model, ".txt", sep="")
sink(file = sinkFilePath, split=TRUE, type="output")

allResultsFilePath <- paste(inputsFolderPath, "AllMatchResultsToDate.csv", sep="" )
matchesToForecastFilePath <- paste( inputsFolderPath, "FutureTeamFixtures.csv", sep="" )
logPointsFilePath <- paste( inputsFolderPath, "LogPoints.csv", sep="" )

# TODO: matchWeightingsFilePath <- paste( inputsFolderPath, "MatchWeightings.csv", sep="" )

# Output file paths:
predictionsFilePath <- paste( outputsFolderPath, "Predictions_", model, ".csv", sep="")
forecastsFilePath <- paste( forecastsFolderPath, "Forecasts_", model, ".csv", sep="")

homePredProbFilePath <- paste( outputsFolderPath, "PredProb.TotalPointsScored.Home.", model, ".csv", sep="")
awayPredProbFilePath <- paste( outputsFolderPath, "PredProb.TotalPointsScored.Away.", model, ".csv", sep="")

predictedProbComparisonFilePath <- paste( outputsFolderPath, "ProbabilityComparisonByTeam.TotalPointsScored.Away.", model, ".csv", sep="")

forecastHomePredProbFilePath <- paste( forecastsFolderPath, "PredProb.TotalPointsScored.Home.Forecast.", model, ".csv", sep="")
forecastAwayPredProbFilePath <- paste( forecastsFolderPath, "PredProb.TotalPointsScored.Away.Forecast.", model, ".csv", sep="")

predictedFinalLogTableFilePath <- paste( forecastsFolderPath, "PredictedFinalLogTable_", model, ".csv", sep="")
aggregatesByTeamFilePath <- paste(inputsFolderPath, "AggregatesByTeam.csv", sep="" )
    # Note: This is an output from this script, but an input to the ForecastPlayerScores.r script.
    #       Hence it is in the inputs folder, not the outputs folder.


# ================================================================
# Load input data and calculate which results were wins and draws:
# 

# Load fixtures to build an estimation model from:
allMatchResults <- read.table( allResultsFilePath, header=TRUE, sep=",")
allMatchResults <- transform( allMatchResults, 
    Weighting = ifelse( 
        Season < seasonToForecastFor, 
        weightingOfEachGameLastSeason,
        ifelse( Round == 1, 
                0.0,  # Ignore games from round 1 as the low number of tries scored indicates an anomaly
                weightingOfGameRelativeToPreviousGame ^ ( Round - 1 )
              )
    )
)
allMatchResults <- transform( allMatchResults, Win = as.numeric( TotalPointsScored > TotalPointsConceded ) )
allMatchResults <- transform( allMatchResults, Draw = as.numeric( TotalPointsScored == TotalPointsConceded ) )
allMatchResults <- transform( allMatchResults, BonusPointLoss = as.numeric( (TotalPointsScored < TotalPointsConceded) & (TotalPointsScored + 7 >= TotalPointsConceded) ) )
allMatchResults <- transform( allMatchResults, TryBonusPoint = as.numeric( TotalTriesScored >= 4 ) )
allMatchResults <- transform( allMatchResults, LogPoints = 4 * Win + 2 * Draw + 1 * BonusPointLoss + 1 * TryBonusPoint ) 
    # TODO: Add 4 points for a bye, 2 for a cancelled match

# Load fixtures to forecast:
matchesToForecast <- read.table( matchesToForecastFilePath, header=TRUE, sep=",")

# Remove byes from fixtures to forecast:
attach(matchesToForecast)
matchesToForecast <- subset( matchesToForecast, FixtureType == "H" | FixtureType == "A" )
detach()
row.names(matchesToForecast) <- NULL  # re-index rows:

# Add temporary fields to store the value to estimate in:
allMatchResults <- transform( allMatchResults, ToEstimate = NA )
matchesToForecast <- transform( matchesToForecast, ToEstimate = NA )

# Add temporary fields to store the estimated values in:
allMatchResults <- transform( allMatchResults, EstimateScored = NA )
allMatchResults <- transform( allMatchResults, EstimateConceded = NA )

matchesToForecast <- transform( matchesToForecast, EstimateScored = NA )
matchesToForecast <- transform( matchesToForecast, EstimateConceded = NA )

# Load log position:
logPoints <- read.table( logPointsFilePath, header=TRUE, sep=",")

# ================================================================
# Choose fields to estimate:
# 
fieldsToEstimate <- c("TotalPoints","TightForwardTries","FRFTries","LOCKTries","LooseForwardTries","FL8Tries","BackTries","SCHTries","FLHTries","CTTries","OBTries","TotalTries","Conversions","Penalties","DropGoals","PenaltyTries")

# Excluded fields:
# "TightForwardAssists","FRFAssists","LOCKAssists","LooseForwardAssists","FL8Assists",
# "BackAssists","SCHAssists","FLHAssists","CTAssists","OBAssists","TotalAssists",

scoredFieldsToEstimate <- paste("Predicted", fieldsToEstimate, "Scored", sep="")
concededFieldsToEstimate <- paste("Predicted", fieldsToEstimate, "Conceded", sep="")
allFieldsToEstimate <- append(scoredFieldsToEstimate,concededFieldsToEstimate)

# ================================================================
# Iterate over all fields to estimate:
# 
for (baseFieldName in fieldsToEstimate)
{
    if (baseFieldNameToEstimateFilter == "" | baseFieldName == baseFieldNameToEstimateFilter)
    {
        # ================================================================
        # Configure constants:
        # 
        fieldToEstimate <- paste(baseFieldName, "Scored", sep="")
        concededFieldToEstimate <- paste(baseFieldName, "Conceded", sep="")
        
        cat("=====================================================================================", fill=TRUE)
        cat(paste("*** Estimating", fieldToEstimate), fill=TRUE)
        cat("", fill=TRUE)
        
        # Field-specific output file paths:
        homeSummaryFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Home.NoReferees.Summary.txt", sep="")
        homeCoefficientsFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Home.NoReferees.Coefficients.csv", sep="")
        homeScoreImageFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Home.NoReferees.Plots.png", sep="")
        homeMultipliersFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Home.NoReferees.Multipliers.csv", sep="")
        
        awaySummaryFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Away.NoReferees.Summary.txt", sep="")
        awayCoefficientsFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Away.NoReferees.Coefficients.csv", sep="")
        awayScoreImageFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Away.NoReferees.Plots.png", sep="")
        awayMultipliersFilePath <- paste( outputsFolderPath, "\\", model, ".", fieldToEstimate, ".Away.NoReferees.Multipliers.csv", sep="")
        
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
            model.Home <- glm.nb( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE) #, control=glm.control(maxit=100))
        }
        if (model == "poisson")
        {
            model.Home <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE, family = poisson() ) #, control=glm.control(maxit=100))
        }
        if (model == "binomial")
        {
            model.Home <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE, family = binomial() ) #, control=glm.control(maxit=100))
        }
        
        detach()
        
        # Save home summary to a file:
        sink(file = homeSummaryFilePath, split=TRUE, type="output")
        print(summary(model.Home))
        sink()
        cat("", fill=TRUE)
        
        write.csv(model.Home$coefficients, file=homeCoefficientsFilePath)
        write.csv(exp(model.Home$coefficients), file=homeMultipliersFilePath)
        
        png(homeScoreImageFilePath)
        layout(matrix(c(1,2,3,4),2,2))
        plot(model.Home)
        dev.off()
        
        
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
            model.Away <- glm.nb( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE) #, control=glm.control(maxit=100))
        }
        if (model == "poisson")
        {
            model.Away <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE, family = poisson() ) #, control=glm.control(maxit=100))
        }
        if (model == "binomial")
        {
            model.Away <- glm( ToEstimate ~ TeamCode + OpponentsTeamCode, weights=Weighting, trace=TRUE, family = binomial() ) #, control=glm.control(maxit=100))
        }
        
        detach()
        
        # Save away summary to a file:
        sink(file = awaySummaryFilePath, split=TRUE, type="output")
        print(summary(model.Away))
        sink()
        cat("", fill=TRUE)
        
        write.csv(model.Away$coefficients, file=awayCoefficientsFilePath)
        write.csv(exp(model.Away$coefficients), file=awayMultipliersFilePath)
        
        png(awayScoreImageFilePath)
        layout(matrix(c(1,2,3,4),2,2))
        plot(model.Away)
        dev.off()

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
        
        if (fieldToEstimate == "TotalTriesScored")
        {
            # =======================================================================
            # Calculate probability of a bonus point for scoring 4 or more tries:
            # 
            allMatchResults <- transform( allMatchResults, TryBonusPointProbability <- NA )
            
            # Calculate the probabilities of 0 to 3 tries
            ppHome <- predprob( model.Home, allMatchResults, at=0:3 )
            ppAway <- predprob( model.Away, allMatchResults, at=0:3 )
            
            for (row in 1:nrow(ppHome))
            {
                if (row %% 2 == 1)
                {
                    # Home team:
                    allMatchResults$TryBonusPointProbability[[row]] <- 1.0 - sum( ppHome[row,] )
                } else
                {
                    # Away team:
                    allMatchResults$TryBonusPointProbability[[row]] <- 1.0 - sum( ppAway[row,] )
                }
            }
            
            # =======================================================================
            # Forecast probability of a bonus point for scoring 4 or more tries:
            # 
            matchesToForecast <- transform( matchesToForecast, TryBonusPointProbability <- NA )
            
            # Calculate the probabilities of 0 to 3 tries
            ppHomeForecast <- predprob( model.Home, matchesToForecast, at=0:3 )
            ppAwayForecast <- predprob( model.Away, matchesToForecast, at=0:3 )
            
            for (row in 1:nrow(ppHomeForecast))
            {
                if (row %% 2 == 1)
                {
                    # Home team:
                    matchesToForecast$TryBonusPointProbability[[row]] <- 1.0 - sum( ppHomeForecast[row,] )
                } else
                {
                    # Away team:
                    matchesToForecast$TryBonusPointProbability[[row]] <- 1.0 - sum( ppAwayForecast[row,] )
                }
            }
        }
        
        if (fieldToEstimate == "TotalPointsScored")
        {
            # =======================================================================
            # Calculate predicted scores:
            # 
            cat("Calculating predicted scores...", fill=TRUE)
            
            allMatchResults <- transform(allMatchResults, PredictedWin = as.numeric(PredictedTotalPointsScored > PredictedTotalPointsConceded))
            allMatchResults <- transform(allMatchResults, IsCorrectResult = as.numeric( PredictedWin == Win ))
            allMatchResults <- transform(allMatchResults, AbsDiffOfTotalPointsScored = abs( TotalPointsScored - PredictedTotalPointsScored ))
            allMatchResults <- transform(allMatchResults, AbsDiffOfTotalPointsConceded = abs( TotalPointsConceded - PredictedTotalPointsConceded ))
            
            # ------------------------------------------------------------------------
            # Calculate probabilities of a win and a draw:
            # 
            # Note: This makes the significant assumption that home and away scores are independent.
            # 
            cat("    Calculating win and draw probabilities...", fill=TRUE)
            
            ppHome <- predprob( model.Home, allMatchResults, at=0:100 )
            ppAway <- predprob( model.Away, allMatchResults, at=0:100 )
            
            write.csv(ppHome, file=homePredProbFilePath, row.names=FALSE)
            write.csv(ppAway, file=awayPredProbFilePath, row.names=FALSE)
            
            allMatchResults <- transform( allMatchResults, WinProbability <- NA )
            allMatchResults <- transform( allMatchResults, DrawProbability <- NA )
            allMatchResults <- transform( allMatchResults, BonusPointLossProbability <- NA )
            
            minLastColumn <- min(ncol(ppHome),ncol(ppAway))
            
            for (row in 1:nrow(ppHome))
            {
                if (row %% 2 == 1)
                {
                    # Home team:
                    
                    # Calculate the probability of a win:
                    probScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppAway[row,] )
                    probOpponentsScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppHome[row+1,] )
                    probWin <- (
                        sum( ppHome[row,2:minLastColumn]*cumsum(ppAway[row+1,1:(minLastColumn-1)]) ) + 
                            probScoreIsGreaterThanAllPredProbs * (1 - probOpponentsScoreIsGreaterThanAllPredProbs)
                    )
                    allMatchResults$WinProbability[[row]] <- probWin
                    
                    # Calculate probability of scoring a bonus point for losing by 7 points or less:
                    opponentsCumSumLag7 <- c( 
                        cumsum(ppAway[row+1,])[8:minLastColumn],
                        rep(1.0,7)  # Add enough records to the end so that the lengths are the same
                    )
                    allMatchResults$BonusPointLossProbability[[row]] <- sum(
                        ppHome[row,] * 
                            ( 
                              # Probability of opponents scoring exactly 1 to 7 points more:
                              opponentsCumSumLag7
                              - cumsum( ppAway[row+1,] )
                            )
                    )
                } else
                {
                    # Away team:
                    
                    # Calculate the probability of a win:
                    probScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppAway[row,] )
                    probOpponentsScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppHome[row-1,] )
                    probWin <- (
                        sum( ppAway[row,2:minLastColumn]*cumsum(ppHome[row-1,1:(minLastColumn-1)]) ) + 
                            probScoreIsGreaterThanAllPredProbs * (1 - probOpponentsScoreIsGreaterThanAllPredProbs)
                    )
                    allMatchResults$WinProbability[[row]] <- probWin
                    
                    # Calculate the probability of a draw as the residual probability:
                    probOpponentsWin <- allMatchResults$WinProbability[[row - 1]]
                    probDraw <- 1.0 - probOpponentsWin - probWin
                    allMatchResults$DrawProbability[[row]] <- probDraw
                    
                    # Set home team's draw probability as well:
                    allMatchResults$DrawProbability[[row-1]] <- probDraw
                    
                    # Calculate probability of scoring a bonus point for losing by 7 points or less:
                    opponentsCumSumLag7 <- c( 
                        cumsum(ppHome[row-1,])[8:minLastColumn],
                        rep(1.0,7)  # Add enough records to the end so that the lengths are the same
                    )
                    allMatchResults$BonusPointLossProbability[[row]] <- sum(
                        ppAway[row,] * 
                            ( 
                              # Probability of opponents scoring exactly 1 to 7 points more:
                              opponentsCumSumLag7
                              - cumsum( ppHome[row-1,] )
                            )
                    )
                }
            }
            
            
            # =======================================================================
            # Forecast outcome of match:
            # 
            cat("Calculating predicted wins...", fill=TRUE)
            
            matchesToForecast <- transform(matchesToForecast, PredictedWin = as.numeric(PredictedTotalPointsScored > PredictedTotalPointsConceded))
            
            # ------------------------------------------------------------------------
            # Calculate probabilities of a win and a draw:
            # 
            # Note: This makes the significant assumption that home and away scores are independent.
            # 
            cat("    Calculating win and draw probabilities...", fill=TRUE)
            
            ppHomeForecast <- predprob( model.Home, matchesToForecast, at=0:100 )
            ppAwayForecast <- predprob( model.Away, matchesToForecast, at=0:100 )
            
            write.csv(ppHomeForecast, file=forecastHomePredProbFilePath, row.names=FALSE)
            write.csv(ppAwayForecast, file=forecastAwayPredProbFilePath, row.names=FALSE)
            
            matchesToForecast <- transform( matchesToForecast, WinProbability <- NA )
            matchesToForecast <- transform( matchesToForecast, DrawProbability <- NA )
            matchesToForecast <- transform( matchesToForecast, BonusPointLossProbability <- NA )
            
            minLastColumn <- min(ncol(ppHomeForecast),ncol(ppAwayForecast))
            
            for (row in 1:nrow(ppHomeForecast))
            {
                if (row %% 2 == 1)
                {
                    # Home team:
                    
                    # Calculate the probability of a win:
                    probScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppAwayForecast[row,] )
                    probOpponentsScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppHomeForecast[row+1,] )
                    probWin <- (
                        sum( ppHomeForecast[row,2:minLastColumn]*cumsum(ppAwayForecast[row+1,1:(minLastColumn-1)]) ) + 
                            probScoreIsGreaterThanAllPredProbs * (1 - probOpponentsScoreIsGreaterThanAllPredProbs)
                    )
                    matchesToForecast$WinProbability[[row]] <- probWin
                    
                    # Calculate probability of scoring a bonus point for losing by 7 points or less:
                    opponentsCumSumLag7 <- c( 
                        cumsum(ppAwayForecast[row+1,])[8:minLastColumn],
                        rep(1.0,7)  # Add enough records to the end so that the lengths are the same
                    )
                    matchesToForecast$BonusPointLossProbability[[row]] <- sum(
                        ppHomeForecast[row,] * 
                            ( 
                              # Probability of opponents scoring exactly 1 to 7 points more:
                              opponentsCumSumLag7
                              - cumsum( ppAwayForecast[row+1,] )
                            )
                    )
                } else
                {
                    # Away team:
                    
                    # Calculate the probability of a win:
                    probScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppAwayForecast[row,] )
                    probOpponentsScoreIsGreaterThanAllPredProbs <- 1.0 - sum( ppHomeForecast[row-1,] )
                    probWin <- (
                        sum( ppAwayForecast[row,2:minLastColumn]*cumsum(ppHomeForecast[row-1,1:(minLastColumn-1)]) ) + 
                            probScoreIsGreaterThanAllPredProbs * (1 - probOpponentsScoreIsGreaterThanAllPredProbs)
                    )
                    matchesToForecast$WinProbability[[row]] <- probWin
                    
                    # Calculate the probability of a draw as the residual probability:
                    probOpponentsWin <- matchesToForecast$WinProbability[[row - 1]]
                    probDraw <- 1.0 - probOpponentsWin - probWin
                    matchesToForecast$DrawProbability[[row]] <- probDraw
                    
                    # Set home team's draw probability as well:
                    matchesToForecast$DrawProbability[[row-1]] <- probDraw
                    
                    # Calculate probability of scoring a bonus point for losing by 7 points or less:
                    opponentsCumSumLag7 <- c( 
                        cumsum(ppHomeForecast[row-1,])[8:minLastColumn],
                        rep(1.0,7)  # Add enough records to the end so that the lengths are the same
                    )
                    matchesToForecast$BonusPointLossProbability[[row]] <- sum(
                        ppAwayForecast[row,] * 
                            ( 
                              # Probability of opponents scoring exactly 1 to 7 points more:
                              opponentsCumSumLag7
                              - cumsum( ppHomeForecast[row-1,] )
                            )
                    )
                }
            }
        }
    }
}

# Only write out predictions and estimates if all fields have been estimated:
if (baseFieldNameToEstimateFilter == "")
{
    # ------------------------------------------------------------------------
    # Calculate and save the aggregate assist and conversion ratios per team:
    # 
    roundRobinMatchResults <- subset( allMatchResults, Round <= 18)
    
    attach( roundRobinMatchResults )
    totalConversionsByTeam <- aggregate( ConversionsScored ~ TeamCode, roundRobinMatchResults, FUN=sum )
    totalTriesByTeam <- aggregate( TotalTriesScored ~ TeamCode, roundRobinMatchResults, FUN=sum )
    totalAssistsByTeam <- aggregate( TotalAssistsScored ~ TeamCode, roundRobinMatchResults, FUN=sum )
    detach()
    
    aggregatesByTeam <- merge( totalTriesByTeam, totalConversionsByTeam )
    aggregatesByTeam <- merge( aggregatesByTeam, totalAssistsByTeam )
    aggregatesByTeam$ConversionRatio <- aggregatesByTeam$ConversionsScored / aggregatesByTeam$TotalTriesScored
    aggregatesByTeam$AssistRatio <- aggregatesByTeam$TotalAssistsScored / aggregatesByTeam$TotalTriesScored
    
    write.csv(aggregatesByTeam, file=aggregatesByTeamFilePath, row.names=FALSE)
    
    
    # ------------------------------------------------------------------------
    # Use the aggregate assist and conversion ratios by team
    # to predict assists and conversions per match:
    # 
    allMatchResults$id <- seq_len(nrow(allMatchResults))
    allMatchResults <- merge( allMatchResults, aggregatesByTeam, by = "TeamCode", all.x=TRUE, sort=FALSE)
    
    # Remove extra merge columns which don't interested us:
    allMatchResults$TotalAssistsScored.y <- NULL
    allMatchResults$TotalTriesScored.y <- NULL
    allMatchResults$ConversionsScored.y <- NULL
    
    # Restore original sort order:
    allMatchResults <- with( allMatchResults, allMatchResults[order(id),] )
    
    allMatchResults$PredictedAssistsFromTeamAssistRatio <- allMatchResults$PredictedTotalTriesScored * allMatchResults$AssistRatio
    allMatchResults$PredictedConversionsFromTeamConversionRatio <- allMatchResults$PredictedTotalTriesScored * allMatchResults$ConversionRatio
    
    
    # ------------------------------------------------------------------------
    # Use the aggregate assist and conversion ratios by team
    # to forecast assists and conversions per match:
    # 
    matchesToForecast$id <- seq_len(nrow(matchesToForecast))
    matchesToForecast <- merge( matchesToForecast, aggregatesByTeam, by = "TeamCode", all.x=TRUE, sort=FALSE)
    
    # Remove extra merge columns which don't interested us:
    matchesToForecast$TotalAssistsScored.y <- NULL
    matchesToForecast$TotalTriesScored.y <- NULL
    matchesToForecast$ConversionsScored.y <- NULL
    
    # Restore original sort order:
    matchesToForecast <- with( matchesToForecast, matchesToForecast[order(id),] )
    
    matchesToForecast$PredictedAssistsFromTeamAssistRatio <- matchesToForecast$PredictedTotalTriesScored * matchesToForecast$AssistRatio
    matchesToForecast$PredictedConversionsFromTeamConversionRatio <- matchesToForecast$PredictedTotalTriesScored * matchesToForecast$ConversionRatio
    
    
    # ------------------------------------------------------------------------
    # Calculate estimated points from sub-components of score:
    # 
    
    # 
    # Calculate estimated team points from predicted tries, penalty tries, conversions, penalties and drop goals:
    # 
    
    # Predicted points scored and conceded:
    allMatchResults <- transform( allMatchResults, 
        PredictedTotalPointsScoredFromTotalTries
            = 5 * PredictedTotalTriesScored + 
              5 * PredictedPenaltyTriesScored + 
              2 * PredictedConversionsScored + 
              3 * PredictedPenaltiesScored + 
              3 * PredictedDropGoalsScored
    )
    
    allMatchResults <- transform( allMatchResults,
        PredictedTotalPointsConcededFromTotalTries
            = 5 * PredictedTotalTriesConceded + 
              5 * PredictedPenaltyTriesConceded + 
              2 * PredictedConversionsConceded + 
              3 * PredictedPenaltiesConceded + 
              3 * PredictedDropGoalsConceded
    )
    
    # Predicted match result:
    allMatchResults <- transform( allMatchResults,
        PredictedWinFromTotalTries
            = as.numeric( PredictedTotalPointsScoredFromTotalTries > PredictedTotalPointsConcededFromTotalTries )
    )
    
    # Comparison to actual results:
    allMatchResults <- transform( allMatchResults, 
        IsCorrectResultFromTotalTries = as.numeric( PredictedWinFromTotalTries == Win )
    )
    
    # 
    # Calculate estimated team points from predicted tries by position type:
    # 
    
    # Scored:
    allMatchResults <- transform( allMatchResults, 
        PredictedTotalTriesScoredAsSumOfPositionTypeTries
            = PredictedTightForwardTriesScored + PredictedLooseForwardTriesScored + PredictedBackTriesScored + PredictedPenaltyTriesScored
    )
    allMatchResults <- transform( allMatchResults, 
        PredictedTotalPointsScoredFromPositionTypeTries
            = 5 * PredictedTotalTriesScoredAsSumOfPositionTypeTries + 
              2 * PredictedConversionsScored + 
              3 * PredictedPenaltiesScored + 
              3 * PredictedDropGoalsScored
    )
    
    # Conceded:
    allMatchResults <- transform( allMatchResults,
        PredictedTotalTriesConcededAsSumOfPositionTypeTries
            = PredictedTightForwardTriesConceded + PredictedLooseForwardTriesConceded + PredictedBackTriesConceded + PredictedPenaltyTriesConceded
    )
    allMatchResults <- transform( allMatchResults,
        PredictedTotalPointsConcededFromPositionTypeTries
            = 5 * PredictedTotalTriesConcededAsSumOfPositionTypeTries + 
              2 * PredictedConversionsConceded + 
              3 * PredictedPenaltiesConceded + 
              3 * PredictedDropGoalsConceded
    )
    
    # Predicted match result:
    allMatchResults <- transform( allMatchResults,
        PredictedWinFromPositionTypeTries
            = as.numeric( PredictedTotalPointsScoredFromPositionTypeTries > PredictedTotalPointsConcededFromPositionTypeTries )
    )
    
    # Comparison to actual results:
    allMatchResults <- transform( allMatchResults, 
        IsCorrectResultFromPositionTypeTries = as.numeric( PredictedWinFromPositionTypeTries == Win )
    )
    
    # Predict log points:
    allMatchResults <- transform( allMatchResults, 
        PredictedLogPoints = ifelse( 
            Round > 18, 
            0,
            4 * WinProbability + 2 * DrawProbability + BonusPointLossProbability + TryBonusPointProbability 
        ) 
    )
    
    
    # ------------------------------------------------------------------------
    # Calculate forecast points from sub-components of score:
    # 
    
    # 
    # Calculate estimated team points from predicted tries, penalty tries, conversions, penalties and drop goals:
    # 
    
    # Predicted points scored and conceded:
    matchesToForecast <- transform( matchesToForecast, 
        PredictedTotalPointsScoredFromTotalTries
            = 5 * PredictedTotalTriesScored + 
              5 * PredictedPenaltyTriesScored + 
              2 * PredictedConversionsScored + 
              3 * PredictedPenaltiesScored + 
              3 * PredictedDropGoalsScored
    )
    
    matchesToForecast <- transform( matchesToForecast,
        PredictedTotalPointsConcededFromTotalTries
            = 5 * PredictedTotalTriesConceded + 
              5 * PredictedPenaltyTriesConceded + 
              2 * PredictedConversionsConceded + 
              3 * PredictedPenaltiesConceded + 
              3 * PredictedDropGoalsConceded
    )
    
    # Predicted match result:
    matchesToForecast <- transform( matchesToForecast,
        PredictedWinFromTotalTries
            = as.numeric( PredictedTotalPointsScoredFromTotalTries > PredictedTotalPointsConcededFromTotalTries )
    )
    
    # 
    # Calculate estimated team points from predicted tries by position type:
    # 
    
    # Scored:
    matchesToForecast <- transform( matchesToForecast, 
        PredictedTotalTriesScoredAsSumOfPositionTypeTries
            = PredictedTightForwardTriesScored + PredictedLooseForwardTriesScored + PredictedBackTriesScored + PredictedPenaltyTriesScored
    )
    matchesToForecast <- transform( matchesToForecast, 
        PredictedTotalPointsScoredFromPositionTypeTries
            = 5 * PredictedTotalTriesScoredAsSumOfPositionTypeTries + 
              2 * PredictedConversionsScored + 
              3 * PredictedPenaltiesScored + 
              3 * PredictedDropGoalsScored
    )
    
    # Conceded:
    matchesToForecast <- transform( matchesToForecast,
        PredictedTotalTriesConcededAsSumOfPositionTypeTries
            = PredictedTightForwardTriesConceded + PredictedLooseForwardTriesConceded + PredictedBackTriesConceded + PredictedPenaltyTriesConceded
    )
    matchesToForecast <- transform( matchesToForecast,
        PredictedTotalPointsConcededFromPositionTypeTries
            = 5 * PredictedTotalTriesConcededAsSumOfPositionTypeTries + 
              2 * PredictedConversionsConceded + 
              3 * PredictedPenaltiesConceded + 
              3 * PredictedDropGoalsConceded
    )
    
    # Predicted match result:
    matchesToForecast <- transform( matchesToForecast,
        PredictedWinFromPositionTypeTries
            = as.numeric( PredictedTotalPointsScoredFromPositionTypeTries > PredictedTotalPointsConcededFromPositionTypeTries )
    )
    
    # Predict log points:
    matchesToForecast <- transform( matchesToForecast, 
        PredictedLogPoints = ifelse( 
            Round > 18, 
            0,
            4 * WinProbability + 2 * DrawProbability + BonusPointLossProbability + TryBonusPointProbability 
        ) 
    )
    
    
    # ------------------------------------------------------------------------
    # Predict final log points of all teams:
    #
    
    attach( matchesToForecast )
    predictedFinalLogTable <- aggregate( PredictedLogPoints ~ TeamCode, matchesToForecast, FUN=sum )
    detach()
    predictedFinalLogTable <- merge( predictedFinalLogTable, logPoints )
    predictedFinalLogTable$PredictedLogPointsForRemainingRounds <- predictedFinalLogTable$PredictedLogPoints
    predictedFinalLogTable$PredictedLogPoints <- predictedFinalLogTable$LogPoints + 
        predictedFinalLogTable$PredictedLogPointsForRemainingRounds + 
        4 * ( 2 - predictedFinalLogTable$Byes ) # 4 points per bye x 2 byes
    predictedFinalLogTable <- predictedFinalLogTable[c("TeamCode","PredictedLogPoints","LogPoints","PredictedLogPointsForRemainingRounds","Byes")]
    write.csv(predictedFinalLogTable, file=predictedFinalLogTableFilePath, row.names=FALSE)
    
    
    # ------------------------------------------------------------------------
    # Save the predictions to an output file:
    # 
    fieldsInPrediction <- append( 
        c( "Round", "TeamCode", "OpponentsTeamCode", "FixtureType", 
           "TotalPointsScored", "TotalPointsConceded", "Win", "Draw", "WinProbability", "DrawProbability", 
           "BonusPointLoss", "BonusPointLossProbability", "TryBonusPoint", "TryBonusPointProbability", 
           "IsCorrectResult", "LogPoints", "PredictedLogPoints",
           "PredictedTotalPointsScoredFromTotalTries", "PredictedTotalPointsConcededFromTotalTries",
           "PredictedWinFromTotalTries", "IsCorrectResultFromTotalTries", 
           "PredictedTotalTriesScoredAsSumOfPositionTypeTries", 
           "PredictedTotalTriesConcededAsSumOfPositionTypeTries", 
           "PredictedTotalPointsConcededFromPositionTypeTries",
           "PredictedWinFromPositionTypeTries", "IsCorrectResultFromPositionTypeTries",
           "PredictedAssistsFromTeamAssistRatio", "PredictedConversionsFromTeamConversionRatio"),
        allFieldsToEstimate,
        after=16
    )
    predictions <- allMatchResults[fieldsInPrediction]
    write.csv(predictions, file=predictionsFilePath, row.names=FALSE)
    
    
    # ------------------------------------------------------------------------
    # Compare cumulative win probabilities by team and fixture type:
    # 
    predictedProbComparison <- aggregate( cbind(Win, WinProbability, Draw, DrawProbability) ~ FixtureType + TeamCode, allMatchResults, FUN=mean)
    write.csv(predictedProbComparison, file=predictedProbComparisonFilePath, row.names=FALSE)
    
    
    # ------------------------------------------------------------------------
    # Save the forecasts to an output file:
    # 
    fieldsInForecast <- append( 
        c( "Round", "TeamCode", "OpponentsTeamCode", "FixtureType", 
           "WinProbability", "DrawProbability", "BonusPointLossProbability", "TryBonusPointProbability", "PredictedLogPoints",
           "PredictedTotalPointsScoredFromTotalTries", "PredictedTotalPointsConcededFromTotalTries", "PredictedWinFromTotalTries",
           "PredictedTotalTriesScoredAsSumOfPositionTypeTries", "PredictedTotalTriesConcededAsSumOfPositionTypeTries", 
           "PredictedTotalPointsScoredFromPositionTypeTries", "PredictedTotalPointsConcededFromPositionTypeTries", 
           "PredictedWinFromPositionTypeTries", 
           "PredictedAssistsFromTeamAssistRatio", "PredictedConversionsFromTeamConversionRatio"),
        allFieldsToEstimate,
        after=8
    )
    forecasts <- matchesToForecast[fieldsInForecast]
    write.csv(forecasts, file=forecastsFilePath, row.names=FALSE)
}

# ------------------------------------------
# Stop redirecting console output to a file:
sink()

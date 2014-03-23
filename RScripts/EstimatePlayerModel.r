# ================================================================
# Load required libraries:
# 
library(MASS)
library(pscl)

# ================================================================
# Initialize various settings:
# 
# Settings:
# 

outputsFolderPath <- "C:\\FantasyLeague\\RScripts\\ScratchPad\\Results\\PlayerEstimationModel"
playerStatsFilePath <- "C:\\FantasyLeague\\PrevSeasonAnalysis\\PlayerStats\\PlayerStatsForEstimationModel.csv"


# Redirect console to a file (as well as the console):
sinkFilePath <- paste( outputsFolderPath, "\\PlayerModelEstimation_sink.txt", sep="")
sink(file = sinkFilePath, split=TRUE, type="output")

# Load data
playerStats <- read.table( playerStatsFilePath, header=TRUE, sep=",")

attach(playerStats)

# model.nb.Anonymous <- glm.nb( Tries ~ PositionCode + Rookie + OpponentsTeamCode * FixtureType, trace=TRUE) #, control=glm.control(maxit=100))
# anova(model.nb.Anonymous)
#                               Df Deviance Resid. Df Resid. Dev  Pr(>Chi)    
# NULL                                           4918     2364.4              
# PositionCode                   6  154.536      4912     2209.8 < 2.2e-16 ***
# Rookie                         1    3.588      4911     2206.3   0.05821 .  
# OpponentsTeamCode             14   60.566      4897     2145.7 9.334e-08 ***
# FixtureType                    1    3.583      4896     2142.1   0.05837 .  
# OpponentsTeamCode:FixtureType 14   12.689      4882     2129.4   0.55118    
# ---
# Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1
model.nb.Anonymous <- glm.nb( Tries ~ PositionCode + OpponentsTeamCode + FixtureType + Rookie, trace=TRUE) #, control=glm.control(maxit=100))
summary(model.nb.Anonymous)
model.nb.Anonymous.Multipliers <- exp( model.Anonymous$coeff )
model.nb.Anonymous.Multipliers
# anova(model.Anonymous)


# model.nb.AnonymousBasedOnTotalTriesScored <- glm.nb( Tries ~ TeamTotalTriesScored + PositionCode + Rookie + FixtureType, trace=TRUE) #, control=glm.control(maxit=100))
#                      Df Deviance Resid. Df Resid. Dev Pr(>Chi)    
# NULL                                  4918     2521.4             
# TeamTotalTriesScored  1  242.247      4917     2279.2   <2e-16 ***
# PositionCode          6  160.114      4911     2119.1   <2e-16 ***
# Rookie                1    1.317      4910     2117.7   0.2511    
# FixtureType           1    0.053      4909     2117.7   0.8182    
model.nb.AnonymousBasedOnTotalTriesScored <- glm.nb( Tries ~ TeamTotalTriesScored + PositionCode, trace=TRUE) #, control=glm.control(maxit=100))
summary(model.nb.AnonymousBasedOnTotalTriesScored)
model.nb.AnonymousBasedOnTotalTriesScored.Multipliers <- exp( model.nb.AnonymousBasedOnTotalTriesScored$coeff )
model.nb.AnonymousBasedOnTotalTriesScored.Multipliers
anova(model.nb.AnonymousBasedOnTotalTriesScored)

model.lm.AnonymousBasedOnTotalTriesScored <- lm( Tries ~ TeamTotalTriesScored + PositionCode, trace=TRUE)
summary(model.lm.AnonymousBasedOnTotalTriesScored)
anova(model.lm.AnonymousBasedOnTotalTriesScored)
# Don't like lm, because of possibility of estimating negative tries scored

model.nb.AnonymousBasedOnLogOfTotalTriesScored <- glm.nb( Tries ~ log(TeamTotalTriesScored + 0.01) + PositionCode, trace=TRUE) #, control=glm.control(maxit=100))
summary(model.nb.AnonymousBasedOnLogOfTotalTriesScored)
model.nb.AnonymousBasedOnLogOfTotalTriesScored.Multipliers <- exp( model.nb.AnonymousBasedOnLogOfTotalTriesScored$coeff )
model.nb.AnonymousBasedOnLogOfTotalTriesScored.Multipliers
anova(model.nb.AnonymousBasedOnLogOfTotalTriesScored)
# What's nice here is that there is a direct multiplication of TeamTotalTriesScored. So zero scored for team => zero scored for player.
# What's not nice is that the TeamTotalTriesScored is raised to the power of 2.66.
# So 0 tries for team => 0 tries for player
# 1 try for team => t tries for player
# 2 tries for team => 6t tries for player
# 3 tries for team => 18t tries for player
# 4 tries for team => 40t tries for player, which comes to an estimate of 3.97 tries PER outside back who played!

# Need to rather model proportion of team's tries scored by the player.
# Could a binomial be appropriate here? Probably. Then the model becomes:
model.bin.AnonymousBasedOnTotalTriesScored <- glm( cbind( Tries, TeamTotalTriesScored - Tries ) ~ PositionCode,
    family=binomial, data=playerStats)
summary(model.bin.AnonymousBasedOnTotalTriesScored)
anova(model.bin.AnonymousBasedOnTotalTriesScored)
model.bin.AnonymousBasedOnTotalTriesScored.Multipliers <- exp( model.bin.AnonymousBasedOnTotalTriesScored$coeff )
model.bin.AnonymousBasedOnTotalTriesScored.Multipliers
# Problem here seems to be how to predict based on this. 
# > model.bin.AnonymousBasedOnTotalTriesScored.Multipliers
#      (Intercept)  PositionCodeFL8  PositionCodeFLH  PositionCodeFRF PositionCodeLOCK   PositionCodeOB  PositionCodeSCH 
#        0.0772325        0.4717362        0.6806164        0.3242045        0.3142307        1.4042513        0.5953065

model.bin.AnonymousBasedOnTotalTriesScored2 <- glm( cbind( Tries, TeamTotalTriesScored - Tries ) ~ PositionCode,
    family=binomial, data=playerStats)
summary(model.bin.AnonymousBasedOnTotalTriesScored2)
anova(model.bin.AnonymousBasedOnTotalTriesScored2)
model.bin.AnonymousBasedOnTotalTriesScored2.Multipliers <- exp( model.bin.AnonymousBasedOnTotalTriesScored2$coeff )
model.bin.AnonymousBasedOnTotalTriesScored2.Multipliers
model.bin.AnonymousBasedOnTotalTriesScored2.Proportions <- 1 / (1 + 1 / exp( model.bin.AnonymousBasedOnTotalTriesScored2$coeff ) )
model.bin.AnonymousBasedOnTotalTriesScored2.Proportions

# > model.bin.AnonymousBasedOnTotalTriesScored2.Multipliers
#      (Intercept)  PositionCodeFL8  PositionCodeFLH  PositionCodeFRF PositionCodeLOCK   PositionCodeOB  PositionCodeSCH 
#        0.0772325        0.4717362        0.6806164        0.3242045        0.3142307        1.4042513        0.5953065 
# > model.bin.AnonymousBasedOnTotalTriesScored2.Proportions <- 1 / (1 + 1 / exp( model.bin.AnonymousBasedOnTotalTriesScored2$coeff ) )
# > model.bin.AnonymousBasedOnTotalTriesScored2.Proportions
#      (Intercept)  PositionCodeFL8  PositionCodeFLH  PositionCodeFRF PositionCodeLOCK   PositionCodeOB  PositionCodeSCH 
#       0.07169529       0.32053039       0.40498022       0.24482962       0.23909859       0.58407009       0.37316121


# model <- glm.nb( ToEstimate ~ TeamCode + OpponentsTeamCode, trace=TRUE) #, control=glm.control(maxit=100))
playerNamePositionTriesModel <- glm.nb( Tries ~ PlayerName + OpponentsTeamCode * FixtureType + TeamPositionTriesScored, trace=TRUE) #, control=glm.control(maxit=100))

summary(playerNamePositionTriesModel)
playerNamePositionTriesModel.Multipliers <- exp( playerNamePositionTriesModel$coeff )
# playerNamePositionTriesModel.Multipliers[playerNamePositionTriesModel.Multipliers >= 1]

playerNameTeamTriesModel <- glm.nb( Tries ~ PlayerName + OpponentsTeamCode : FixtureType + TeamTotalTriesScored, trace=TRUE) #, control=glm.control(maxit=100))
summary(playerNameTeamTriesModel)
playerNameTeamTriesModel.Multipliers <- exp( playerNameTeamTriesModel$coeff )
playerNameTeamTriesModel.Multipliers
playerNameTeamTriesModel.Multipliers[playerNameTeamTriesModel.Multipliers >= 1]

detach(playerStats)

# Stop redirecting console output to a file:
sink()

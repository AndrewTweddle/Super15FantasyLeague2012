# =======================================================================
# Useful diagnostic tests:
# 
# -------------------------------------------------------------------------------------------------------
# 
aggregate(IsCorrectResult ~ FixtureType, data=subset(allMatchResults, TotalPointsScored != TotalPointsConceded), FUN=sum )
# 120 games without draws (4 draws in total)
#
# 94 for neg binomial
# 92 for Poisson
# 

aggregate( IsCorrectResultFromTotalTries ~ FixtureType, data=subset(allMatchResults, TotalPointsScored != TotalPointsConceded), FUN=sum )
#   FixtureType IsCorrectResultFromTotalTries
# 1           A                            91
# 2           H                            91

aggregate( IsCorrectResultFromPositionTypeTries ~ FixtureType, data=subset(allMatchResults, TotalPointsScored != TotalPointsConceded), FUN=sum )
#   FixtureType IsCorrectResultFromPositionTypeTries
# 1           A                                   88
# 2           H                                   88

aggregate(Win ~ FixtureType, allMatchResults, FUN=mean)
#   FixtureType       Win
# 1           A 0.4193548
# 2           H 0.5483871
# 
aggregate(Draw ~ FixtureType, allMatchResults, FUN=mean)
# 
#   FixtureType       Draw
# 1           A 0.03225806
# 2           H 0.03225806
#
aggregate( WinProbability ~ FixtureType, allMatchResults, FUN=mean)
# 
# NEGATIVE BINOMIAL:
# 
#   FixtureType WinProbability
# 1           A      0.4245818
# 2           H      0.5493279
# 
# POISSON:
# 
#   FixtureType WinProbability
# 1           A      0.3942861
# 2           H      0.5750353
#
# CONCLUSION: Negative Binomial is much better!
#

aggregate( DrawProbability ~ FixtureType, allMatchResults, FUN=mean)
# 
# NEGATIVE BINOMIAL:
# 
#   FixtureType DrawProbability
# 1           A      0.02609037
# 2           H      0.02609037
#
# POISSON:
# 
#   FixtureType DrawProbability
# 1           A      0.03067863
# 2           H      0.03067863
# -------------------------------------------------------------------------------------------------------
# 
1-pchisq(135.5,90)
# [1] 0.001379875
# 
# Highly significant, so not a good model
#
# -------------------------------------------------------------------------------------------------------
# 
summary( model.Home )
summary( model.Away )
# 
# -------------------------------------------------------------------------------------------------------
# 
# Comparisons of models:
# 
# model.Home/Away <- glm.nb( TotalPointsScored ~ TeamCode + OpponentsTeamCode )  # 94 correct
# model.Home/Away <- lm( TotalPointsScored ~ TeamCode + OpponentsTeamCode )      # 94 correct
# model.Home/Away <- glm.nb( TotalPointsScored ~ TeamCode + OpponentsTeamCode, link=sqrt )  # 93 correct
# model.Home/Away <- glm.nb( TotalPointsScored ~ TeamCode + OpponentsTeamCode, link=identity ) # 90 correct
# model.Home/Away <- glm( TotalPointsScored ~ TeamCode + OpponentsTeamCode, family=poisson() ) # 92 correct
#

# Average absolute deviation:
aggregate( Abs(TotalPointsScored - PredictedTotalPointsScored) ~ FixtureType, allMatchResults, FUN=mean)
# 
# -------------------------------------------------------------------------------------------------------
# 
# Test correlation of home and away (because of assumption of independence):
cor.test(homeResults$TotalPointsScored,awayResults$TotalPointsScored)

#        Pearson's product-moment correlation

# data:  homeResults$TotalPointsScored and awayResults$TotalPointsScored 
# t = -0.7797, df = 117, p-value = 0.4371
# alternative hypothesis: true correlation is not equal to 0 
# 95 percent confidence interval:
# -0.2486775  0.1095125 
# sample estimates:
#         cor 
# -0.07190029
#


sum(allMatchResults$BonusPointLoss)
# [1] 53
sum(allMatchResults$BonusPointLossProbability)
# [1] 42.60204

aggregate(BonusPointLoss ~ FixtureType, allMatchResults, FUN=sum)
#   FixtureType BonusPointLoss
# 1           A             28
# 2           H             25
aggregate(BonusPointLossProbability ~ FixtureType, allMatchResults, FUN=sum)
#   FixtureType BonusPointLossProbability
# 1           A                  22.13686
# 2           H                  20.46518

sum(allMatchResults$TryBonusPoint)
# [1] 57
sum(allMatchResults$TryBonusPointProbability)
# [1] 56.51132

sum(allMatchResults$TotalTriesScored)
# [1] 575
sum(allMatchResults$PredictedTotalTriesScored)
# [1] 577.7082

sum(allMatchResults$PenaltiesScored)
# [1] 665
sum(allMatchResults$PredictedPenaltiesScored)
# [1] 667.9489


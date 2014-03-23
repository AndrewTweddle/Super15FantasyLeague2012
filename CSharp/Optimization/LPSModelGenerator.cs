using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.IO;

namespace FantasyLeague
{
    public class LPSModelGenerator
    {
        #region Public Properties

        public int CurrentRound { get; set; }
        public int LastRound { get; set; }
        public double MaxCostOfTeam { get; set; }
        public int MaxTransfersInCurrentWindow { get; set; }
        public bool UseBinaryVariables { get; set; }

        /// <summary>
        /// Indicates whether filtering by candidate type is enabled or not
        /// </summary>
        public bool IgnoreAllowedRoles { get; set; }

        #endregion // Public Properties

        #region Public Methods

        public string Generate(IList<TransferConstraint> transferAllocations, IList<PositionModel> positions,
            IEnumerable<string> teamCompositionConstraints, IDictionary<int, IList<PlayerModel>> playerListsByRound,
            IList<PlayerModel> nonPlayoffPlayers, IList<PlayerModel> playersByRound)
        {
            string[] teams
                = { "BLU", "BRM", "BUL", "CHE", "CHF", "CRU", "HIG", 
                    "HUR", "LIO", "RBL", "RED", "SHK", "STO", "WAR", "WFR" 
                  };
            string[] decisionVariableNames 
                = { "IsInTeam", "IsCaptain", "IsKicker", "IsSubstitute", 
                    "TransfersIn", "TransfersOut" 
                  };

            StringBuilder sb = new StringBuilder();
            StringWriter sw = new StringWriter(sb);

            // Objective Function:
            DefineAnObjectiveFunctionToMaximizeSumOfScoresForAllRounds(sw);
            CalculateExpectedScoresEachRound(sw, playersByRound);

            // Add team composition constraints:
            AddConstraintsOnTotalNumberOfTeamMembersEachRound(sw, playerListsByRound);
            AddConstraintsOnTotalNumberOfSubstitutesEachRound(sw, playerListsByRound);
            AddConstraintsToPreventAPlayerFillingMoreThanOneRoleInARound(sw, playersByRound);
            AddConstraintsOfExactlyOneDesignatedKickerEachRound(sw, playerListsByRound);
            AddConstraintsOfExactlyOneDesignatedCaptainEachRound(sw, playerListsByRound);
            AddConstraintsOnMaximumPlayersPerRealTeamEachRound(sw, playerListsByRound, teams);
            AddCustomConstraintsOnTeamComposition(sw, teamCompositionConstraints);
            AddConstraintsToEnforceRequiredNumberOfPlayersPerPositionEachRound(sw, positions, playerListsByRound);
            AddConstraintsOfExactlyOneSubstitutePerPositionEachRound(sw, positions, playerListsByRound);

            // Add cost constraints:
            AddConstraintsOnTotalCostsOfChosenPlayersPerRound(sw, playerListsByRound);

            // Add transfer constraints:
            CalculateWhetherPlayerIsInTeamFromPreviousRoundsTeamAndTransfers(sw, playerListsByRound, nonPlayoffPlayers);
            AddConstraintsToPreventAPlayerBeingTransferredInAndOutInASingleRound(sw, playersByRound);
            CalculateTotalTransfersForEachRoundFromPlayersTransferredIn(sw, playerListsByRound);
            AddMaxTransfersPerRoundConstraints(sw);
            AddTotalTransfersConstraint(sw);
            AddTransferAllocationConstraints(sw, transferAllocations);

            // Define variables:
            AddRangeConstraintsOnBinaryVariablesDefinedAsInts(sw, decisionVariableNames, playersByRound);
            DefineTeamVariablesPerRound(sw, playerListsByRound, teams);
            DefineRoundVariables(sw);
            DefinePlayerVariables(sw, decisionVariableNames, nonPlayoffPlayers, playersByRound);

            // Generate the text of the LPS model:
            sw.Flush();
            string lpsModel = sb.ToString();
            return lpsModel;
        }

        private void DefineAnObjectiveFunctionToMaximizeSumOfScoresForAllRounds(StringWriter sw)
        {
            sw.Write("Max: ");
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write(@"+ ScoreForRound_{0} ", round);
            }
            sw.WriteLine(";");
        }

        private void CalculateExpectedScoresEachRound(
            StringWriter sw, IList<PlayerModel> playersByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write(@"ScoreForRound_{0}_Constraint: ScoreForRound_{0} = ", round);
                foreach (PlayerModel player in playersByRound.Where(player => player.Round == round))
                {
                    sw.Write(@"+ {0} IsInTeam_{1}_{2} ", 
                        player.NonKickerScoreForRound, player.PlayerId, player.Round);

                    if (IgnoreAllowedRoles)
                    {
                        if (player.AllowedRole == AllowedRole.Kicker
                        || player.AllowedRounds == AllowedRounds.PlayOffs)
                        {
                            sw.Write(@"+ {0} IsKicker_{1}_{2} ",
                                player.KickerScoreForRound - player.NonKickerScoreForRound, 
                                player.PlayerId, player.Round);
                        }

                        if (player.AllowedRole == AllowedRole.Captain
                            || player.AllowedRounds == AllowedRounds.PlayOffs)
                        {
                            sw.Write(@"+ {0} IsCaptain_{1}_{2} ", 
                                player.NonKickerScoreForRound, player.PlayerId, player.Round);
                        }
                    }

                    sw.Write(@"+ {0} IsSubstitute_{1}_{2} ", 
                        -0.5 * player.NonKickerScoreForRound, player.PlayerId, player.Round);
                }
                sw.WriteLine(";");
            }
        }

        private void AddConstraintsOnTotalNumberOfTeamMembersEachRound(
            StringWriter sw, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write("PlayersInTeamConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    sw.Write(@"+ IsInTeam_{0}_{1} ", player.PlayerId, round);
                }
                sw.WriteLine(@"= 22;");
            }
        }

        private void AddConstraintsOnTotalNumberOfSubstitutesEachRound(
            StringWriter sw, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write("SubstitutesInTeamConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    sw.Write(@"+ IsSubstitute_{0}_{1} ", player.PlayerId, round);
                }
                sw.WriteLine(@"= 7;");
            }
        }

        private void AddConstraintsToPreventAPlayerFillingMoreThanOneRoleInARound(
            StringWriter sw, IList<PlayerModel> playersByRound)
        {
            foreach (PlayerModel player in playersByRound)
            {
                sw.Write(@"PlayerStatusInTeamConstraint_{0}_{1}: ", player.PlayerId, player.Round);

                if (IgnoreAllowedRoles 
                    || player.AllowedRole == AllowedRole.Captain 
                    || player.AllowedRounds == AllowedRounds.PlayOffs)
                {
                    sw.Write(@"+ IsCaptain_{0}_{1} ", player.PlayerId, player.Round);
                }

                if (IgnoreAllowedRoles 
                    || player.AllowedRole == AllowedRole.Kicker 
                    || player.AllowedRounds == AllowedRounds.PlayOffs)
                {
                    sw.Write(@"+ IsKicker_{0}_{1} ", player.PlayerId, player.Round);
                }

                sw.WriteLine(
                    @" + IsSubstitute_{0}_{1} <= IsInTeam_{0}_{1};", 
                    player.PlayerId, player.Round);
            }

        }

        private void AddConstraintsOfExactlyOneDesignatedKickerEachRound(
            StringWriter sw, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write("OneKickerPerTeamConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    if (IgnoreAllowedRoles 
                        || player.AllowedRole == AllowedRole.Kicker 
                        || player.AllowedRounds == AllowedRounds.PlayOffs)
                    {
                        sw.Write(@"+ IsKicker_{0}_{1} ", player.PlayerId, round);
                    }
                }
                sw.WriteLine(@"= 1;");
            }
        }

        private void AddConstraintsOfExactlyOneDesignatedCaptainEachRound(
            StringWriter sw, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write("OneCaptainPerTeamConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    if (IgnoreAllowedRoles 
                        || player.AllowedRole == AllowedRole.Captain 
                        || player.AllowedRounds == AllowedRounds.PlayOffs)
                    {
                        sw.Write(@"+ IsCaptain_{0}_{1} ", player.PlayerId, round);
                    }
                }
                sw.WriteLine(@"= 1;");
            }
        }

        private void AddConstraintsOnMaximumPlayersPerRealTeamEachRound(StringWriter sw,
            IDictionary<int, IList<PlayerModel>> playerListsByRound, string[] teams)
        {
            int maxPlayersPerTeam = 3;
            foreach (string team in teams)
            {
                for (int round = CurrentRound; round <= LastRound; round++)
                {
                    if (playerListsByRound[round].Any(player => player.Team == team))
                    {
                        if (round <= Constants.LAST_ROUND_ROBIN_ROUND)
                        {
                            maxPlayersPerTeam = 3;
                        }
                        else
                        {
                            if (round == Constants.LAST_ROUND_IN_SEASON)
                            {
                                maxPlayersPerTeam = 12;
                            }
                            else
                            {
                                maxPlayersPerTeam = 7;
                            }
                        }

                        // was: sw.Write(@"MaxPlayersPerTeam_{0}_{1}: ", team, round);
                        sw.Write(@"PlayersFromTeamConstraint_{0}_{1}: ", team, round);
                        foreach (PlayerModel player in playerListsByRound[round])
                        {
                            if (player.Team == team)
                            {
                                sw.Write(@"+ IsInTeam_{0}_{1} ", player.PlayerId, round);
                            }
                        }
                        sw.WriteLine(" = PlayersFromTeam_{0}_{1};", team, round);
                        // was: sw.WriteLine(" <= {0};", maxPlayersPerTeam);

                        sw.WriteLine(
                            @"MaxPlayersPerTeam_{0}_{1}: PlayersFromTeam_{0}_{1} <= {2};", 
                            team, round, maxPlayersPerTeam);
                    }
                }
            }
        }

        private static void AddCustomConstraintsOnTeamComposition(
            StringWriter sw, IEnumerable<string> teamCompositionConstraints)
        {
            Console.WriteLine("Custom constraints:");
            foreach (string constraint in teamCompositionConstraints)
            {
                sw.WriteLine(constraint);
                Console.WriteLine(constraint);
            }
            Console.WriteLine();
        }

        private void AddConstraintsToEnforceRequiredNumberOfPlayersPerPositionEachRound(StringWriter sw,
            IList<PositionModel> positions, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            foreach (PositionModel position in positions)
            {
                for (int round = CurrentRound; round <= LastRound; round++)
                {
                    sw.Write(@"PlayersPerPositionConstraint_{0}_{1}: ", position.Code, round);
                    foreach (PlayerModel player in playerListsByRound[round])
                    {
                        if (player.Position == position.Code)
                        {
                            sw.Write(@"+ IsInTeam_{0}_{1} ", player.PlayerId, round);
                        }
                    }
                    sw.WriteLine(" <= {0};", position.PlayersPerPosition + 1);
                }
            }
        }

        private void AddConstraintsOfExactlyOneSubstitutePerPositionEachRound(StringWriter sw,
            IList<PositionModel> positions, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            foreach (PositionModel position in positions)
            {
                for (int round = CurrentRound; round <= LastRound; round++)
                {
                    sw.Write(@"PlayersPerPositionConstraint_{0}_{1}: ", position.Code, round);
                    foreach (PlayerModel player in playerListsByRound[round])
                    {
                        if (player.Position == position.Code)
                        {
                            sw.Write(@"+ IsSubstitute_{0}_{1} ", player.PlayerId, round);
                        }
                    }
                    sw.WriteLine(" <= 1;");
                }
            }
        }

        private void AddConstraintsOnTotalCostsOfChosenPlayersPerRound(StringWriter sw,
            IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write(@"TotalCostConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    sw.Write(@"+ {0} IsInTeam_{1}_{2} ", player.Price, player.PlayerId, round);
                }
                sw.WriteLine(" <= {0};", MaxCostOfTeam);
            }
        }

        private void CalculateWhetherPlayerIsInTeamFromPreviousRoundsTeamAndTransfers( StringWriter sw,
            IDictionary<int, IList<PlayerModel>> playerListsByRound, IList<PlayerModel> nonPlayoffPlayers)
        {
            bool mustConstraintsStillBeAddedForNonPlayoffPlayersInRound19 = (CurrentRound <= 19 && LastRound >= 19);

            for (int round = CurrentRound; round <= LastRound; round++)
            {
                /* Constraint for non-playoff players in round 19: */
                if (round == 20 && mustConstraintsStillBeAddedForNonPlayoffPlayersInRound19)
                {
                    /* Is in team constraint: */
                    foreach (PlayerModel player in nonPlayoffPlayers)
                    {
                        sw.WriteLine("NonPlayoffPlayerIsInTeamConstraint_{0}_19: IsInTeam_{0}_19 = 0;", player.PlayerId);
                    }

                    /* Transfer out constraint: */
                    foreach (PlayerModel player in nonPlayoffPlayers)
                    {
                        sw.WriteLine(
                            "NonPlayoffPlayerTransfersOutConstraint_{0}_19: TransfersOut_{0}_19 = IsInTeam_{0}_18;", 
                            player.PlayerId);
                    }

                    mustConstraintsStillBeAddedForNonPlayoffPlayersInRound19 = false;
                }

                foreach (PlayerModel player in playerListsByRound[round])
                {
                    string previousRoundTerm = String.Empty;

                    if (round == CurrentRound)
                    {
                        if (player.PreviousRole != "X" && player.PreviousRole != " ")
                        {
                            previousRoundTerm = "1";
                        }
                    }
                    else  // A player who is only added for the playoff rounds will not have been in the team in round 17...
                        if (round != Constants.LAST_ROUND_ROBIN_ROUND || (player.AllowedRounds != AllowedRounds.PlayOffs))
                        {
                            previousRoundTerm = String.Format("+ IsInTeam_{0}_{1}", player.PlayerId, round - 1);
                        }

                    sw.WriteLine(
                        @"TransfersConstraint_{0}_{1}: IsInTeam_{0}_{1} = {2} + TransfersIn_{0}_{1} - TransfersOut_{0}_{1} ;",
                        player.PlayerId, round, previousRoundTerm);
                }
            }
            /* TODO: In case last round is round 19...
            if (mustConstraintsStillBeAddedForNonPlayoffPlayersInRound19) ...
            */
        }

        private static void AddConstraintsToPreventAPlayerBeingTransferredInAndOutInASingleRound(
            StringWriter sw, IList<PlayerModel> playersByRound)
        {
            foreach (PlayerModel player in playersByRound)
            {
                sw.WriteLine(
                    "TransfersInOutConstraint_{0}_{1}: TransfersIn_{0}_{1} + TransfersOut_{0}_{1} <= 1 ;",
                    player.PlayerId, player.Round);
            }
        }

        private void CalculateTotalTransfersForEachRoundFromPlayersTransferredIn(
            StringWriter sw, IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.Write(@"TransfersForRoundConstraint_{0}: ", round);
                foreach (PlayerModel player in playerListsByRound[round])
                {
                    sw.Write(@"+ TransfersIn_{0}_{1} ", player.PlayerId, round);
                }
                sw.WriteLine("= TransfersForRound_{0} ;", round);
            }
        }

        private void AddMaxTransfersPerRoundConstraints(StringWriter sw)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                int maxTransfersPerRound = 6;
                if (round >= 19)
                {
                    if (round == Constants.LAST_ROUND_IN_SEASON)
                    {
                        maxTransfersPerRound = 14;
                    }
                    else
                    {
                        maxTransfersPerRound = 8;
                    }
                }

                if (round != 1)
                {
                    sw.WriteLine(@"MaxTransfersPerRoundConstraint_{0}: TransfersForRound_{0} <= {1};",
                        round, maxTransfersPerRound);
                }
            }
        }

        private void AddTotalTransfersConstraint(StringWriter sw)
        {
            sw.Write(@"TotalTransfersConstraint: ");
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                if (round != 1)
                {
                    sw.Write(@"+ TransfersForRound_{0} ", round);
                }
            }
            sw.WriteLine("<= {0} ;", MaxTransfersInCurrentWindow);
        }

        private void AddTransferAllocationConstraints(StringWriter sw,
            IList<TransferConstraint> transferAllocations)
        {
            foreach (var transferAllocation in transferAllocations)
            {
                sw.Write(@"TransfersAfter{0}RoundsConstraint: ", transferAllocation.Rounds);
                for (int round = CurrentRound; round < CurrentRound + transferAllocation.Rounds; round++)
                {
                    if (round != 1)
                    {
                        sw.Write(@"+ TransfersForRound_{0} ", round);
                    }
                }
                sw.WriteLine("<= {0} ;", transferAllocation.Transfers);
            }
        }

        private void AddRangeConstraintsOnBinaryVariablesDefinedAsInts( 
            StringWriter sw, string[] decisionVariableNames,
            IList<PlayerModel> playersByRound)
        {
            if (!UseBinaryVariables)
            {
                foreach (PlayerModel player in playersByRound)
                {
                    foreach (string variableName in decisionVariableNames)
                    {
                        if (!IgnoreAllowedRoles)
                        {
                            if (variableName == "IsKicker"
                                && player.AllowedRole != AllowedRole.Kicker
                                && player.AllowedRounds != AllowedRounds.PlayOffs)
                            {
                                continue;
                            }

                            if (variableName == "IsCaptain"
                                && player.AllowedRole != AllowedRole.Captain
                                && player.AllowedRounds != AllowedRounds.PlayOffs)
                            {
                                continue;
                            }
                        }

                        sw.WriteLine(@"0 <= {0}_{1}_{2} <= 1;", variableName, player.PlayerId, player.Round);
                        // was: sw.WriteLine(@"{0}_IsZeroOneVariableConstraint_{1}_{2}: 0 <= {0}_{1}_{2} <= 1;", variableName, player.PlayerId, player.Round);
                    }
                }
            }
        }

        private void DefineTeamVariablesPerRound(StringWriter sw, 
            IDictionary<int, IList<PlayerModel>> playerListsByRound, string[] teams)
        {
            foreach (string team in teams)
            {
                for (int round = CurrentRound; round <= LastRound; round++)
                {
                    if (playerListsByRound[round].Any(player => player.Team == team))
                    {
                        sw.WriteLine("int PlayersFromTeam_{0}_{1};", team, round);
                    }
                }
            }
        }

        private void DefineRoundVariables(StringWriter sw)
        {
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                sw.WriteLine(@"int TransfersForRound_{0};", round);
                sw.WriteLine(@"free PointsForRound_{0};", round);
            }
        }

        private void DefinePlayerVariables(StringWriter sw, string[] decisionVariableNames,
            IList<PlayerModel> nonPlayoffPlayers, IList<PlayerModel> playersByRound)
        {
            bool mustVariablesStillBeAddedForNonPlayoffPlayersInRound19 = (CurrentRound <= 19 && LastRound >= 19);
            string variableType = UseBinaryVariables ? "bin" : "int";

            foreach (PlayerModel player in playersByRound)
            {
                /* Add variables for non-playoff players in round 19 in the correct place (i.e. before the first round 20 variable): */
                if (player.Round == 20 && mustVariablesStillBeAddedForNonPlayoffPlayersInRound19)
                {
                    /* Transfer out constraint: */
                    foreach (PlayerModel nonPlayoffPlayer in nonPlayoffPlayers)
                    {
                        sw.WriteLine(@"{0} IsInTeam_{1}_19;", variableType, nonPlayoffPlayer.PlayerId);
                        sw.WriteLine(@"{0} TransfersOut_{1}_19;", variableType, nonPlayoffPlayer.PlayerId);
                    }
                    mustVariablesStillBeAddedForNonPlayoffPlayersInRound19 = false;
                }

                /* Add other variables as normal: */
                foreach (string variableName in decisionVariableNames)
                {
                    if (!IgnoreAllowedRoles && variableName == "IsKicker" && player.AllowedRole != AllowedRole.Kicker)
                    {
                        continue;
                    }

                    if (!IgnoreAllowedRoles && variableName == "IsCaptain" && player.AllowedRole != AllowedRole.Captain)
                    {
                        continue;
                    }

                    sw.WriteLine(@"{0} {1}_{2}_{3};", variableType, variableName, player.PlayerId, player.Round);
                }
            }
            /* TODO: In case last round is round 19...
            if (mustVariablesStillBeAddedForNonPlayoffPlayersInRound19) ...
            */
        }

        #endregion // Public methods
    }
}

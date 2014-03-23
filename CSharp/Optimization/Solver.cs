using System;
using System.Text;
using System.Text.RegularExpressions;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Diagnostics;
using AndrewTweddle.Tools.Utilities.CommandLine;

namespace FantasyLeague
{
    public class Solver
    {
        #region Constants

        private const string DEFAULT_PATH_TO_LPSOLVE_COMMAND_LINE_APP 
            = @"C:\toolkit\technology\OR\lpsolve64\lp_solve.exe";
        private const int DEFAULT_CURRENT_ROUND = 2;
        private const int DEFAULT_ROUNDS_TO_PROJECT_FORWARD = 3;
        private const int DEFAULT_MAX_COST_OF_TEAM = 200;
        private const int DEFAULT_TOTAL_CANDIDATE_COUNT = 100;
        private const int DEFAULT_KICKER_CANDIDATE_COUNT = 15;
        private const int DEFAULT_CAPTAIN_CANDIDATE_COUNT = 50;
        private const bool DEFAULT_IGNORE_ALLOWED_ROLES = true;
        private const int DEFAULT_TRANSFERS_FOR_THE_SEASON = 70;
        private const int DEFAULT_TRANSFERS_TO_RETAIN_FOR_PLAY_OFFS = 30;

        #endregion

        #region Private Member Variables

        private int currentRound = DEFAULT_CURRENT_ROUND;
        private List<TransferConstraint> transferAllocations = new List<TransferConstraint>();

        #endregion

        #region Public Properties

        #region Properties representing algorithm parameterizations

        // Note: these could easily be turned into consts, since the choices are now apparent:
        public bool UseBinaryVariables { get; set; }
        public bool OptimizeCandidatesForTeamVariety { get; set; }
        public bool ScoreLastRoundAsSumOfRemainingRounds { get; set; }
        public bool BreakAtFirst { get; set; }

        /// <summary>
        /// Indicates whether filtering by candidate type is enabled or not
        /// </summary>
        public bool IgnoreAllowedRoles { get; set; }

        public int TotalCandidateCount { get; set; }
        public int KickerCandidateCount { get; set; }
        public int CaptainCandidateCount { get; set; }

        public double MaxCostOfTeam { get; set; }
        public string PathToLpSolveCommandLineApp { get; set; }

        #endregion  // End of: Properties representing algorithm parameterizations

        #region Properties representing algorithm inputs

        public string RootFolder { get; private set; }
        public string ModelSubPath { get; private set; }
        public int Season { get; set; }
        public int CurrentRound 
        {
            get
            {
                return currentRound;
            }
            set
            {
                currentRound = value;
                if (LastRound < currentRound)
                {
                    LastRound = currentRound + DEFAULT_ROUNDS_TO_PROJECT_FORWARD;
                    // TODO: Ensure this can't go beyond the end of the season
                }
            }
        }
        public int LastRound { get; set; }

        /// <summary>
        /// This containts a list of transfer constraints for various numbers of rounds ahead.
        /// This limits the number of transfer allocations which may be used by that number of rounds.
        /// This is to prevent the algorithm from using too many transfers too early,
        /// as this could limit the flexibility to adjust to changing situations 
        /// (e.g. injuries) in subsequent rounds.
        /// </summary>
        /// <remarks>
        /// Ideally TransferAllocations should be of type IList&lt;TransferConstraint&gt;.
        /// However the FindIndex method is only defined on the List&lt;TransferConstraint&gt;.
        /// It would be even better to expose an AddTransferAllocation() method and keep the list private.
        /// Due to time pressure, I chose to do it this way instead.
        /// </remarks>
        public List<TransferConstraint> TransferAllocations
        {
            get
            {
                return transferAllocations;
            }
            set
            {
                if (value == null)
                {
                    throw new ArgumentNullException("TransferAllocations", "The TransferAllocations list must not be null");
                }
                transferAllocations = value;
            }
        }

        /// <summary>
        /// If TargetScorePerRound is set, then the LPSolve linear programming tool 
        /// will stop when it reaches this value. 
        /// This allows trading off some optimality for looking further ahead.
        /// </summary>
        public double? TargetScorePerRound { get; set; }

        #endregion  // End of: Properties representing algorithm inputs

        #region Calculated properties

        public int PreviousRound
        {
            get
            {
                return CurrentRound - 1;
            }
        }

        public int OtherPlayerCandidateCount
        {
            get
            {
                return TotalCandidateCount - CaptainCandidateCount - KickerCandidateCount;
            }
        }

        #endregion  // End of: Calculated properties

        #endregion  // End of: Public Properties

        #region Private Properties

        private int MaxTransfersInCurrentWindow { get; set; }

        #endregion

        #region Constructors

        public Solver(string rootFolder, string modelSubPath, int season)
        {
            RootFolder = rootFolder;
            ModelSubPath = modelSubPath;
            Season = season;
            TotalCandidateCount = DEFAULT_TOTAL_CANDIDATE_COUNT;
            KickerCandidateCount = DEFAULT_KICKER_CANDIDATE_COUNT;
            CaptainCandidateCount = DEFAULT_CAPTAIN_CANDIDATE_COUNT;
            MaxCostOfTeam = DEFAULT_MAX_COST_OF_TEAM;
            PathToLpSolveCommandLineApp = DEFAULT_PATH_TO_LPSOLVE_COMMAND_LINE_APP;
            IgnoreAllowedRoles = DEFAULT_IGNORE_ALLOWED_ROLES;
        }

        #endregion // End of: Constructors

        #region Public Methods

        public void Run()
        {
            DetermineTransferConstraints();  // Note: This sets property MaxTransfersInCurrentWindow

            string pathToLpsFile = String.Format(
                @"{0}\DataByRound\Round{1}\OptimisationModels\{2}\optimization.lp", 
                RootFolder, CurrentRound, ModelSubPath);
            
            // Load data from disk:
            List<PlayerModel> pmModels = LoadPlayerModelsFromDisk();
            IList<PositionModel> positions = LoadPositionModelsFromDisk();
            Console.WriteLine("Number of positions: {0}", positions.Count);
            IEnumerable<string> teamCompositionConstraints = LoadCustomLinearProgramConstraintsFromDisk();
            IList<string> finalists = LoadPredictedFinalistsFromDisk();
            DisplayPredictedFinalists(finalists);

            /* Choose candidate players from amongst all players:
             * 
             * Note: This is to limit the size of the model
             *       otherwise performance suffers.
             */
            IList<PlayerModel> kickers;
            IList<PlayerModel> captains;
            IList<PlayerModel> otherPlayers;
            IList<PlayerModel> playoffPlayers;
            ChooseCandidatePlayers(pmModels, positions, finalists, 
                out kickers, out captains, out otherPlayers, out playoffPlayers);

            // Write candidates to file:
            string candidatesFilePath = String.Format("{0}.candidates", pathToLpsFile);
            WriteCandidatesToFile(candidatesFilePath, kickers, captains, otherPlayers, playoffPlayers);
            
            // Get a list of all round-robin players:
            IList<PlayerModel> roundRobinPlayers = GetRoundRobinCandidatePlayers(pmModels);
            
            // Get a list of players for each round:
            IDictionary<int, IList<PlayerModel>> playerListsByRound 
                = GetListsOfCandidatePlayerModelsKeyedByRoundInPlanningWindow(
                    playoffPlayers, roundRobinPlayers);
            
            // For round 19, we will need to ensure that all non-playoff players have been transferred out...
            IList<PlayerModel> nonPlayoffPlayers 
                = roundRobinPlayers.Except(playoffPlayers)
                                   .OrderBy(player => player.FullName)
                                   .ToList();
            
            // Generate data for each combination of player and round in the current window:
            IList<PlayerModel> playersByRound
                = GenerateListOfCandidatePlayersPerRoundInPlanningWindow(playerListsByRound);

            SetScoreForLastRoundInPlanningWindowToSumOfAllSubsequentRounds(playersByRound);

            // Generate and solve model:
            GenerateAndSaveLPSModelToDisk(pathToLpsFile, positions, 
                teamCompositionConstraints, playerListsByRound, 
                nonPlayoffPlayers, playersByRound);
            string outputs = LaunchLPSolverAndGetOutputs(pathToLpsFile);

            // Write LPSolve outputs to a file:
            string outputsFileName = String.Format("{0}.outputs", pathToLpsFile);
            File.WriteAllText(outputsFileName, outputs);

            ParseAndDisplayLPSolveOutputs(pathToLpsFile, playersByRound, outputs);
            
            return;
        }

        #endregion

        #region Private Methods

        private void DetermineTransferConstraints()
        {
            int transfersLeft = DEFAULT_TRANSFERS_FOR_THE_SEASON;
            int transfersToRetain = DEFAULT_TRANSFERS_TO_RETAIN_FOR_PLAY_OFFS;
            double transfersAvailable = transfersLeft - transfersToRetain;
            double averageTransfersPerRound = transfersAvailable / (Constants.LAST_ROUND_ROBIN_ROUND - PreviousRound);
            MaxTransfersInCurrentWindow = (int)Math.Floor(averageTransfersPerRound * (LastRound - PreviousRound));
            if (TransferAllocations.Count > 0 && TransferAllocations.Any(ta => ta.Rounds == LastRound - PreviousRound))
            {
                int indexOfLastRoundTransfer = TransferAllocations.FindIndex(ta => ta.Rounds == LastRound - PreviousRound);
                MaxTransfersInCurrentWindow = TransferAllocations[indexOfLastRoundTransfer].Transfers;
                TransferAllocations.RemoveAt(indexOfLastRoundTransfer);
            }

            // Display summary:
            Console.WriteLine();
            Console.WriteLine("Previous round                  = {0}", PreviousRound);
            Console.WriteLine("Current round                   = {0}", CurrentRound);
            Console.WriteLine("Last round in window            = {0}", LastRound);
            Console.WriteLine("Rounds in current window        = {0}", LastRound - PreviousRound);
            Console.WriteLine("Transfers left                  = {0}", transfersLeft);
            Console.WriteLine("Transfers to retain             = {0}", transfersToRetain);
            Console.WriteLine("Transfers available             = {0}", transfersAvailable);
            Console.WriteLine("Round robin rounds left         = {0}", Constants.LAST_ROUND_ROBIN_ROUND - PreviousRound);
            Console.WriteLine("Average transfers per round     = {0}", averageTransfersPerRound);
            Console.WriteLine("Max transfers in current window = {0}", MaxTransfersInCurrentWindow);

            // Display transfer allocations:
            string transferAllocDesc = String.Empty;
            if (TransferAllocations.Count > 0)
            {
                StringBuilder sbTransferAllocDesc = new StringBuilder();
                foreach (var transferAllocation in TransferAllocations)
                {
                    Console.WriteLine("Max {0} transfers after {1} rounds", 
                        transferAllocation.Transfers, transferAllocation.Rounds);
                    sbTransferAllocDesc.AppendFormat("_{0}TfrsAfter{1}Rounds", 
                        transferAllocation.Transfers, transferAllocation.Rounds);
                }
                transferAllocDesc = sbTransferAllocDesc.ToString();
            }

            Console.WriteLine();
        }

        private List<PlayerModel> LoadPlayerModelsFromDisk()
        {
            string playerModelFilePath = String.Format(
                @"{0}\DataByRound\Round{1}\OptimisationModels\{2}\PlayerModel.csv",
                RootFolder, CurrentRound, ModelSubPath);
            PlayerModelLoader pmLoader = new PlayerModelLoader();
            List<PlayerModel> pmModels = pmLoader.Load(playerModelFilePath, CurrentRound).ToList();
            Console.WriteLine("Number of players: {0}", pmModels.Count);
            return pmModels;
        }

        private IList<PositionModel> LoadPositionModelsFromDisk()
        {
            string positionModelFilePath = String.Format(
                @"{0}\MasterData\{0}\Rules\PositionRules.csv",
                RootFolder, Season);
            PositionModelLoader posLoader = new PositionModelLoader();
            IList<PositionModel> positions = posLoader.Load(positionModelFilePath).ToList();
            return positions;
        }

        private IEnumerable<string> LoadCustomLinearProgramConstraintsFromDisk()
        {
            string customConstraintsFilePath = String.Format(
                @"{0}\DataByRound\Round{1}\OptimisationModels\{2}\CustomConstraints.txt",
                RootFolder, CurrentRound, ModelSubPath);
            IEnumerable<string> teamCompositionConstraints;
            if (File.Exists(customConstraintsFilePath))
            {
                teamCompositionConstraints = File.ReadAllLines(customConstraintsFilePath);
            }
            else
            {
                teamCompositionConstraints = new string[0];
            }
            return teamCompositionConstraints;
        }

        private IList<string> LoadPredictedFinalistsFromDisk()
        {
            string predictedFinalistsFilePath = String.Format(
                @"{0}\DataByRound\Round{1}\OptimisationModels\{2}\PredictedFinalists.csv",
                RootFolder, CurrentRound, ModelSubPath);
            PredictedFinalistsLoader finalistsLoader = new PredictedFinalistsLoader();
            IList<string> finalists 
                = finalistsLoader.LoadTeamCodesOfPredictedFinalists(predictedFinalistsFilePath)
                                 .ToList();
            return finalists;
        }

        private static void DisplayPredictedFinalists(IList<string> finalists)
        {
            int finalistSpot = 1;
            foreach (string finalist in finalists)
            {
                Console.WriteLine("Finalist {0}: {1}", finalistSpot++, finalist);
            }
        }

        private void ChooseCandidatePlayers(List<PlayerModel> pmModels, IList<PositionModel> positions, 
            IList<string> finalists, out IList<PlayerModel> kickers, out IList<PlayerModel> captains, 
            out IList<PlayerModel> otherPlayers, out IList<PlayerModel> playoffPlayers)
        {
            // Use the top kicker in each team as a kicking candidate, but only consider flyhalves:
            kickers = GetKickerCandidates(pmModels);
            SetAllowedRoleForPlayers(kickers, AllowedRole.Kicker);

            // Use the top player in each position as a captain candidate, but don't consider flyhalves:
            captains = GetCaptainCandidates(pmModels);
            SetAllowedRoleForPlayers(captains, AllowedRole.Captain);

            /* Fill up the remaining candidate positions with the best 1 or 2
             * non-flyhalf candidates in each position, ordered by NonKickerTotal:
             */
            otherPlayers = GetRemainingCandidates(pmModels);
            SetAllowedRoleForPlayers(otherPlayers, AllowedRole.Other);

            AddPlayersWhoAreCurrentlyInTheTeamAsCandidates(pmModels, kickers, captains, otherPlayers);

            SetAllowedRoundsForCandidatesToRoundRobinRounds(pmModels);

            /* Determine candidates for the play-off rounds: */
            playoffPlayers = DetermineCandidatesForThePlayoffRounds(pmModels, positions, finalists);
            SetAllowedRoundsForPlayoffPlayers(playoffPlayers);
        }

        private static void SetAllowedRoundsForCandidatesToRoundRobinRounds(List<PlayerModel> pmModels)
        {
            foreach (PlayerModel player in pmModels)
            {
                if (player.AllowedRole != AllowedRole.Excluded)
                {
                    player.AllowedRounds = AllowedRounds.RoundRobin;
                }
            }
        }

        private static void SetAllowedRoleForPlayers(IList<PlayerModel> players, AllowedRole role)
        {
            foreach (PlayerModel player in players)
            {
                player.AllowedRole = role;
            }
        }

        private static IList<PlayerModel> GetKickerCandidates(List<PlayerModel> pmModels)
        {
            IList<PlayerModel> kickers =
                (from player in pmModels
                 where player.GamesPlayed > 4
                    && player.Position == "FLH"
                 group player by player.Team
                )
                .Select(grouping => grouping.OrderByDescending(pm => pm.KickerTotal)
                .FirstOrDefault())
                .Where(pm => pm != null)
                .ToList();
            return kickers;
        }

        private IList<PlayerModel> GetCaptainCandidates(List<PlayerModel> pmModels)
        {
            /* Use the top 50 non-kicking players as captain candidates, 
             * but no more than 1 per team and position, 
             * and excluding flyhalves: 
             */
            var playersGroupedByPositionAndTeam =
                from player in pmModels
                where player.GamesPlayed > 4
                    && player.AllowedRole == AllowedRole.Excluded
                    && player.Position != "FLH"
                group player by new { Position = player.Position, Team = player.Team };

            IEnumerable<PlayerModel> topPlayerPerTeamAndPosition
                = playersGroupedByPositionAndTeam.SelectMany(
                    g => g.OrderByDescending(pm => pm.NonKickerTotal
                  )
                  .Take(1));
            // bug found after round 7... was: = playersGroupedByPositionAndTeam.SelectMany(g => g.Take(1));

            IList<PlayerModel> captains =
                (from player in topPlayerPerTeamAndPosition
                 orderby player.NonKickerTotal descending
                 select player
                )
                .Take(CaptainCandidateCount)
                .ToList();
            return captains;
        }

        private IList<PlayerModel> GetRemainingCandidates(IList<PlayerModel> pmModels)
        {
            /* Use the top 1 or 2 remaining candidates per team and position, 
             * but only enough of these to fill the remaining candidate positions: 
             */
            int maxRemainingCandidatesPerTeamAndPosition = OptimizeCandidatesForTeamVariety ? 1 : 2;

            IEnumerable<PlayerModel> topRemainingPlayerPerTeamAndPosition
                = (from player in pmModels
                   where player.GamesPlayed > 4
                      && player.AllowedRole == AllowedRole.Excluded
                      && player.Position != "FLH"
                   group player by new { Position = player.Position, Team = player.Team }
                  )
                  .SelectMany(g => g.Take(maxRemainingCandidatesPerTeamAndPosition));

            List<PlayerModel> otherPlayers =
                (from player in topRemainingPlayerPerTeamAndPosition
                 orderby player.NonKickerTotal descending
                 select player
                )
                .Take(OtherPlayerCandidateCount).ToList();
            return otherPlayers;
        }

        private static void AddPlayersWhoAreCurrentlyInTheTeamAsCandidates(IList<PlayerModel> pmModels,
            IList<PlayerModel> kickers, IList<PlayerModel> captains, IList<PlayerModel> otherPlayers)
        {
            /* Ensure players who were in the team last round, are also in the model this round: */
            foreach (PlayerModel player in pmModels)
            {
                if (player.AllowedRole == AllowedRole.Excluded 
                    && player.PreviousRole != " " 
                    && player.PreviousRole != "X")
                {
                    switch (player.PreviousRole)
                    {
                        case "C":
                            player.AllowedRole = AllowedRole.Captain;
                            captains.Add(player);
                            break;
                        case "K":
                            player.AllowedRole = AllowedRole.Kicker;
                            kickers.Add(player);
                            break;
                        default:
                            player.AllowedRole = AllowedRole.Other;
                            otherPlayers.Add(player);
                            break;
                    }
                }
            }
        }

        private static List<PlayerModel> DetermineCandidatesForThePlayoffRounds(
            IList<PlayerModel> pmModels, IList<PositionModel> positions, 
            IList<string> finalists)
        {
            List<PlayerModel> playoffPlayers = new List<PlayerModel>();

            var playoffPlayerGroupings
                = from player in pmModels
                  join team in finalists
                    on player.Team equals team
                  join position in positions
                    on player.Position equals position.Code
                  where player.GamesPlayed > 4
                  group player 
                     by new { Position = player.Position, 
                              Team = player.Team, 
                              PlayersPerPosition = position.PlayersPerPosition 
                            };

            foreach (var grouping in playoffPlayerGroupings)
            {
                int playersPerPosition = grouping.Key.PlayersPerPosition;
                if (playersPerPosition == 1)
                {
                    playersPerPosition = 2;
                }
                playoffPlayers.AddRange(
                    grouping.OrderByDescending(pm => pm.NonKickerTotal)
                            .Take(playersPerPosition));
            }
            playoffPlayers = playoffPlayers.OrderBy(player => player.FullName)
                                           .ToList();
            return playoffPlayers;
        }

        private static void SetAllowedRoundsForPlayoffPlayers(IList<PlayerModel> playoffPlayers)
        {
            foreach (PlayerModel player in playoffPlayers)
            {
                if (player.AllowedRounds == AllowedRounds.RoundRobin)
                {
                    player.AllowedRounds = AllowedRounds.All;
                }
                else
                {
                    player.AllowedRounds = AllowedRounds.PlayOffs;
                }
            }
        }

        private static void WriteCandidatesToFile(string candidatesFilePath, 
            IList<PlayerModel> kickers, IList<PlayerModel> captains, 
            IList<PlayerModel> otherPlayers, IList<PlayerModel> playoffPlayers)
        {
            StringBuilder sbCandidates = new StringBuilder();
            sbCandidates.Append("*** ROUND ROBIN ROUNDS: ***\r\n\r\n");
            sbCandidates.Append("Kickers:\r\n");
            sbCandidates.Append("========:\r\n");
            foreach (PlayerModel player in kickers.OrderBy(p => p.Position).ThenBy(p => p.Team))
            {
                sbCandidates.AppendFormat("{0,4} : {1,3} - {2}\r\n", 
                    player.Position, player.Team, player.FullName);
            }
            sbCandidates.Append("\r\nCaptains:\r\n");
            sbCandidates.Append("========:\r\n");
            foreach (PlayerModel player in captains.OrderBy(p => p.Position).ThenBy(p => p.Team))
            {
                sbCandidates.AppendFormat("{0,4} : {1,3} - {2}\r\n", 
                    player.Position, player.Team, player.FullName);
            }
            sbCandidates.Append("\r\nOther Players:\r\n");
            sbCandidates.Append("=============:\r\n");
            foreach (PlayerModel player in otherPlayers.OrderBy(p => p.Position).ThenBy(p => p.Team))
            {
                sbCandidates.AppendFormat("{0,4} : {1,3} - {2}\r\n", 
                    player.Position, player.Team, player.FullName);
            }

            sbCandidates.Append("*** PLAY-OFF ROUNDS: ***\r\n\r\n");
            foreach (PlayerModel player in playoffPlayers.OrderBy(p => p.Position).ThenBy(p => p.Team))
            {
                sbCandidates.AppendFormat("{0,4} : {1,3} - {2}\r\n", 
                    player.Position, player.Team, player.FullName);
            }
            File.WriteAllText(candidatesFilePath, sbCandidates.ToString());
        }

        private static IList<PlayerModel> GetRoundRobinCandidatePlayers(List<PlayerModel> pmModels)
        {
            IList<PlayerModel> roundRobinPlayers 
                = pmModels.Where(player => player.AllowedRole != AllowedRole.Excluded)
                          .ToList();
            return roundRobinPlayers;
        }

        private IDictionary<int, IList<PlayerModel>> GetListsOfCandidatePlayerModelsKeyedByRoundInPlanningWindow(
            IList<PlayerModel> playoffPlayers, IList<PlayerModel> roundRobinPlayers)
        {
            IDictionary<int, IList<PlayerModel>> playerListsByRound = new Dictionary<int, IList<PlayerModel>>();
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                if (round < Constants.LAST_ROUND_ROBIN_ROUND)
                {
                    playerListsByRound[round] = roundRobinPlayers;
                }
                else
                    if (round > Constants.LAST_ROUND_ROBIN_ROUND)
                    {
                        playerListsByRound[round] = playoffPlayers;
                    }
                    else
                    {
                        /* In round 18 we include all round robin players plus all play-off players,
                         * so that a transition from the one set to the other can be made in round 18:
                         */
                        playerListsByRound[round] 
                            = roundRobinPlayers
                                .Union(playoffPlayers)
                                .OrderBy(player => player.FullName)
                                .ToList();
                    }
            }
            return playerListsByRound;
        }

        private IList<PlayerModel> GenerateListOfCandidatePlayersPerRoundInPlanningWindow(
            IDictionary<int, IList<PlayerModel>> playerListsByRound)
        {
            IEnumerable<PlayerModel> playersByRoundEnumerable = new List<PlayerModel>();
            for (int round = CurrentRound; round <= LastRound; round++)
            {
                int r = round;
                playersByRoundEnumerable = playersByRoundEnumerable.Union(
                    playerListsByRound[round].Select(player => player.Clone(r)));
            }
            IList<PlayerModel> playersByRound = playersByRoundEnumerable.ToList();
            return playersByRound;
        }

        private void SetScoreForLastRoundInPlanningWindowToSumOfAllSubsequentRounds(
            IList<PlayerModel> playersByRound)
        {
            if (ScoreLastRoundAsSumOfRemainingRounds)
            {
                foreach (PlayerModel player in playersByRound.Where(p => p.Round == LastRound))
                {
                    player.ScoreAllRemainingRounds = true;
                }
            }
        }

        private void GenerateAndSaveLPSModelToDisk(string pathToLpsFile, 
            IList<PositionModel> positions, 
            IEnumerable<string> teamCompositionConstraints, 
            IDictionary<int, IList<PlayerModel>> playerListsByRound, 
            IList<PlayerModel> nonPlayoffPlayers, 
            IList<PlayerModel> playersByRound)
        {
            LPSModelGenerator lpsGenerator = new LPSModelGenerator();
            lpsGenerator.CurrentRound = CurrentRound;
            lpsGenerator.LastRound = LastRound;
            lpsGenerator.IgnoreAllowedRoles = IgnoreAllowedRoles;
            lpsGenerator.MaxCostOfTeam = MaxCostOfTeam;
            lpsGenerator.MaxTransfersInCurrentWindow = MaxTransfersInCurrentWindow;
            lpsGenerator.UseBinaryVariables = UseBinaryVariables;

            string lpsModel = lpsGenerator.Generate(
                TransferAllocations,
                positions,
                teamCompositionConstraints,
                playerListsByRound,
                nonPlayoffPlayers,
                playersByRound);

            System.IO.File.WriteAllText(pathToLpsFile, lpsModel);
        }

        private string LaunchLPSolverAndGetOutputs(string pathToLpsFile)
        {
            string outputs;
            Console.WriteLine();
            Stopwatch swatch = Stopwatch.StartNew();
            try
            {
                string commandLineArguments = String.Format(
                    "-lp \"{0}\" -S -B5 -Bg -Bd -Bc {1}{2}",
                    pathToLpsFile,
                    TargetScorePerRound.HasValue
                        ? "-o " + (TargetScorePerRound.Value * (LastRound - PreviousRound)).ToString()
                        : String.Empty,
                    BreakAtFirst ? " -f" : String.Empty);
                Console.WriteLine("Running lpsolve {0}", commandLineArguments);

                outputs = CommandLineHelper.Run(PathToLpSolveCommandLineApp, commandLineArguments);
            }
            finally
            {
                swatch.Stop();
                Console.WriteLine();
                Console.WriteLine("Finished. Duration = {0}", swatch.Elapsed);
                Console.WriteLine();
            }
            return outputs;
        }

        private void ParseAndDisplayLPSolveOutputs(string pathToLpsFile, IList<PlayerModel> playersByRound, string outputs)
        {
            string[] lines = outputs.Split(new string[] { Environment.NewLine }, StringSplitOptions.RemoveEmptyEntries);

            StringBuilder sbOutput = new StringBuilder();
            StringWriter swOutput = new StringWriter(sbOutput);
            string optimalValueText = lines[0];
            int initialLinesToSkip = 2;

            if (optimalValueText.StartsWith("This problem is infeasible"))
            {
                Console.WriteLine(optimalValueText);
                Console.WriteLine();
            }
            else
            {
                if (optimalValueText.StartsWith("Suboptimal solution"))
                {
                    Console.WriteLine(optimalValueText);
                    Console.WriteLine();

                    optimalValueText = lines[1];
                    initialLinesToSkip = 3;
                }
                string optimalValueHeader = "Value of objective function: ";
                if (optimalValueText.StartsWith(optimalValueHeader))
                {
                    optimalValueText = optimalValueText.Substring(optimalValueHeader.Length);
                }
                else
                {
                    optimalValueText = "0";
                    for (int i = 0; i < lines.Length; i++)
                    {
                        if (lines[i].StartsWith(optimalValueHeader))
                        {
                            initialLinesToSkip = i + 2;
                            optimalValueText = lines[i].Substring(optimalValueHeader.Length);
                            break;
                        }
                    }
                }
                GenerateAndDisplayOptimalValue(swOutput, lines, optimalValueText);
                DisplayExpectedScoresPerRound(lines, initialLinesToSkip);

                List<RawVariableValue> rawVariableValues 
                    = ExtractRawVariableValuesFromLPSolveOutputs(lines, initialLinesToSkip);

                foreach (var vv in rawVariableValues.Where(vv => vv.Value != 0))
                {
                    swOutput.WriteLine("{0} = {1}", vv.UnparsedVariableName, vv.Value);
                }
                swOutput.Flush();
                string pathToOutputFile = String.Format("{0}.txt", pathToLpsFile);
                System.IO.File.WriteAllText(pathToOutputFile, sbOutput.ToString());

                Dictionary<string, RawVariableValue> variableValueMap 
                    = rawVariableValues.ToDictionary(vv => vv.UnparsedVariableName);

                /* The following is potentially very useful for further automation, but is not yet used:
                IList<VariableValue> variableValues 
                    = ExtractVariableValuesFromRawVariableValues(rawVariableValues).ToList();
                */

                UpdatePlayerModelsFromLPSolveOutputs(playersByRound, variableValueMap);
                DisplayWarningsForPlayersChosenForThisRoundWhichAreNotInTheTeamSheet(playersByRound);
            }
        }

        private void GenerateAndDisplayOptimalValue(StringWriter swOutput, 
            string[] lines, string optimalValueText)
        {
            double optimalValue = 0.0;
            bool canParseOptimal = double.TryParse(optimalValueText, out optimalValue);

            if (canParseOptimal)
            {
                Console.WriteLine("Optimal value: {0}", optimalValue);
                Console.WriteLine("Value per round: {0}", optimalValue / (LastRound - PreviousRound));

                swOutput.WriteLine("Optimal value: {0}", optimalValue);
                swOutput.WriteLine("Value per round: {0}", optimalValue / (LastRound - PreviousRound));
            }
            else
            {
                Console.WriteLine("Optimum value can't be parsed: {0}", optimalValueText);
                swOutput.WriteLine("Optimum value can't be parsed: {0}", optimalValueText);
            }
            Console.WriteLine();
            swOutput.WriteLine();
        }

        private void DisplayExpectedScoresPerRound(string[] lines, int initialLinesToSkip)
        {
            Console.WriteLine();
            for (int i = 0; i < LastRound - PreviousRound; i++)
            {
                if (i + initialLinesToSkip < lines.Length)
                {
                    Console.WriteLine(lines[i + initialLinesToSkip]);
                }
            }
            Console.WriteLine();
        }

        private static List<RawVariableValue> ExtractRawVariableValuesFromLPSolveOutputs(string[] lines, int initialLinesToSkip)
        {
            string[] separators = { " ", "\t" };
            List<RawVariableValue> rawVariableValues
                = lines.Skip(initialLinesToSkip)
                       .Select(line => line.Split(separators, StringSplitOptions.RemoveEmptyEntries))
                       .Select(
                            x => new RawVariableValue
                            {
                                UnparsedVariableName = x[0],
                                Value = double.Parse(x[1])
                            }
                        )
                       .ToList();
            return rawVariableValues;
        }

        private static IEnumerable<VariableValue> ExtractVariableValuesFromRawVariableValues(
            List<RawVariableValue> rawVariableValues)
        {
            string pattern = @"^(?<VariableName>\w+)_(?<PlayerId>\w+)_(?<Round>\d+)$";
            IEnumerable<VariableValue> variableValues
                = rawVariableValues
                .Where(rvv => Regex.IsMatch(rvv.UnparsedVariableName, pattern))
                .SelectMany(
                    rvv => RegexMatches(rvv.UnparsedVariableName, pattern)
                            .Select(
                                match =>
                                    new VariableValue
                                    {
                                        VariableName = match.Groups["VariableName"].Value,
                                        PlayerId = match.Groups["PlayerId"].Value,
                                        Round = int.Parse(match.Groups["Round"].Value),
                                        Value = rvv.Value
                                    }
                                )
                    );
            return variableValues;
        }

        private static IEnumerable<Match> RegexMatches(string input, string pattern)
        {
            MatchCollection matches = Regex.Matches(input, pattern);
            foreach (Match mat in matches)
            {
                yield return mat;
            }
        }

        private static void UpdatePlayerModelsFromLPSolveOutputs(
            IList<PlayerModel> playersByRound, 
            Dictionary<string, RawVariableValue> variableValueMap)
        {
            foreach (PlayerModel player in playersByRound)
            {
                string isInTeamVariableName = String.Format("IsInTeam_{0}_{1}",
                    player.PlayerId, player.Round);
                string isSubstituteVariableName = String.Format("IsSubstitute_{0}_{1}",
                    player.PlayerId, player.Round);
                string isCaptainVariableName = String.Format("IsCaptain_{0}_{1}",
                    player.PlayerId, player.Round);
                string isKickerVariableName = String.Format("IsKicker_{0}_{1}",
                    player.PlayerId, player.Round);

                player.IsInTeam = variableValueMap[isInTeamVariableName].Value;
                player.IsSubstitute = variableValueMap[isSubstituteVariableName].Value;
                player.IsCaptain
                    = variableValueMap.ContainsKey(isCaptainVariableName)
                    ? variableValueMap[isCaptainVariableName].Value
                    : 0;
                player.IsKicker
                    = variableValueMap.ContainsKey(isKickerVariableName)
                    ? variableValueMap[isKickerVariableName].Value : 0;
            }
        }

        private void DisplayWarningsForPlayersChosenForThisRoundWhichAreNotInTheTeamSheet(IList<PlayerModel> playersByRound)
        {
            string teamsheetFilePath = String.Format(
                @"{0}\DataByRound\Round{0}\Inputs\TeamSheets.html",
                RootFolder, CurrentRound);
            string teamsheetContents = String.Empty;
            if (File.Exists(teamsheetFilePath))
            {
                teamsheetContents = File.ReadAllText(teamsheetFilePath);
            }

            foreach (PlayerModel player in playersByRound.Where(p => p.Round == CurrentRound)
                                                         .OrderBy(p => p.Role)
                                                         .ThenBy(p => p.Position))
            {
                if (player.IsInTeam != 0)
                {
                    string warning =
                        string.IsNullOrEmpty(teamsheetContents) || (teamsheetContents.IndexOf(player.FullName) >= 0)
                        ? string.Empty : "   *** WARNING: not in teamsheet ***";
                    Console.WriteLine("{0}: {1,4} : {2,3} - {3}{4}",
                        player.Role, player.Position, player.Team, player.FullName, warning);
                }
            }
        }

       #endregion
    }
}
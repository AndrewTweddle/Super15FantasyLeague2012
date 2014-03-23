using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Data;
using System.Text.RegularExpressions;

namespace FantasyLeague
{
    class Program
    {
        static void Main(string[] args)
        {
            // If first argument is -noexit, then prompt to exit the console.
            bool noExit = (args.Length > 0 && args[0].ToLower() == "-noexit");

            try
            {
                // The -noexit argument should be ignored:
                if (noExit)
                {
                    args = args.Skip(1).ToArray();
                }

                string rootFolder = @"C:\FantasyLeague";  // TODO: Remove hard-coding
                int season = 2012;  // TODO: Remove hard-coding

                string modelSubPath = (args.Length > 0) ? args[0] : String.Empty;
                int? currentRoundArg = (args.Length > 1) ? int.Parse(args[1]) : (int?)null;
                int? lastRoundArg = (args.Length > 2) ? int.Parse(args[2]) : (int?)null;
                double? maxCostOfTeamArg = (args.Length > 3) ? double.Parse(args[3]) : (double?)null;
                string transferAllocationsArg = (args.Length > 4) ? args[4] : String.Empty;
                double parsedTargetScorePerRound = 0.0;
                double? targetScorePerRoundArg = (double?) null;
                if (args.Length > 5 && double.TryParse(args[5], out parsedTargetScorePerRound))
                {
                    targetScorePerRoundArg = parsedTargetScorePerRound;
                }
                int? filterByCandidateTypeArg = (args.Length > 6) ? int.Parse(args[6]) : (int?)null;
                int? breakAtFirstArg = (args.Length > 7) ? int.Parse(args[7]) : (int?)null;

                Console.WriteLine("Started optimization run @ {0}", DateTime.Now);
                try
                {
                    Solver solver = new Solver(rootFolder, modelSubPath, season);

                    // Configure solver properties:
                    if (currentRoundArg.HasValue) 
                    {
                        solver.CurrentRound = currentRoundArg.Value;
                    }

                    if (lastRoundArg.HasValue)
                    {
                        solver.LastRound = lastRoundArg.Value;
                    }

                    if (maxCostOfTeamArg.HasValue)
                    {
                        solver.MaxCostOfTeam = maxCostOfTeamArg.Value;
                    }

                    if (breakAtFirstArg.HasValue)
                    {
                        solver.BreakAtFirst = (breakAtFirstArg.Value == 1);
                    }

                    solver.TargetScorePerRound = targetScorePerRoundArg;

                    /* The 5th argument is 0 or 1 indicating whether to filter by allowed roles 
                       (if not the allowed roles will be ignored): 
                     */
                    if (filterByCandidateTypeArg.HasValue)
                    {
                        solver.IgnoreAllowedRoles = (filterByCandidateTypeArg.Value == 0);
                    }

                    /* Read custom transfer constraints: */
                    string pattern = @"(?<rounds>\d+),(?<transfers>\d+)";
                    Regex regex = new Regex(pattern);
                    var transfers = from Match mat in regex.Matches(transferAllocationsArg)
                                    where mat.Success
                                    select new TransferConstraint
                                    {
                                        Rounds = int.Parse(mat.Groups["rounds"].Captures[0].Value) - solver.CurrentRound + 1,
                                        Transfers = int.Parse(mat.Groups["transfers"].Captures[0].Value)
                                    };
                    solver.TransferAllocations = transfers.ToList();

                    solver.Run();

                    Console.WriteLine();
                    Console.WriteLine("Optimization algorithm finished @ {0}", DateTime.Now);
                }
                finally
                {
                    // Beep 3 times to indicate finished:
                    Console.Beep();
                    Console.Beep();
                    Console.Beep();
                }
            }
            catch (Exception exc)
            {
                Console.Error.WriteLine("An error occurred...");
                Console.Error.WriteLine("{0}", exc);
            }
            
            if (noExit)
            {
                Console.WriteLine();
                Console.WriteLine("Press ENTER to exit");
                Console.ReadLine();
            }
        }
    }
}

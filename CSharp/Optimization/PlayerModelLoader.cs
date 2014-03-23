using System;
using System.Collections.Generic;
using System.Data;
using System.Data.OleDb;
using System.Linq;

namespace FantasyLeague
{
    public class PlayerModelLoader
    {
        public IEnumerable<PlayerModel> Load(string csvFilePath, int currentRound = 1)
        {
            List<PlayerModel> playerModels = new List<PlayerModel>();

            DataTable playerEstimatesTable = CSVParser.ParseCSV(csvFilePath);
            DataRow[] rows = playerEstimatesTable.Select();
            var playerEstimates = 
                from row in rows 
                where !String.IsNullOrWhiteSpace(row.Field<string>("PlayerName"))
                select new {
                    Round = int.Parse(row.Field<string>("Round")),
                    FullName = row.Field<string>("PlayerName"),
                    Position = row.Field<string>("PositionCode"),
                    Team = row.Field<string>("TeamCode"),
                    Price = double.Parse(row.Field<string>("Price")),
                    GamesPlayed = int.Parse(row.Field<string>("GamesPlayed")),
                    PreviousRole = row.Field<string>("PreviousRole"),
                    EstimatedPointsAsPlayer = double.Parse(row.Field<string>("EstimatedPointsAsPlayer")),
                    EstimatedPointsAsKicker = double.Parse(row.Field<string>("EstimatedPointsAsKicker"))
                };
            var groupedPlayerEstimates = playerEstimates.GroupBy(est => new PlayerModel
            {
                FullName = est.FullName,
                Position = est.Position,
                Team = est.Team,
                GamesPlayed = est.GamesPlayed,
                Price = est.Price,
                PreviousRole = est.PreviousRole,
                KickerScoresForRound = new double[21],
                NonKickerScoresForRound = new double[21]
            });
            foreach (var grouping in groupedPlayerEstimates)
            {
                PlayerModel pm = grouping.Key;
                double nonKickerTotal = 0.0;
                double kickerTotal = 0.0;
                foreach (var est in grouping)
                {
                    pm.KickerScoresForRound[est.Round - 1] = est.EstimatedPointsAsKicker;
                    pm.NonKickerScoresForRound[est.Round - 1] = est.EstimatedPointsAsPlayer;
                    nonKickerTotal += est.EstimatedPointsAsPlayer;
                    kickerTotal += est.EstimatedPointsAsKicker;
                }
                pm.NonKickerTotal = nonKickerTotal;
                pm.KickerTotal = kickerTotal;
                playerModels.Add(pm);
            }
            return playerModels;
        }
    }
}
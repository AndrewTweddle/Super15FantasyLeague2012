using System;
using System.Collections.Generic;
using System.Data;
using System.Data.OleDb;
using System.Linq;

namespace FantasyLeague
{
    public class PredictedFinalistsLoader
    {
        public IEnumerable<string> LoadTeamCodesOfPredictedFinalists(string csvFilePath)
        {
            DataTable predictedFinalistsTable = CSVParser.ParseCSV(csvFilePath);
            DataRow[] rows = predictedFinalistsTable.Select();
            var unorderedPredictedFinalists = 
                from row in rows
                select new
                {
                    Position = int.Parse(row.Field<string>("Position")),
                    TeamCode = row.Field<string>("TeamCode"),
                    AdjustedTeamCode = row.Field<string>("AdjustedTeamCode")
                };
            IEnumerable<string> predictedFinalists = unorderedPredictedFinalists.OrderBy(fin => fin.Position).Select(fin => fin.AdjustedTeamCode);
            return predictedFinalists;
        }
    }
}
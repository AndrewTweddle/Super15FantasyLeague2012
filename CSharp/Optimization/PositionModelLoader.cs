using System;
using System.Collections.Generic;
using System.Data;
using System.Data.OleDb;

namespace FantasyLeague
{
    public class PositionModelLoader
    {
        public IEnumerable<PositionModel> Load(string csvFilePath)
        {
            IList<PositionModel> positionModels = new List<PositionModel>();
            DataTable positionModelsTable = CSVParser.ParseCSV(csvFilePath);
            DataRow[] rows = positionModelsTable.Select();
            foreach (DataRow row in rows)
            {
                PositionModel positionModel = new PositionModel();
                positionModel.Code = row.Field<string>("PositionCode");
                positionModel.Name = row.Field<string>("PositionName");
                positionModel.PointsPerTry = row.Field<int>("PointsPerTry");
                positionModel.PlayersPerPosition = row.Field<int>("PlayersPerPosition");
                positionModels.Add(positionModel);
            }
            return positionModels;
        }
    }
}
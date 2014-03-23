using System;
using System.Collections.Generic;
using System.Data;
using System.Data.OleDb;

namespace FantasyLeague
{
    public class TeamCompositionConstraintsLoader
    {
        public IEnumerable<string> LoadConstraints(string excelPath)
        {
            string connectionString = String.Format(
                @"Provider=Microsoft.Jet.OLEDB.4.0;Data Source={0};Extended Properties=""Excel 8.0;HDR=Yes;IMEX=1"";",
                excelPath);
            OleDbConnection oleDbConnection = new OleDbConnection(connectionString);
            string query = "select * from TeamCompositionConstraints";
            
            bool shouldCloseConn = false;
            if (oleDbConnection.State != ConnectionState.Open)
            {
                oleDbConnection.Open();
                shouldCloseConn = true;
            }
            
            try
            {
                OleDbCommand oleDbCommand = new OleDbCommand(query,oleDbConnection);
                IDataReader reader = oleDbCommand.ExecuteReader();
                try
                {
                    while (reader.Read())
                    {
                        string constraint = (string) reader[0];
                        yield return constraint;
                    }
                }
                finally
                {
                    reader.Close();
                }
            }
            finally
            {
                if (shouldCloseConn)
                {
                    oleDbConnection.Close();
                }
            }
        }
    }
}
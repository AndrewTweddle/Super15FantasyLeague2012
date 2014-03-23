using System;
using System.Data;
using System.IO; //not used by default
using System.Data.OleDb; //not used by default

namespace FantasyLeague
{
    class CSVParser
    {
        public static DataTable ParseCSV(string path)
        {
            return ParseCSV(path, "*");
        }

        public static DataTable ParseCSV(string path, params string[] columns)
        {
            if (!File.Exists(path))
                return null;

            string full = Path.GetFullPath(path);
            string file = Path.GetFileName(full);
            string dir = Path.GetDirectoryName(full);

            //create the "database" connection string 
            string connString = "Provider=Microsoft.Jet.OLEDB.4.0;"
                + "Data Source=\"" + dir + "\\\";"
                + "Extended Properties=\"text;HDR=Yes;FMT=Delimited\"";

            // Create the columns to retrieve:
            string selection = string.Join(", ", columns);

            //create the database query
            string query = String.Format("SELECT {0} FROM {1}", selection, file);

            //create a DataTable to hold the query results
            DataTable dTable = new DataTable();

            //create an OleDbDataAdapter to execute the query
            OleDbDataAdapter dAdapter = new OleDbDataAdapter(query, connString);
            try
            {
                //fill the DataTable
                dAdapter.Fill(dTable);
            }
            finally
            {
                dAdapter.Dispose();
            }

            return dTable;
        }
    }
}

using System.Data;
using Microsoft.Data.SqlClient;
namespace Proyecto_Final.Services.ChatV2;

public static class ChatV2SqlParameters
{
    public static SqlParameter AddUtc(SqlParameterCollection parameters, string name, DateTimeOffset instant)
    {
        var parameter = new SqlParameter(name, SqlDbType.DateTime2) { Scale = 7, Value = instant.UtcDateTime };
        parameters.Add(parameter); return parameter;
    }
}

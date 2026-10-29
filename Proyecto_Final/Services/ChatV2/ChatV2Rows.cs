using System.Data.Common;

namespace Proyecto_Final.Services.ChatV2;

internal static class ChatV2Rows
{
    internal sealed record Column(string Name, Type ClrType, string SqlType, int? Size = null);
    internal static readonly Column[] ReceiptColumns =
    [new("RequestId",typeof(Guid),"uniqueidentifier"),new("Domain",typeof(string),"char",1),new("ResourceId",typeof(int),"int"),
        new("MessageId",typeof(long),"bigint"),new("StreamSequence",typeof(long),"bigint"),new("TimestampUtc",typeof(DateTime),"datetime2"),
        new("PersistedState",typeof(string),"varchar",15),new("Content",typeof(string),"nvarchar",1000),new("AuthorizationVersion",typeof(long),"bigint")];
    internal static readonly Column[] HistoryColumns =
    [new("MessageId",typeof(long),"bigint"),new("StreamSequence",typeof(long),"bigint"),new("Sender",typeof(int),"int"),
        new("Content",typeof(string),"nvarchar",1000),new("OriginalDate",typeof(DateTime),"datetime2"),new("TimestampUtc",typeof(DateTime),"datetime2"),
        new("LegacyMessageId",typeof(int),"int"),new("LegacyRead",typeof(bool),"bit")];
    internal static readonly Column[] ContextColumns =
    [new("CursorDomain",typeof(string),"char",1),new("CursorResource",typeof(int),"int"),new("NextSequence",typeof(long),"bigint"),
        new("UpperBound",typeof(long),"bigint"),new("HasMore",typeof(bool),"bit"),new("ActorAuthorizationVersion",typeof(long),"bigint"),new("ResourceAuthorizationVersion",typeof(long),"bigint")];
    internal static void Schema(DbDataReader reader, params Column[] columns)
    {
        if (reader.FieldCount != columns.Length) Contract();
        var sqlReader = reader as Microsoft.Data.SqlClient.SqlDataReader;
        var schema = sqlReader?.GetColumnSchema();
        for (var i = 0; i < columns.Length; i++)
        {
            if (reader.GetName(i) != columns[i].Name || reader.GetFieldType(i) != columns[i].ClrType) Contract();
            if (sqlReader is not null && (sqlReader.GetDataTypeName(i) != columns[i].SqlType
                || columns[i].Size is int size && schema![i].ColumnSize != size)) Contract();
        }
    }
    internal static T Required<T>(DbDataReader reader, int ordinal)
    {
        if (reader.IsDBNull(ordinal) || reader.GetValue(ordinal) is not T result) throw new ChatV2Exception(ChatV2Failure.Contract);
        return result;
    }
    internal static T? Optional<T>(DbDataReader reader, int ordinal) where T : struct => reader.IsDBNull(ordinal) ? null : Required<T>(reader, ordinal);
    internal static void Contract() => throw new ChatV2Exception(ChatV2Failure.Contract);
    internal static ChatV2Domain Domain(string value) => value switch { "P" => ChatV2Domain.Private, "D" => ChatV2Domain.Department, "C" => ChatV2Domain.Customer, _ => throw new ChatV2Exception(ChatV2Failure.Contract) };
    internal static string SqlDomain(ChatV2Domain domain) => domain switch { ChatV2Domain.Private => "P", ChatV2Domain.Department => "D", ChatV2Domain.Customer => "C", _ => throw new ChatV2Exception(ChatV2Failure.Validation) };
    internal static DateTime Utc(DateTime value) => DateTime.SpecifyKind(value, DateTimeKind.Utc);
    internal static ChatV2Receipt Receipt(DbDataReader reader)
    {
        var result = new ChatV2Receipt(Required<Guid>(reader,0),Domain(Required<string>(reader,1)),Required<int>(reader,2),
            Required<long>(reader,3),Required<long>(reader,4),Utc(Required<DateTime>(reader,5)),Required<string>(reader,6),Required<string>(reader,7),Required<long>(reader,8));
        if (result.RequestId == Guid.Empty || result.ResourceId <= 0 || result.MessageId <= 0 || result.StreamSequence <= 0
            || result.PersistedState != "PERSISTED" || result.Content.Length is < 1 or > 1000 || result.AuthorizationVersion < 0) Contract();
        return result;
    }
    internal static ChatV2Message Message(DbDataReader reader)
    {
        var original = Optional<DateTime>(reader,4); var utc = Optional<DateTime>(reader,5);
        var result = new ChatV2Message(Required<long>(reader,0),Required<long>(reader,1),Required<int>(reader,2),Required<string>(reader,3),
            original is null ? null : DateTime.SpecifyKind(original.Value,DateTimeKind.Unspecified),utc is null ? null : Utc(utc.Value),Optional<int>(reader,6),Optional<bool>(reader,7));
        if (result.MessageId <= 0 || result.StreamSequence <= 0 || result.Sender <= 0 || result.Content.Length is < 1 or > 1000
            || result.OriginalDate is null && result.TimestampUtc is null || result.LegacyMessageId is <= 0) Contract();
        return result;
    }
    internal static ChatV2HistoryContext Context(DbDataReader reader)
    {
        var result = new ChatV2HistoryContext(Domain(Required<string>(reader,0)),Required<int>(reader,1),Required<long>(reader,2),Required<long>(reader,3),
            Required<bool>(reader,4),Required<long>(reader,5),Required<long>(reader,6));
        if (result.ResourceId <= 0 || result.NextSequence < 0 || result.UpperBound < result.NextSequence
            || result.ActorAuthorizationVersion <= 0 || result.ResourceAuthorizationVersion < 0 || result.HasMore != (result.NextSequence < result.UpperBound)) Contract();
        return result;
    }
}

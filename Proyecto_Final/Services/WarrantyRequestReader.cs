using System.Data.Common;
using Proyecto_Final.Models.Admin;

namespace Proyecto_Final.Services;

internal static class WarrantyRequestReader
{
    // Explicit projection of the accredited local Garantias schema. Historical
    // eight-column SPs cannot provide description/resolution by ordinal.
    internal const string ListSql = """
        SELECT g.GarantiaId, g.UsuarioId, o.PedidoId, p.Nombre AS Producto,
               u.NombreCompleto AS Cliente, g.FechaSolicitud, g.Estado, g.Motivo,
               g.Descripcion, g.Resolucion, g.FechaResolucion
        FROM dbo.Garantias AS g
        INNER JOIN dbo.PedidoDetalle AS d ON d.PedidoDetalleId=g.PedidoDetalleId
        INNER JOIN dbo.Pedidos AS o ON o.PedidoId=d.PedidoId
        INNER JOIN dbo.Productos AS p ON p.ProductoId=d.ProductoId
        INNER JOIN dbo.Usuarios AS u ON u.UsuarioId=g.UsuarioId
        ORDER BY CASE g.Estado WHEN N'Pendiente' THEN 0 WHEN N'En revisión' THEN 1 ELSE 2 END,
                 g.FechaSolicitud DESC;
        """;

    internal static WarrantyRequestViewModel Read(DbDataReader reader) => new()
    {
        GarantiaId = reader.GetInt32(reader.GetOrdinal("GarantiaId")),
        UsuarioId = reader.GetInt32(reader.GetOrdinal("UsuarioId")),
        PedidoId = reader.GetInt32(reader.GetOrdinal("PedidoId")),
        Producto = reader.GetString(reader.GetOrdinal("Producto")),
        Cliente = reader.GetString(reader.GetOrdinal("Cliente")),
        FechaSolicitud = reader.GetDateTime(reader.GetOrdinal("FechaSolicitud")),
        Estado = reader.GetString(reader.GetOrdinal("Estado")),
        Motivo = reader.GetString(reader.GetOrdinal("Motivo")),
        Descripcion = TextOrNull(reader,"Descripcion"),
        Resolucion = TextOrNull(reader,"Resolucion"),
        FechaResolucion = reader.IsDBNull(reader.GetOrdinal("FechaResolucion")) ? null : reader.GetDateTime(reader.GetOrdinal("FechaResolucion"))
    };

    private static string? TextOrNull(DbDataReader reader,string column) =>
        reader.IsDBNull(reader.GetOrdinal(column)) ? null : reader.GetString(reader.GetOrdinal(column));
}

using System.Data;
using Microsoft.Data.SqlClient;
using Proyecto_Final.Middleware;
using Proyecto_Final.Models.Admin;
using Proyecto_Final.Models.Store;
using Proyecto_Final.Services;
using Proyecto_FinalAPI.Models;
using Proyecto_FinalAPI.Services;

namespace Proyecto_Final.Tests;

public sealed class CommercialFoundationIntegrationTests
{
    [Theory]
    [InlineData(true, true, true, true)]
    [InlineData(false, true, true, false)]
    [InlineData(true, false, true, false)]
    [InlineData(true, true, false, false)]
    public void Login_RechecksCanonicalProfileAndCredentialStamp(bool activeUser, bool activeProfile, bool sameStamp, bool accepted)
    {
        var stamp = Guid.NewGuid();
        var table = ProfileTable();
        table.Rows.Add(8, 4, activeUser, sameStamp ? stamp : Guid.NewGuid(), "Vendedor", activeProfile);
        using var reader = table.CreateDataReader();
        Assert.True(reader.Read());
        var user = new ApiUser { UsuarioId = 8, Activo = true, PerfilNombre = "Vendedor", SecurityStamp = stamp.ToString("D") };
        Assert.Equal(accepted, AccountApiDbService.ApplyCurrentProfile(reader, user));
        Assert.Equal(accepted ? 4 : 0, user.PerfilId);
        Assert.Equal(accepted, user.PerfilActivo);
    }

    [Theory]
    [InlineData(0, "Vendedor")]
    [InlineData(4, "Administrador")]
    public void Login_DoesNotInferProfileFromRoleOrAcceptChangedRole(int profileId, string currentRole)
    {
        var stamp = Guid.NewGuid();
        var table = ProfileTable();
        table.Rows.Add(8, profileId, true, stamp, currentRole, true);
        using var reader = table.CreateDataReader();
        reader.Read();
        Assert.False(AccountApiDbService.ApplyCurrentProfile(reader,
            new ApiUser { UsuarioId = 8, Activo = true, PerfilNombre = "Vendedor", SecurityStamp = stamp.ToString("D") }));
    }

    [Fact]
    public void Session_RequiresCanonicalProfileIdAndActiveProfile()
    {
        var table = ProfileTable();
        var stamp = Guid.NewGuid();
        table.Rows.Add(8, 4, true, stamp, "Vendedor", true);
        using var reader = table.CreateDataReader();
        reader.Read();
        var state = UserSessionValidationService.ReadState(reader);
        Assert.True(SessionValidationMiddleware.IsCurrent(state, "Vendedor", stamp.ToString("D"), 4));
        Assert.False(SessionValidationMiddleware.IsCurrent(state with { ProfileActive = false }, "Vendedor", stamp.ToString("D"), 4));
        Assert.False(SessionValidationMiddleware.IsCurrent(state, "Vendedor", stamp.ToString("D"), 5));
        Assert.False(SessionValidationMiddleware.IsCurrent(state, "Vendedor", stamp.ToString("D")));
    }

    [Theory]
    [InlineData("Minorista")]
    [InlineData("Mayorista")]
    public async Task Segment_AcceptsOnlyARealUniqueSqlRow(string segment)
    {
        var table = new DataTable(); table.Columns.Add("SegmentoCliente", typeof(string)); table.Rows.Add(segment);
        using var reader = table.CreateDataReader();
        Assert.Equal(segment, await StoreDbService.ReadUserSegmentAsync(reader));
    }

    [Theory]
    [InlineData(0, "Minorista")]
    [InlineData(1, null)]
    [InlineData(1, "Todos")]
    [InlineData(2, "Minorista")]
    public async Task Segment_MissingNullInvalidOrDuplicateRowsDoNotBecomeMinorista(int rows, string? value)
    {
        var table = new DataTable(); table.Columns.Add("SegmentoCliente", typeof(string));
        for (var i = 0; i < rows; i++) table.Rows.Add(value is null ? DBNull.Value : value);
        using var reader = table.CreateDataReader();
        await Assert.ThrowsAsync<InvalidOperationException>(() => StoreDbService.ReadUserSegmentAsync(reader));
    }

    [Fact]
    public void PromotionProjection_PreservesDatesSegmentDiscountsAndGiftStock()
    {
        var table = new DataTable();
        foreach (var (name, type) in new (string, Type)[] {
            ("PromocionId",typeof(int)),("Nombre",typeof(string)),("Tipo",typeof(string)),("ProductoId",typeof(int)),
            ("CantidadMinima",typeof(int)),("PorcentajeDescuento",typeof(decimal)),("ProductoRegaloId",typeof(int)),
            ("ProductoRegaloNombre",typeof(string)),("ProductoRegaloPrecio",typeof(decimal)),("ProductoRegaloStock",typeof(int)),
            ("CantidadRegalo",typeof(int)),("Prioridad",typeof(int)),("SegmentoCliente",typeof(string)),("FechaInicio",typeof(DateTime)),("FechaFin",typeof(DateTime))
        }) table.Columns.Add(name,type);
        var date = new DateTime(2026,10,14);
        table.Rows.Add(2,"Descuento","DescuentoPorcentual",10,2,12.5m,DBNull.Value,DBNull.Value,DBNull.Value,DBNull.Value,DBNull.Value,5,"Mayorista",date,date);
        using var reader = table.CreateDataReader(); reader.Read();
        var promotion = PromotionsDbService.ReadActivePromotion(reader);
        Assert.Equal(date,promotion.FechaInicio); Assert.Equal(date,promotion.FechaFin); Assert.Equal("Mayorista",promotion.SegmentoCliente);
        var items = new List<CartItemViewModel> { new() { ProductoId=10,Cantidad=3,Precio=0.15m } };
        PromotionEngine.Apply(items,[promotion],"Mayorista",date);
        Assert.Equal(0.06m,items[0].MontoDescuento);
        items[0].MontoDescuento=0;
        PromotionEngine.Apply(items,[promotion],"Mayorista",date.AddDays(1));
        Assert.Equal(0m,items[0].MontoDescuento);
        PromotionEngine.Apply(items,[promotion],"Minorista",date);
        Assert.Equal(0m,items[0].MontoDescuento);
    }

    [Fact]
    public void ReadCommands_UseCanonicalJoinsAndTypedIdentityParameters()
    {
        using var connection = new SqlConnection();
        using var state = UserSessionValidationService.CreateStateCommand(connection,8);
        using var login = AccountApiDbService.CreateCurrentProfileCommand(connection,8);
        using var promotions = PromotionsDbService.CreateActivePromotionCommand(connection,"Mayorista");
        Assert.Equal(SqlDbType.Int,state.Parameters["@UsuarioId"].SqlDbType);
        Assert.Equal(SqlDbType.Int,login.Parameters["@UsuarioId"].SqlDbType);
        Assert.Contains("p.PerfilId = u.PerfilId",state.CommandText);
        Assert.Contains("PerfilActivo",login.CommandText);
        Assert.Contains("pr.FechaInicio, pr.FechaFin",promotions.CommandText);
        Assert.Equal("Mayorista",promotions.Parameters["@SegmentoCliente"].Value);
    }

    private static DataTable ProfileTable()
    {
        var table = new DataTable();
        table.Columns.Add("UsuarioId",typeof(int)); table.Columns.Add("PerfilId",typeof(int));
        table.Columns.Add("Activo",typeof(bool)); table.Columns.Add("SecurityStamp",typeof(Guid));
        table.Columns.Add("PerfilNombre",typeof(string)); table.Columns.Add("PerfilActivo",typeof(bool));
        return table;
    }
}

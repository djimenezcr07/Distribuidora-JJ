SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-212: panel de progreso en tiempo real del vendedor sobre su propia meta. */
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 54900,N'Falta el ledger 0001.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0021_seller_goal_progress' AND Status=N'Applied')
    THROW 54901,N'0021 ya figura aplicada.',1;
IF OBJECT_ID(N'dbo.MetasVendedor',N'U') IS NULL OR OBJECT_ID(N'dbo.Facturas',N'U') IS NULL OR OBJECT_ID(N'dbo.Pedidos',N'U') IS NULL OR OBJECT_ID(N'dbo.Usuarios',N'U') IS NULL
    THROW 54902,N'Faltan dependencias: dbo.MetasVendedor (CU-211/213), Facturas, Pedidos o Usuarios. Verificar aplicación previa antes de continuar.',1;

BEGIN TRANSACTION;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Metas_MiProgreso
    @VendedorUsuarioId INT,
    @Anio               INT,
    @Mes                INT
AS
BEGIN
    SET NOCOUNT ON;
    IF @Anio NOT BETWEEN 2000 AND 2100 THROW 54910,N'Año inválido.',1;
    IF @Mes NOT BETWEEN 1 AND 12 THROW 54911,N'Mes inválido.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios u INNER JOIN dbo.Perfiles pf ON pf.PerfilId=u.PerfilId
                  WHERE u.UsuarioId=@VendedorUsuarioId AND pf.Nombre=N'Vendedor' AND u.Activo=1)
        THROW 54912,N'El usuario no es un vendedor activo.',1;

    DECLARE @VentasReales DECIMAL(18,2)=(
        SELECT ISNULL(SUM(f.Total),0) FROM dbo.Facturas f INNER JOIN dbo.Pedidos p ON p.PedidoId=f.PedidoId
        WHERE p.VendedorUsuarioId=@VendedorUsuarioId AND YEAR(f.FechaFactura)=@Anio AND MONTH(f.FechaFactura)=@Mes AND f.Estado<>N'Anulada');

    SELECT
        @VendedorUsuarioId AS VendedorUsuarioId,
        @Anio AS Anio,
        @Mes AS Mes,
        ISNULL(m.MontoMeta,0) AS MontoMeta,
        @VentasReales AS VentasReales,
        CASE WHEN ISNULL(m.MontoMeta,0)>0 THEN CAST(@VentasReales/m.MontoMeta*100 AS DECIMAL(9,2)) ELSE 0 END AS PorcentajeCumplimiento,
        CASE WHEN ISNULL(m.MontoMeta,0)-@VentasReales<0 THEN 0 ELSE ISNULL(m.MontoMeta,0)-@VentasReales END AS MontoPendiente,
        CASE WHEN m.MetaId IS NULL THEN CAST(1 AS BIT) ELSE CAST(0 AS BIT) END AS SinMetaDefinida
    FROM (SELECT 1 AS Dummy) d
    LEFT JOIN dbo.MetasVendedor m ON m.VendedorUsuarioId=@VendedorUsuarioId AND m.Anio=@Anio AND m.Mes=@Mes;
END;
GO

IF XACT_STATE()<>1 THROW 54903,N'La transacción 0021 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 54904,N'SHA-256 inválido para 0021.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0021_seller_goal_progress',N'0021_seller_goal_progress.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-212: progreso individual de meta mensual, solo lectura, filtrado por vendedor.');
COMMIT TRANSACTION;
GO
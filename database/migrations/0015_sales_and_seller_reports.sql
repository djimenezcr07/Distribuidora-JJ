SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-132 y CU-134: reportes de ventas y desempeño de vendedores. */
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NULL THROW 54800,N'Falta el ledger 0001.',1;
IF EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0015_sales_and_seller_reports' AND Status=N'Applied') THROW 54801,N'0015 ya figura aplicada.',1;
IF OBJECT_ID(N'dbo.Facturas',N'U') IS NULL OR OBJECT_ID(N'dbo.FacturaDetalle',N'U') IS NULL OR OBJECT_ID(N'dbo.Pedidos',N'U') IS NULL
   OR OBJECT_ID(N'dbo.Productos',N'U') IS NULL OR OBJECT_ID(N'dbo.Usuarios',N'U') IS NULL OR OBJECT_ID(N'dbo.Perfiles',N'U') IS NULL
   OR OBJECT_ID(N'dbo.Permisos',N'U') IS NULL OR OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NULL
    THROW 54802,N'Faltan dependencias de facturación, pedidos, productos, usuarios o permisos.',1;
IF COL_LENGTH(N'dbo.Pedidos',N'VendedorUsuarioId') IS NULL OR COL_LENGTH(N'dbo.Productos',N'Categoria') IS NULL
    THROW 54803,N'Faltan VendedorUsuarioId o Categoria requeridos por los reportes.',1;

BEGIN TRANSACTION;

DECLARE @Permissions TABLE(Codigo NVARCHAR(100),Nombre NVARCHAR(150),Descripcion NVARCHAR(500));
INSERT @Permissions VALUES
(N'REPORTES_VENTAS_VER',N'Consultar reporte de ventas',N'Permite consultar, imprimir y exportar ventas agregadas.'),
(N'REPORTES_VENDEDORES_VER',N'Consultar desempeño de vendedores',N'Permite consultar, imprimir y exportar métricas comerciales por vendedor.');
UPDATE permission SET Modulo=N'Reportes',Nombre=required.Nombre,Descripcion=required.Descripcion,Activo=1
FROM dbo.Permisos permission INNER JOIN @Permissions required ON required.Codigo=permission.Codigo;
INSERT dbo.Permisos(Codigo,Modulo,Nombre,Descripcion,Activo)
SELECT Codigo,N'Reportes',Nombre,Descripcion,1 FROM @Permissions required
WHERE NOT EXISTS(SELECT 1 FROM dbo.Permisos permission WITH(UPDLOCK,HOLDLOCK) WHERE permission.Codigo=required.Codigo);
INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
SELECT profile.PerfilId,permission.PermisoId,NULL,N'Migración 0015 reportes'
FROM dbo.Perfiles profile CROSS JOIN dbo.Permisos permission
WHERE profile.Nombre IN(N'Administrador',N'Gerente') AND permission.Codigo IN(SELECT Codigo FROM @Permissions)
AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos assigned WHERE assigned.PerfilId=profile.PerfilId AND assigned.PermisoId=permission.PermisoId);
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reportes_VentasDetallado
    @Desde DATE,@Hasta DATE,@Agrupacion NVARCHAR(20)=N'diario',@Categoria NVARCHAR(100)=NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @Desde IS NULL OR @Hasta IS NULL OR @Desde>@Hasta OR DATEDIFF(DAY,@Desde,@Hasta)>731 THROW 54820,N'Rango de fechas inválido.',1;
    IF @Agrupacion NOT IN(N'diario',N'mensual',N'categoria') THROW 54821,N'Agrupación inválida.',1;
    SET @Categoria=NULLIF(LTRIM(RTRIM(@Categoria)),N'');

    CREATE TABLE #EligibleInvoices(FacturaId INT NOT NULL PRIMARY KEY,PedidoId INT NOT NULL,Fecha DATE NOT NULL,Total DECIMAL(18,2) NOT NULL);
    INSERT #EligibleInvoices
    SELECT invoice.FacturaId,invoice.PedidoId,CONVERT(DATE,invoice.FechaFactura),invoice.Total
    FROM dbo.Facturas invoice
    WHERE invoice.Estado<>N'Anulada' AND invoice.FechaFactura>=@Desde AND invoice.FechaFactura<DATEADD(DAY,1,@Hasta)
      AND (@Categoria IS NULL OR EXISTS
          (SELECT 1 FROM dbo.FacturaDetalle detail INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId
           WHERE detail.FacturaId=invoice.FacturaId AND product.Categoria=@Categoria));

    SELECT COALESCE(SUM(Total),0) TotalVentas,COUNT(*) Facturas,COUNT(DISTINCT PedidoId) Pedidos,
           CONVERT(DECIMAL(18,2),CASE WHEN COUNT(*)>0 THEN COALESCE(SUM(Total),0)/COUNT(*) ELSE 0 END) TicketPromedio
    FROM #EligibleInvoices;

    CREATE TABLE #Rows(GrupoClave NVARCHAR(100),GrupoNombre NVARCHAR(150),FechaGrupo DATE NULL,Categoria NVARCHAR(100) NULL,TotalVentas DECIMAL(18,2),Facturas INT,Pedidos INT,TicketPromedio DECIMAL(18,2),Unidades INT);
    IF @Agrupacion=N'diario'
    BEGIN
        ;WITH invoiceTotals AS
        (SELECT Fecha,SUM(Total) TotalVentas,COUNT(*) Facturas,COUNT(DISTINCT PedidoId) Pedidos FROM #EligibleInvoices GROUP BY Fecha),
        units AS
        (SELECT eligible.Fecha,SUM(detail.Cantidad) Unidades FROM #EligibleInvoices eligible INNER JOIN dbo.FacturaDetalle detail ON detail.FacturaId=eligible.FacturaId
         INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId WHERE @Categoria IS NULL OR product.Categoria=@Categoria GROUP BY eligible.Fecha)
        INSERT #Rows SELECT CONVERT(NVARCHAR(10),invoiceTotals.Fecha,23),CONVERT(NVARCHAR(10),invoiceTotals.Fecha,103),invoiceTotals.Fecha,NULL,invoiceTotals.TotalVentas,invoiceTotals.Facturas,invoiceTotals.Pedidos,
            CONVERT(DECIMAL(18,2),invoiceTotals.TotalVentas/NULLIF(invoiceTotals.Facturas,0)),COALESCE(units.Unidades,0)
        FROM invoiceTotals LEFT JOIN units ON units.Fecha=invoiceTotals.Fecha;
    END
    ELSE IF @Agrupacion=N'mensual'
    BEGIN
        ;WITH invoiceTotals AS
        (SELECT DATEFROMPARTS(YEAR(Fecha),MONTH(Fecha),1) Mes,SUM(Total) TotalVentas,COUNT(*) Facturas,COUNT(DISTINCT PedidoId) Pedidos FROM #EligibleInvoices GROUP BY YEAR(Fecha),MONTH(Fecha)),
        units AS
        (SELECT DATEFROMPARTS(YEAR(eligible.Fecha),MONTH(eligible.Fecha),1) Mes,SUM(detail.Cantidad) Unidades FROM #EligibleInvoices eligible INNER JOIN dbo.FacturaDetalle detail ON detail.FacturaId=eligible.FacturaId
         INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId WHERE @Categoria IS NULL OR product.Categoria=@Categoria GROUP BY YEAR(eligible.Fecha),MONTH(eligible.Fecha))
        INSERT #Rows SELECT CONVERT(NVARCHAR(7),invoiceTotals.Mes,126),CONCAT(DATENAME(MONTH,invoiceTotals.Mes),N' ',YEAR(invoiceTotals.Mes)),invoiceTotals.Mes,NULL,invoiceTotals.TotalVentas,invoiceTotals.Facturas,invoiceTotals.Pedidos,
            CONVERT(DECIMAL(18,2),invoiceTotals.TotalVentas/NULLIF(invoiceTotals.Facturas,0)),COALESCE(units.Unidades,0)
        FROM invoiceTotals LEFT JOIN units ON units.Mes=invoiceTotals.Mes;
    END
    ELSE
    BEGIN
        INSERT #Rows
        SELECT product.Categoria,product.Categoria,NULL,product.Categoria,CONVERT(DECIMAL(18,2),SUM(detail.Subtotal)),COUNT(DISTINCT eligible.FacturaId),COUNT(DISTINCT eligible.PedidoId),
               CONVERT(DECIMAL(18,2),SUM(detail.Subtotal)/NULLIF(COUNT(DISTINCT eligible.FacturaId),0)),SUM(detail.Cantidad)
        FROM #EligibleInvoices eligible INNER JOIN dbo.FacturaDetalle detail ON detail.FacturaId=eligible.FacturaId
        INNER JOIN dbo.Productos product ON product.ProductoId=detail.ProductoId
        WHERE @Categoria IS NULL OR product.Categoria=@Categoria GROUP BY product.Categoria;
    END;
    SELECT GrupoClave,GrupoNombre,FechaGrupo,Categoria,TotalVentas,Facturas,Pedidos,TicketPromedio,Unidades FROM #Rows ORDER BY COALESCE(FechaGrupo,'99991231'),GrupoNombre;
    SELECT DISTINCT Categoria FROM dbo.Productos WHERE Activo=1 AND NULLIF(LTRIM(RTRIM(Categoria)),N'') IS NOT NULL ORDER BY Categoria;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Reportes_DesempenoVendedores
    @Desde DATE,@Hasta DATE,@VendedorUsuarioId INT=NULL,@Orden NVARCHAR(30)=N'ventas_desc'
AS
BEGIN
    SET NOCOUNT ON;
    IF @Desde IS NULL OR @Hasta IS NULL OR @Desde>@Hasta OR DATEDIFF(DAY,@Desde,@Hasta)>731 THROW 54830,N'Rango de fechas inválido.',1;
    IF @VendedorUsuarioId IS NOT NULL AND @VendedorUsuarioId<=0 THROW 54831,N'Vendedor inválido.',1;
    IF @Orden NOT IN(N'ventas_desc',N'ventas_asc',N'nombre',N'cumplimiento_desc') THROW 54832,N'Orden inválido.',1;

    CREATE TABLE #Goals(VendedorUsuarioId INT NOT NULL PRIMARY KEY,Meta DECIMAL(18,2) NOT NULL);
    IF OBJECT_ID(N'dbo.MetasVendedor',N'U') IS NOT NULL
        EXEC sys.sp_executesql N'
            INSERT #Goals(VendedorUsuarioId,Meta)
            SELECT VendedorUsuarioId,SUM(MontoMeta) FROM dbo.MetasVendedor
            WHERE DATEFROMPARTS(Anio,Mes,1) BETWEEN DATEFROMPARTS(YEAR(@D),MONTH(@D),1) AND DATEFROMPARTS(YEAR(@H),MONTH(@H),1)
            GROUP BY VendedorUsuarioId;',N'@D DATE,@H DATE',@D=@Desde,@H=@Hasta;

    ;WITH sales AS
    (
        SELECT orders.VendedorUsuarioId,SUM(invoice.Total) Ventas,COUNT(DISTINCT orders.PedidoId) Pedidos,COUNT(DISTINCT invoice.FacturaId) Facturas,COUNT(DISTINCT orders.UsuarioId) ClientesAtendidos
        FROM dbo.Facturas invoice INNER JOIN dbo.Pedidos orders ON orders.PedidoId=invoice.PedidoId
        WHERE invoice.Estado<>N'Anulada' AND invoice.FechaFactura>=@Desde AND invoice.FechaFactura<DATEADD(DAY,1,@Hasta) AND orders.VendedorUsuarioId IS NOT NULL
        GROUP BY orders.VendedorUsuarioId
    ), sellers AS
    (
        SELECT userAccount.UsuarioId,userAccount.NombreCompleto
        FROM dbo.Usuarios userAccount INNER JOIN dbo.Perfiles profile ON profile.PerfilId=userAccount.PerfilId
        WHERE userAccount.Activo=1 AND profile.Nombre=N'Vendedor'
        UNION
        SELECT userAccount.UsuarioId,userAccount.NombreCompleto FROM sales INNER JOIN dbo.Usuarios userAccount ON userAccount.UsuarioId=sales.VendedorUsuarioId
    )
    SELECT seller.UsuarioId VendedorUsuarioId,seller.NombreCompleto VendedorNombre,CONVERT(DECIMAL(18,2),COALESCE(sales.Ventas,0)) Ventas,
           COALESCE(sales.Pedidos,0) Pedidos,COALESCE(sales.Facturas,0) Facturas,
           CONVERT(DECIMAL(18,2),CASE WHEN COALESCE(sales.Pedidos,0)>0 THEN sales.Ventas/sales.Pedidos ELSE 0 END) TicketPromedio,
           COALESCE(sales.ClientesAtendidos,0) ClientesAtendidos,goal.Meta,
           CONVERT(DECIMAL(18,2),CASE WHEN goal.Meta>0 THEN COALESCE(sales.Ventas,0)/goal.Meta*100 END) CumplimientoPorcentual
    INTO #SellerResult FROM sellers seller LEFT JOIN sales ON sales.VendedorUsuarioId=seller.UsuarioId LEFT JOIN #Goals goal ON goal.VendedorUsuarioId=seller.UsuarioId
    WHERE @VendedorUsuarioId IS NULL OR seller.UsuarioId=@VendedorUsuarioId;

    SELECT VendedorUsuarioId,VendedorNombre,Ventas,Pedidos,Facturas,TicketPromedio,ClientesAtendidos,Meta,CumplimientoPorcentual FROM #SellerResult
    ORDER BY CASE WHEN @Orden=N'nombre' THEN VendedorNombre END,
             CASE WHEN @Orden=N'ventas_asc' THEN Ventas END ASC,
             CASE WHEN @Orden=N'cumplimiento_desc' THEN CumplimientoPorcentual END DESC,
             CASE WHEN @Orden=N'ventas_desc' THEN Ventas END DESC,VendedorNombre;
    SELECT userAccount.UsuarioId,userAccount.NombreCompleto,userAccount.Correo
    FROM dbo.Usuarios userAccount INNER JOIN dbo.Perfiles profile ON profile.PerfilId=userAccount.PerfilId
    WHERE userAccount.Activo=1 AND profile.Nombre=N'Vendedor' ORDER BY userAccount.NombreCompleto;
END;
GO

IF XACT_STATE()<>1 THROW 54804,N'La transacción 0015 no está disponible.',1;
DECLARE @MigrationSha256 NVARCHAR(128)=N'$(MigrationSha256)';
IF LEN(@MigrationSha256)<>64 OR @MigrationSha256 LIKE N'%[^0-9A-Fa-f]%' THROW 54805,N'SHA-256 inválido para 0015.',1;
INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)
VALUES(N'0015_sales_and_seller_reports',N'0015_sales_and_seller_reports.sql',UPPER(@MigrationSha256),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-132/CU-134: reportes filtrables, agrupados, imprimibles y exportables.');
COMMIT TRANSACTION;
GO

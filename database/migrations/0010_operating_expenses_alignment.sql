SET NOCOUNT ON;
SET XACT_ABORT ON;

/*
 CU-222: evolución aditiva de GastosOperativos legado al flujo anual normalizado.
 Los registros legados permanecen consultables, pero no se inventan departamento/categoría.
 Rollback: retirar SP/vista; preservar columnas y auditoría. No ejecutar database_Esteban en DEV.
*/
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.GastosOperativos',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.GastosOperativos
 (
  GastoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GastosOperativos PRIMARY KEY,CuentaId INT NULL,Fecha DATE NULL,Monto DECIMAL(18,2) NULL,Concepto NVARCHAR(200) NULL,Comprobante NVARCHAR(60) NULL,RegistradoPorUsuarioId INT NULL,RegistradoPorNombre NVARCHAR(150) NULL,FechaRegistro DATETIME2(0) NULL,
  FechaGasto DATE NOT NULL,DepartamentoId INT NULL,CategoriaId INT NULL,Proveedor NVARCHAR(180) NULL,NumeroDocumento NVARCHAR(80) NOT NULL,TipoDocumento NVARCHAR(40) NOT NULL,Descripcion NVARCHAR(500) NOT NULL,
  Subtotal DECIMAL(18,2) NOT NULL,Impuesto DECIMAL(18,2) NOT NULL,Total DECIMAL(18,2) NOT NULL,MetodoPago NVARCHAR(40) NOT NULL,Moneda CHAR(3) NOT NULL CONSTRAINT DF_GastosOperativos_Moneda DEFAULT 'CRC',Estado NVARCHAR(20) NOT NULL,
  TokenOperacion UNIQUEIDENTIFIER NOT NULL,ComprobanteNombreOriginal NVARCHAR(255) NULL,ComprobanteStorageKey NVARCHAR(80) NULL,ComprobanteMimeType NVARCHAR(100) NULL,ComprobanteExtension NVARCHAR(10) NULL,ComprobanteTamanoBytes BIGINT NULL,ComprobanteHashSha256 CHAR(64) NULL,ComprobanteStorageStatus NVARCHAR(20) NULL,
  CreadoPorUsuarioId INT NOT NULL,CreadoPorNombre NVARCHAR(150) NOT NULL,ActualizadoPorUsuarioId INT NOT NULL,ActualizadoPorNombre NVARCHAR(150) NOT NULL,FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_GastosOperativos_Creacion DEFAULT SYSUTCDATETIME(),FechaActualizacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_GastosOperativos_Actualizacion DEFAULT SYSUTCDATETIME(),AnuladoPorUsuarioId INT NULL,FechaAnulacionUtc DATETIME2(0) NULL,MotivoCancelacion NVARCHAR(500) NULL
 );
END
ELSE
BEGIN
 ALTER TABLE dbo.GastosOperativos ALTER COLUMN CuentaId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'FechaGasto') IS NULL ALTER TABLE dbo.GastosOperativos ADD FechaGasto DATE NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'DepartamentoId') IS NULL ALTER TABLE dbo.GastosOperativos ADD DepartamentoId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'CategoriaId') IS NULL ALTER TABLE dbo.GastosOperativos ADD CategoriaId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'NumeroDocumento') IS NULL ALTER TABLE dbo.GastosOperativos ADD NumeroDocumento NVARCHAR(80) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'TipoDocumento') IS NULL ALTER TABLE dbo.GastosOperativos ADD TipoDocumento NVARCHAR(40) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Descripcion') IS NULL ALTER TABLE dbo.GastosOperativos ADD Descripcion NVARCHAR(500) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Subtotal') IS NULL ALTER TABLE dbo.GastosOperativos ADD Subtotal DECIMAL(18,2) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Impuesto') IS NULL ALTER TABLE dbo.GastosOperativos ADD Impuesto DECIMAL(18,2) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Total') IS NULL ALTER TABLE dbo.GastosOperativos ADD Total DECIMAL(18,2) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'MetodoPago') IS NULL ALTER TABLE dbo.GastosOperativos ADD MetodoPago NVARCHAR(40) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Moneda') IS NULL ALTER TABLE dbo.GastosOperativos ADD Moneda CHAR(3) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'Estado') IS NULL ALTER TABLE dbo.GastosOperativos ADD Estado NVARCHAR(20) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'TokenOperacion') IS NULL ALTER TABLE dbo.GastosOperativos ADD TokenOperacion UNIQUEIDENTIFIER NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteNombreOriginal') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteNombreOriginal NVARCHAR(255) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteStorageKey') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteStorageKey NVARCHAR(80) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteMimeType') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteMimeType NVARCHAR(100) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteExtension') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteExtension NVARCHAR(10) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteTamanoBytes') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteTamanoBytes BIGINT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteHashSha256') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteHashSha256 CHAR(64) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ComprobanteStorageStatus') IS NULL ALTER TABLE dbo.GastosOperativos ADD ComprobanteStorageStatus NVARCHAR(20) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'CreadoPorUsuarioId') IS NULL ALTER TABLE dbo.GastosOperativos ADD CreadoPorUsuarioId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'CreadoPorNombre') IS NULL ALTER TABLE dbo.GastosOperativos ADD CreadoPorNombre NVARCHAR(150) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ActualizadoPorUsuarioId') IS NULL ALTER TABLE dbo.GastosOperativos ADD ActualizadoPorUsuarioId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'ActualizadoPorNombre') IS NULL ALTER TABLE dbo.GastosOperativos ADD ActualizadoPorNombre NVARCHAR(150) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'FechaCreacionUtc') IS NULL ALTER TABLE dbo.GastosOperativos ADD FechaCreacionUtc DATETIME2(0) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'FechaActualizacionUtc') IS NULL ALTER TABLE dbo.GastosOperativos ADD FechaActualizacionUtc DATETIME2(0) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'MotivoCancelacion') IS NULL ALTER TABLE dbo.GastosOperativos ADD MotivoCancelacion NVARCHAR(500) NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'AnuladoPorUsuarioId') IS NULL ALTER TABLE dbo.GastosOperativos ADD AnuladoPorUsuarioId INT NULL;
 IF COL_LENGTH(N'dbo.GastosOperativos',N'FechaAnulacionUtc') IS NULL ALTER TABLE dbo.GastosOperativos ADD FechaAnulacionUtc DATETIME2(0) NULL;
 UPDATE dbo.GastosOperativos SET FechaGasto=COALESCE(FechaGasto,Fecha),NumeroDocumento=COALESCE(NumeroDocumento,NULLIF(Comprobante,N''),CONCAT(N'LEG-',GastoId)),TipoDocumento=COALESCE(TipoDocumento,N'Legado'),Descripcion=COALESCE(Descripcion,Concepto,N'Gasto legado'),Subtotal=COALESCE(Subtotal,Monto,0),Impuesto=COALESCE(Impuesto,0),Total=COALESCE(Total,Monto,0),MetodoPago=COALESCE(MetodoPago,N'No especificado'),Moneda=COALESCE(Moneda,'CRC'),Estado=COALESCE(Estado,N'Pagado'),TokenOperacion=COALESCE(TokenOperacion,NEWID()),CreadoPorUsuarioId=COALESCE(CreadoPorUsuarioId,RegistradoPorUsuarioId),CreadoPorNombre=COALESCE(CreadoPorNombre,RegistradoPorNombre,N'Migración legado'),ActualizadoPorUsuarioId=COALESCE(ActualizadoPorUsuarioId,CreadoPorUsuarioId,RegistradoPorUsuarioId),ActualizadoPorNombre=COALESCE(ActualizadoPorNombre,CreadoPorNombre,RegistradoPorNombre,N'Migración legado'),FechaCreacionUtc=COALESCE(FechaCreacionUtc,FechaRegistro,SYSUTCDATETIME()),FechaActualizacionUtc=COALESCE(FechaActualizacionUtc,FechaRegistro,SYSUTCDATETIME());
END;

IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'UX_GastosOperativos_TokenOperacion') CREATE UNIQUE INDEX UX_GastosOperativos_TokenOperacion ON dbo.GastosOperativos(TokenOperacion) WHERE TokenOperacion IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'UX_GastosOperativos_ComprobanteStorageKey') CREATE UNIQUE INDEX UX_GastosOperativos_ComprobanteStorageKey ON dbo.GastosOperativos(ComprobanteStorageKey) WHERE ComprobanteStorageKey IS NOT NULL;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'IX_GastosOperativos_Reporte') CREATE INDEX IX_GastosOperativos_Reporte ON dbo.GastosOperativos(FechaGasto,DepartamentoId,CategoriaId,Estado) INCLUDE(Total);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'FK_GastosOperativos_Departamento') ALTER TABLE dbo.GastosOperativos ADD CONSTRAINT FK_GastosOperativos_Departamento FOREIGN KEY(DepartamentoId) REFERENCES dbo.DepartamentosOperativos(DepartamentoId);
IF NOT EXISTS(SELECT 1 FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'FK_GastosOperativos_Categoria') ALTER TABLE dbo.GastosOperativos ADD CONSTRAINT FK_GastosOperativos_Categoria FOREIGN KEY(CategoriaId) REFERENCES dbo.CategoriasGasto(CategoriaId);
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'CK_GastosOperativos_Estado') ALTER TABLE dbo.GastosOperativos ADD CONSTRAINT CK_GastosOperativos_Estado CHECK(Estado IS NULL OR Estado IN(N'Registrado',N'Aprobado',N'Rechazado',N'Pagado',N'Anulado'));
IF NOT EXISTS(SELECT 1 FROM sys.check_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.GastosOperativos') AND name=N'CK_GastosOperativos_Montos') ALTER TABLE dbo.GastosOperativos ADD CONSTRAINT CK_GastosOperativos_Montos CHECK(Subtotal IS NULL OR(Subtotal>=0 AND Impuesto>=0 AND Total=ROUND(Subtotal+Impuesto,2)));

IF OBJECT_ID(N'dbo.GastoOperativoAuditoria',N'U') IS NULL CREATE TABLE dbo.GastoOperativoAuditoria(GastoAuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_GastoOperativoAuditoria PRIMARY KEY,GastoId INT NOT NULL,Accion NVARCHAR(50) NOT NULL,UsuarioId INT NOT NULL,UsuarioNombre NVARCHAR(150) NOT NULL,Detalle NVARCHAR(800) NULL,FechaUtc DATETIME2(0) NOT NULL CONSTRAINT DF_GastoOperativoAuditoria_Fecha DEFAULT SYSUTCDATETIME(),CONSTRAINT FK_GastoOperativoAuditoria_Gasto FOREIGN KEY(GastoId) REFERENCES dbo.GastosOperativos(GastoId));

IF OBJECT_ID(N'dbo.Permisos',N'U') IS NOT NULL
BEGIN
 MERGE dbo.Permisos t USING(VALUES(N'GASTOS_VER',N'Gastos',N'Ver gastos',N'Consulta gastos y comprobantes privados.'),(N'GASTOS_REGISTRAR',N'Gastos',N'Registrar gastos',N'Registra gastos con idempotencia.'),(N'GASTOS_EDITAR',N'Gastos',N'Editar gastos',N'Edita gastos registrados.'),(N'GASTOS_APROBAR',N'Gastos',N'Aprobar gastos',N'Aprueba o rechaza gastos.'),(N'GASTOS_PAGAR',N'Gastos',N'Pagar gastos',N'Marca gastos aprobados como pagados.'),(N'GASTOS_ANULAR',N'Gastos',N'Anular gastos',N'Anula gastos no pagados.'),(N'GASTOS_EXCEDER_PRESUPUESTO',N'Gastos',N'Autorizar exceso',N'Permite aprobar sobre el presupuesto disponible.'),(N'GASTOS_LEGADO_VER',N'Gastos',N'Ver cuentas legadas',N'Consulta temporal de cuentas mensuales legadas.'))s(Codigo,Modulo,Nombre,Descripcion) ON t.Codigo=s.Codigo
 WHEN MATCHED THEN UPDATE SET Modulo=s.Modulo,Nombre=s.Nombre,Descripcion=s.Descripcion,Activo=1 WHEN NOT MATCHED THEN INSERT(Codigo,Modulo,Nombre,Descripcion,Activo)VALUES(s.Codigo,s.Modulo,s.Nombre,s.Descripcion,1);
 IF OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NOT NULL INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre) SELECT p.PerfilId,pm.PermisoId,NULL,N'Migración 0010' FROM dbo.Perfiles p CROSS JOIN dbo.Permisos pm WHERE p.Nombre=N'Administrador' AND pm.Codigo LIKE N'GASTOS_%' AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=p.PerfilId AND x.PermisoId=pm.PermisoId);
END;
COMMIT;
GO

CREATE OR ALTER VIEW dbo.vw_OperatingExpenseImpact AS
SELECT g.GastoId,g.FechaGasto,g.DepartamentoId,d.Nombre Departamento,g.CategoriaId,c.Nombre Categoria,g.Proveedor,g.NumeroDocumento,g.TipoDocumento,g.Descripcion,g.Subtotal,g.Impuesto,g.Total,g.MetodoPago,g.Moneda,g.Estado,g.CreadoPorUsuarioId,g.CreadoPorNombre,g.FechaCreacionUtc,g.MotivoCancelacion,g.ComprobanteNombreOriginal,
 CAST(CASE WHEN g.ComprobanteStorageStatus=N'Ready' THEN 1 ELSE 0 END AS BIT) TieneComprobante,ISNULL(b.MontoPresupuesto,0) MontoPresupuesto,ISNULL(r.GastoReal,0) GastoReal,ISNULL(r.GastoComprometido,0) GastoComprometido,
 CAST(CASE WHEN ISNULL(b.MontoPresupuesto,0)=0 THEN 0 ELSE (ISNULL(r.GastoReal,0)+ISNULL(r.GastoComprometido,0))/b.MontoPresupuesto*100 END AS DECIMAL(9,2)) PorcentajeEjecucion,
 CASE WHEN ISNULL(b.MontoPresupuesto,0)>0 AND (ISNULL(r.GastoReal,0)+ISNULL(r.GastoComprometido,0))/b.MontoPresupuesto*100>=100 THEN N'Excedido' WHEN ISNULL(b.MontoPresupuesto,0)>0 AND (ISNULL(r.GastoReal,0)+ISNULL(r.GastoComprometido,0))/b.MontoPresupuesto*100>=90 THEN N'Crítico' WHEN ISNULL(b.MontoPresupuesto,0)>0 AND (ISNULL(r.GastoReal,0)+ISNULL(r.GastoComprometido,0))/b.MontoPresupuesto*100>=80 THEN N'Advertencia' ELSE N'Normal' END NivelConsumo
FROM dbo.GastosOperativos g INNER JOIN dbo.DepartamentosOperativos d ON d.DepartamentoId=g.DepartamentoId INNER JOIN dbo.CategoriasGasto c ON c.CategoriaId=g.CategoriaId
OUTER APPLY(SELECT SUM(pd.MontoAsignado) MontoPresupuesto FROM dbo.PresupuestosAnuales p INNER JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId WHERE p.Anio=YEAR(g.FechaGasto) AND p.DepartamentoId=g.DepartamentoId AND pd.CategoriaId=g.CategoriaId AND pd.Mes=MONTH(g.FechaGasto) AND p.Estado=N'Aprobado' AND p.Activo=1)b
OUTER APPLY(SELECT SUM(CASE WHEN x.Estado IN(N'Aprobado',N'Pagado') THEN x.Total ELSE 0 END)GastoReal,SUM(CASE WHEN x.Estado=N'Registrado' THEN x.Total ELSE 0 END)GastoComprometido FROM dbo.GastosOperativos x WHERE YEAR(x.FechaGasto)=YEAR(g.FechaGasto) AND MONTH(x.FechaGasto)=MONTH(g.FechaGasto) AND x.DepartamentoId=g.DepartamentoId AND x.CategoriaId=g.CategoriaId)r;
GO

CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_GetOptions AS BEGIN SET NOCOUNT ON; SELECT DepartamentoId,Nombre FROM dbo.DepartamentosOperativos WHERE Activo=1 ORDER BY Nombre; SELECT CategoriaId,Nombre FROM dbo.CategoriasGasto WHERE Activo=1 ORDER BY Nombre; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_List @Busqueda NVARCHAR(180)=NULL,@Desde DATE=NULL,@Hasta DATE=NULL,@DepartamentoId INT=NULL,@CategoriaId INT=NULL,@Estado NVARCHAR(30)=NULL,@Pagina INT=1,@TamanoPagina INT=20 AS
BEGIN
 SET NOCOUNT ON; SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END;SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
 ;WITH q AS(SELECT *,COUNT(*)OVER()TotalResultados FROM dbo.vw_OperatingExpenseImpact WHERE(@Busqueda IS NULL OR NumeroDocumento LIKE N'%'+@Busqueda+N'%' OR Proveedor LIKE N'%'+@Busqueda+N'%' OR Descripcion LIKE N'%'+@Busqueda+N'%')AND(@Desde IS NULL OR FechaGasto>=@Desde)AND(@Hasta IS NULL OR FechaGasto<=@Hasta)AND(@DepartamentoId IS NULL OR DepartamentoId=@DepartamentoId)AND(@CategoriaId IS NULL OR CategoriaId=@CategoriaId)AND(@Estado IS NULL OR Estado=@Estado))
 SELECT * FROM q ORDER BY FechaGasto DESC,GastoId DESC OFFSET(@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
 DECLARE @presupuesto DECIMAL(18,2)=(SELECT ISNULL(SUM(pd.MontoAsignado),0)FROM dbo.PresupuestosAnuales p JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId WHERE p.Estado=N'Aprobado' AND p.Activo=1 AND(@DepartamentoId IS NULL OR p.DepartamentoId=@DepartamentoId)AND(@CategoriaId IS NULL OR pd.CategoriaId=@CategoriaId)AND(@Desde IS NULL OR DATEFROMPARTS(p.Anio,pd.Mes,1)>=DATEFROMPARTS(YEAR(@Desde),MONTH(@Desde),1))AND(@Hasta IS NULL OR DATEFROMPARTS(p.Anio,pd.Mes,1)<=EOMONTH(@Hasta)));
 DECLARE @real DECIMAL(18,2)=(SELECT ISNULL(SUM(Total),0)FROM dbo.GastosOperativos WHERE Estado IN(N'Aprobado',N'Pagado')AND(@Desde IS NULL OR FechaGasto>=@Desde)AND(@Hasta IS NULL OR FechaGasto<=@Hasta)AND(@DepartamentoId IS NULL OR DepartamentoId=@DepartamentoId)AND(@CategoriaId IS NULL OR CategoriaId=@CategoriaId));
 SELECT ISNULL(SUM(CASE WHEN Estado=N'Registrado' THEN Total ELSE 0 END),0),ISNULL(SUM(CASE WHEN Estado=N'Aprobado' THEN Total ELSE 0 END),0),ISNULL(SUM(CASE WHEN Estado=N'Pagado' THEN Total ELSE 0 END),0),ISNULL(SUM(CASE WHEN Estado=N'Registrado' THEN Total ELSE 0 END),0),@presupuesto-@real FROM dbo.GastosOperativos WHERE(@Desde IS NULL OR FechaGasto>=@Desde)AND(@Hasta IS NULL OR FechaGasto<=@Hasta)AND(@DepartamentoId IS NULL OR DepartamentoId=@DepartamentoId)AND(@CategoriaId IS NULL OR CategoriaId=@CategoriaId);
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_GetById @GastoId INT AS
BEGIN SET NOCOUNT ON;SELECT * FROM dbo.vw_OperatingExpenseImpact WHERE GastoId=@GastoId;SELECT Accion,UsuarioNombre,FechaUtc,Detalle FROM dbo.GastoOperativoAuditoria WHERE GastoId=@GastoId ORDER BY FechaUtc DESC;END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_GetForEdit @GastoId INT AS
BEGIN SET NOCOUNT ON;SELECT GastoId,FechaGasto,DepartamentoId,CategoriaId,Proveedor,NumeroDocumento,TipoDocumento,Descripcion,Subtotal,Impuesto,MetodoPago,TokenOperacion FROM dbo.GastosOperativos WHERE GastoId=@GastoId AND Estado=N'Registrado';END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_Create @GastoId INT=NULL,@FechaGasto DATE,@FechaNegocio DATE,@DepartamentoId INT,@CategoriaId INT,@Proveedor NVARCHAR(180)=NULL,@NumeroDocumento NVARCHAR(80),@TipoDocumento NVARCHAR(40),@Descripcion NVARCHAR(500),@Subtotal DECIMAL(18,2),@Impuesto DECIMAL(18,2),@MetodoPago NVARCHAR(40),@TokenOperacion UNIQUEIDENTIFIER,@ComprobanteNombreOriginal NVARCHAR(255)=NULL,@ComprobanteStorageKey NVARCHAR(80)=NULL,@ComprobanteMimeType NVARCHAR(100)=NULL,@ComprobanteExtension NVARCHAR(10)=NULL,@ComprobanteTamanoBytes BIGINT=NULL,@ComprobanteHashSha256 CHAR(64)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 IF @FechaGasto>@FechaNegocio OR @FechaGasto<DATEADD(YEAR,-2,@FechaNegocio) THROW 54300,N'Fecha de gasto inválida.',1;
 IF @Subtotal<=0 OR @Impuesto<0 THROW 54301,N'Montos de gasto inválidos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.DepartamentosOperativos WHERE DepartamentoId=@DepartamentoId AND Activo=1) OR NOT EXISTS(SELECT 1 FROM dbo.CategoriasGasto WHERE CategoriaId=@CategoriaId AND Activo=1) THROW 54312,N'Departamento o categoría inactivo.',1;
 BEGIN TRANSACTION;DECLARE @id INT;
 SELECT @id=GastoId FROM dbo.GastosOperativos WITH(UPDLOCK,HOLDLOCK) WHERE TokenOperacion=@TokenOperacion;
 IF @id IS NOT NULL BEGIN COMMIT;SELECT GastoId,CAST(1 AS BIT)Duplicado,NivelConsumo,PorcentajeEjecucion FROM dbo.vw_OperatingExpenseImpact WHERE GastoId=@id;RETURN;END;
 IF EXISTS(SELECT 1 FROM dbo.GastosOperativos WITH(UPDLOCK,HOLDLOCK) WHERE DepartamentoId=@DepartamentoId AND NumeroDocumento=LTRIM(RTRIM(@NumeroDocumento)) AND ISNULL(Proveedor,N'')=ISNULL(NULLIF(LTRIM(RTRIM(@Proveedor)),N''),N'') AND Estado<>N'Anulado') THROW 54313,N'Existe un gasto activo con el mismo proveedor y número de documento.',1;
 INSERT dbo.GastosOperativos(FechaGasto,DepartamentoId,CategoriaId,Proveedor,NumeroDocumento,TipoDocumento,Descripcion,Subtotal,Impuesto,Total,MetodoPago,Moneda,Estado,TokenOperacion,ComprobanteNombreOriginal,ComprobanteStorageKey,ComprobanteMimeType,ComprobanteExtension,ComprobanteTamanoBytes,ComprobanteHashSha256,ComprobanteStorageStatus,CreadoPorUsuarioId,CreadoPorNombre,ActualizadoPorUsuarioId,ActualizadoPorNombre,FechaCreacionUtc,FechaActualizacionUtc)
 VALUES(@FechaGasto,@DepartamentoId,@CategoriaId,NULLIF(LTRIM(RTRIM(@Proveedor)),N''),LTRIM(RTRIM(@NumeroDocumento)),@TipoDocumento,LTRIM(RTRIM(@Descripcion)),@Subtotal,@Impuesto,ROUND(@Subtotal+@Impuesto,2),@MetodoPago,'CRC',N'Registrado',@TokenOperacion,@ComprobanteNombreOriginal,@ComprobanteStorageKey,@ComprobanteMimeType,@ComprobanteExtension,@ComprobanteTamanoBytes,@ComprobanteHashSha256,CASE WHEN @ComprobanteStorageKey IS NULL THEN NULL ELSE N'Pending' END,@UsuarioId,@UsuarioNombre,@UsuarioId,@UsuarioNombre,SYSUTCDATETIME(),SYSUTCDATETIME());SET @id=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.GastoOperativoAuditoria(GastoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@id,N'Registrar',@UsuarioId,@UsuarioNombre,N'Gasto creado con token idempotente.');COMMIT;
 SELECT GastoId,CAST(0 AS BIT)Duplicado,NivelConsumo,PorcentajeEjecucion FROM dbo.vw_OperatingExpenseImpact WHERE GastoId=@id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_Update @GastoId INT,@FechaGasto DATE,@FechaNegocio DATE,@DepartamentoId INT,@CategoriaId INT,@Proveedor NVARCHAR(180)=NULL,@NumeroDocumento NVARCHAR(80),@TipoDocumento NVARCHAR(40),@Descripcion NVARCHAR(500),@Subtotal DECIMAL(18,2),@Impuesto DECIMAL(18,2),@MetodoPago NVARCHAR(40),@TokenOperacion UNIQUEIDENTIFIER,@ComprobanteNombreOriginal NVARCHAR(255)=NULL,@ComprobanteStorageKey NVARCHAR(80)=NULL,@ComprobanteMimeType NVARCHAR(100)=NULL,@ComprobanteExtension NVARCHAR(10)=NULL,@ComprobanteTamanoBytes BIGINT=NULL,@ComprobanteHashSha256 CHAR(64)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;IF @FechaGasto>@FechaNegocio OR @FechaGasto<DATEADD(YEAR,-2,@FechaNegocio) THROW 54300,N'Fecha de gasto inválida.',1;IF @Subtotal<=0 OR @Impuesto<0 THROW 54301,N'Montos de gasto inválidos.',1;IF NOT EXISTS(SELECT 1 FROM dbo.DepartamentosOperativos WHERE DepartamentoId=@DepartamentoId AND Activo=1) OR NOT EXISTS(SELECT 1 FROM dbo.CategoriasGasto WHERE CategoriaId=@CategoriaId AND Activo=1) THROW 54312,N'Departamento o categoría inactivo.',1;UPDATE dbo.GastosOperativos SET FechaGasto=@FechaGasto,DepartamentoId=@DepartamentoId,CategoriaId=@CategoriaId,Proveedor=NULLIF(LTRIM(RTRIM(@Proveedor)),N''),NumeroDocumento=LTRIM(RTRIM(@NumeroDocumento)),TipoDocumento=@TipoDocumento,Descripcion=LTRIM(RTRIM(@Descripcion)),Subtotal=@Subtotal,Impuesto=@Impuesto,Total=ROUND(@Subtotal+@Impuesto,2),MetodoPago=@MetodoPago,ComprobanteNombreOriginal=COALESCE(@ComprobanteNombreOriginal,ComprobanteNombreOriginal),ComprobanteStorageKey=COALESCE(@ComprobanteStorageKey,ComprobanteStorageKey),ComprobanteMimeType=COALESCE(@ComprobanteMimeType,ComprobanteMimeType),ComprobanteExtension=COALESCE(@ComprobanteExtension,ComprobanteExtension),ComprobanteTamanoBytes=COALESCE(@ComprobanteTamanoBytes,ComprobanteTamanoBytes),ComprobanteHashSha256=COALESCE(@ComprobanteHashSha256,ComprobanteHashSha256),ComprobanteStorageStatus=CASE WHEN @ComprobanteStorageKey IS NULL THEN ComprobanteStorageStatus ELSE N'Pending' END,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME() WHERE GastoId=@GastoId AND Estado=N'Registrado';
 IF @@ROWCOUNT<>1 THROW 54302,N'Sólo se puede editar un gasto registrado.',1;INSERT dbo.GastoOperativoAuditoria(GastoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@GastoId,N'Editar',@UsuarioId,@UsuarioNombre,N'Datos del gasto actualizados.');
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_MarkReceiptReady @GastoId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS BEGIN SET NOCOUNT ON;UPDATE dbo.GastosOperativos SET ComprobanteStorageStatus=N'Ready' WHERE GastoId=@GastoId AND ComprobanteStorageStatus=N'Pending';IF @@ROWCOUNT<>1 THROW 54303,N'No existe comprobante pendiente.',1;INSERT dbo.GastoOperativoAuditoria(GastoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@GastoId,N'Confirmar comprobante',@UsuarioId,@UsuarioNombre,N'Archivo privado confirmado.');END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_DeletePendingReceipt @GastoId INT,@UsuarioId INT AS BEGIN SET NOCOUNT ON;UPDATE dbo.GastosOperativos SET ComprobanteNombreOriginal=NULL,ComprobanteStorageKey=NULL,ComprobanteMimeType=NULL,ComprobanteExtension=NULL,ComprobanteTamanoBytes=NULL,ComprobanteHashSha256=NULL,ComprobanteStorageStatus=NULL WHERE GastoId=@GastoId AND ComprobanteStorageStatus=N'Pending' AND CreadoPorUsuarioId=@UsuarioId;END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_Transition @GastoId INT,@Accion NVARCHAR(20),@Motivo NVARCHAR(500)=NULL,@AutorizarExceso BIT=0,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;BEGIN TRANSACTION;DECLARE @estado NVARCHAR(20),@creador INT,@fecha DATE,@dep INT,@cat INT,@total DECIMAL(18,2),@nuevo NVARCHAR(20);SELECT @estado=Estado,@creador=CreadoPorUsuarioId,@fecha=FechaGasto,@dep=DepartamentoId,@cat=CategoriaId,@total=Total FROM dbo.GastosOperativos WITH(UPDLOCK,HOLDLOCK) WHERE GastoId=@GastoId;
 IF @estado IS NULL THROW 54304,N'El gasto no existe.',1;
 IF @Accion=N'Aprobar' BEGIN IF @estado<>N'Registrado' THROW 54305,N'Transición inválida.',1;IF @creador=@UsuarioId THROW 54306,N'El registrador no puede aprobar su propio gasto.',1;DECLARE @budget DECIMAL(18,2)=(SELECT ISNULL(SUM(pd.MontoAsignado),0)FROM dbo.PresupuestosAnuales p JOIN dbo.PresupuestoDetalles pd ON pd.PresupuestoId=p.PresupuestoId WHERE p.Anio=YEAR(@fecha)AND p.DepartamentoId=@dep AND pd.CategoriaId=@cat AND pd.Mes=MONTH(@fecha)AND p.Estado=N'Aprobado'AND p.Activo=1);DECLARE @spent DECIMAL(18,2)=(SELECT ISNULL(SUM(Total),0)FROM dbo.GastosOperativos WHERE YEAR(FechaGasto)=YEAR(@fecha)AND MONTH(FechaGasto)=MONTH(@fecha)AND DepartamentoId=@dep AND CategoriaId=@cat AND Estado IN(N'Aprobado',N'Pagado'));IF(@budget=0 OR @spent+@total>@budget)AND @AutorizarExceso=0 THROW 54307,N'El gasto excede el presupuesto; se requiere autorización especial.',1;SET @nuevo=N'Aprobado';END
 ELSE IF @Accion=N'Rechazar' BEGIN IF @estado<>N'Registrado' OR NULLIF(LTRIM(RTRIM(@Motivo)),N'')IS NULL THROW 54308,N'El rechazo requiere motivo y estado registrado.',1;SET @nuevo=N'Rechazado';END
 ELSE IF @Accion=N'Pagar' BEGIN IF @estado<>N'Aprobado' THROW 54309,N'Sólo se paga un gasto aprobado.',1;SET @nuevo=N'Pagado';END
 ELSE IF @Accion=N'Anular' BEGIN IF @estado IN(N'Pagado',N'Anulado') OR NULLIF(LTRIM(RTRIM(@Motivo)),N'')IS NULL THROW 54310,N'No se puede anular o falta el motivo.',1;SET @nuevo=N'Anulado';END ELSE THROW 54311,N'Acción inválida.',1;
 UPDATE dbo.GastosOperativos SET Estado=@nuevo,MotivoCancelacion=CASE WHEN @nuevo IN(N'Rechazado',N'Anulado')THEN @Motivo ELSE MotivoCancelacion END,AnuladoPorUsuarioId=CASE WHEN @nuevo=N'Anulado'THEN @UsuarioId ELSE AnuladoPorUsuarioId END,FechaAnulacionUtc=CASE WHEN @nuevo=N'Anulado'THEN SYSUTCDATETIME() ELSE FechaAnulacionUtc END,ActualizadoPorUsuarioId=@UsuarioId,ActualizadoPorNombre=@UsuarioNombre,FechaActualizacionUtc=SYSUTCDATETIME()WHERE GastoId=@GastoId;INSERT dbo.GastoOperativoAuditoria(GastoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@GastoId,@Accion,@UsuarioId,@UsuarioNombre,CONCAT(@estado,N' -> ',@nuevo,N'. ',COALESCE(@Motivo,N''),CASE WHEN @AutorizarExceso=1 THEN N' Exceso autorizado.' ELSE N'' END));COMMIT;
END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_OperatingExpense_GetReceipt @GastoId INT,@UsuarioId INT,@PuedeAdministrar BIT=0 AS BEGIN SET NOCOUNT ON;SELECT ComprobanteStorageKey,ComprobanteNombreOriginal,ComprobanteMimeType FROM dbo.GastosOperativos WHERE GastoId=@GastoId AND ComprobanteStorageStatus=N'Ready' AND(@PuedeAdministrar=1 OR CreadoPorUsuarioId=@UsuarioId);END;
GO

IF OBJECT_ID(N'dbo.GastosOperativos',N'U') IS NULL OR OBJECT_ID(N'dbo.vw_OperatingExpenseImpact',N'V') IS NULL OR OBJECT_ID(N'dbo.sp_OperatingExpense_Transition',N'P') IS NULL THROW 54390,N'Validación posterior 0010 fallida.',1;
GO
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0010_operating_expenses_alignment')
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)VALUES(N'0010_operating_expenses_alignment',N'0010_operating_expenses_alignment.sql',CONVERT(CHAR(64),HASHBYTES('SHA2_256',N'0010_operating_expenses_alignment_v1'),2),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-222: alineación aditiva del legado, idempotencia, comprobantes privados y estados auditados.');
GO

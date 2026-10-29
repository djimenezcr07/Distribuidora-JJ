SET NOCOUNT ON;
SET XACT_ABORT ON;

/* CU-221. Rollback seguro: retirar procedimientos; preservar presupuestos y auditoría financiera. */
BEGIN TRANSACTION;
IF OBJECT_ID(N'dbo.CategoriasGasto',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.CategoriasGasto(CategoriaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_CategoriasGasto PRIMARY KEY,Codigo NVARCHAR(30) NOT NULL CONSTRAINT UQ_CategoriasGasto_Codigo UNIQUE,Nombre NVARCHAR(120) NOT NULL CONSTRAINT UQ_CategoriasGasto_Nombre UNIQUE,Activo BIT NOT NULL CONSTRAINT DF_CategoriasGasto_Activo DEFAULT 1);
END;
MERGE dbo.CategoriasGasto AS t USING(VALUES(N'ALQUILER',N'Alquiler'),(N'SERVICIOS',N'Servicios públicos'),(N'COMBUSTIBLE',N'Combustible'),(N'MANTENIMIENTO',N'Mantenimiento'),(N'SUMINISTROS',N'Suministros'),(N'OTROS',N'Otros'))s(Codigo,Nombre) ON t.Codigo=s.Codigo
WHEN MATCHED THEN UPDATE SET Nombre=s.Nombre,Activo=1 WHEN NOT MATCHED THEN INSERT(Codigo,Nombre,Activo)VALUES(s.Codigo,s.Nombre,1);

IF OBJECT_ID(N'dbo.PresupuestosAnuales',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.PresupuestosAnuales
 (
  PresupuestoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PresupuestosAnuales PRIMARY KEY,
  Anio INT NOT NULL,DepartamentoId INT NOT NULL,Moneda CHAR(3) NOT NULL CONSTRAINT DF_PresupuestosAnuales_Moneda DEFAULT 'CRC',
  MontoAnual DECIMAL(18,2) NOT NULL,Estado NVARCHAR(20) NOT NULL CONSTRAINT DF_PresupuestosAnuales_Estado DEFAULT N'Borrador',Notas NVARCHAR(800) NULL,
  Activo BIT NOT NULL CONSTRAINT DF_PresupuestosAnuales_Activo DEFAULT 1,CreadoPorUsuarioId INT NOT NULL,CreadoPorNombre NVARCHAR(150) NOT NULL,
  AprobadoPorUsuarioId INT NULL,AprobadoPorNombre NVARCHAR(150) NULL,FechaCreacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PresupuestosAnuales_Creacion DEFAULT SYSUTCDATETIME(),FechaActualizacionUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PresupuestosAnuales_Actualizacion DEFAULT SYSUTCDATETIME(),FechaAprobacionUtc DATETIME2(0) NULL,
  CONSTRAINT FK_PresupuestosAnuales_Departamento FOREIGN KEY(DepartamentoId) REFERENCES dbo.DepartamentosOperativos(DepartamentoId),
  CONSTRAINT FK_PresupuestosAnuales_Creador FOREIGN KEY(CreadoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
  CONSTRAINT CK_PresupuestosAnuales_Anio CHECK(Anio BETWEEN 2000 AND 2100),CONSTRAINT CK_PresupuestosAnuales_Monto CHECK(MontoAnual>0),
  CONSTRAINT CK_PresupuestosAnuales_Estado CHECK(Estado IN(N'Borrador',N'Presentado',N'Aprobado',N'Rechazado',N'Cerrado',N'Inactivo'))
 );
END;
IF NOT EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=OBJECT_ID(N'dbo.PresupuestosAnuales') AND name=N'UX_PresupuestosAnuales_AprobadoActivo')
 CREATE UNIQUE INDEX UX_PresupuestosAnuales_AprobadoActivo ON dbo.PresupuestosAnuales(Anio,DepartamentoId) WHERE Estado=N'Aprobado' AND Activo=1;

IF OBJECT_ID(N'dbo.PresupuestoDetalles',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.PresupuestoDetalles
 (
  PresupuestoDetalleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PresupuestoDetalles PRIMARY KEY,PresupuestoId INT NOT NULL,CategoriaId INT NOT NULL,Mes TINYINT NOT NULL,MontoAsignado DECIMAL(18,2) NOT NULL,Notas NVARCHAR(300) NULL,
  CONSTRAINT FK_PresupuestoDetalles_Presupuesto FOREIGN KEY(PresupuestoId) REFERENCES dbo.PresupuestosAnuales(PresupuestoId),CONSTRAINT FK_PresupuestoDetalles_Categoria FOREIGN KEY(CategoriaId) REFERENCES dbo.CategoriasGasto(CategoriaId),
  CONSTRAINT UQ_PresupuestoDetalles_Linea UNIQUE(PresupuestoId,CategoriaId,Mes),CONSTRAINT CK_PresupuestoDetalles_Mes CHECK(Mes BETWEEN 1 AND 12),CONSTRAINT CK_PresupuestoDetalles_Monto CHECK(MontoAsignado>=0)
 );
END;
IF OBJECT_ID(N'dbo.PresupuestoAuditoria',N'U') IS NULL
BEGIN
 CREATE TABLE dbo.PresupuestoAuditoria(PresupuestoAuditoriaId BIGINT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PresupuestoAuditoria PRIMARY KEY,PresupuestoId INT NOT NULL,Accion NVARCHAR(50) NOT NULL,UsuarioId INT NOT NULL,UsuarioNombre NVARCHAR(150) NOT NULL,Detalle NVARCHAR(800) NULL,FechaUtc DATETIME2(0) NOT NULL CONSTRAINT DF_PresupuestoAuditoria_Fecha DEFAULT SYSUTCDATETIME(),CONSTRAINT FK_PresupuestoAuditoria_Presupuesto FOREIGN KEY(PresupuestoId) REFERENCES dbo.PresupuestosAnuales(PresupuestoId));
END;
IF OBJECT_ID(N'dbo.Permisos',N'U') IS NOT NULL
BEGIN
 MERGE dbo.Permisos t USING(VALUES
 (N'PRESUPUESTOS_VER',N'Presupuestos',N'Ver presupuestos',N'Consulta presupuestos y su detalle.'),(N'PRESUPUESTOS_GESTIONAR',N'Presupuestos',N'Gestionar presupuestos',N'Crea y edita borradores.'),(N'PRESUPUESTOS_APROBAR',N'Presupuestos',N'Aprobar presupuestos',N'Aprueba o rechaza sin autoaprobación.'),(N'PRESUPUESTOS_CERRAR',N'Presupuestos',N'Cerrar presupuestos',N'Cierra presupuestos aprobados.'),(N'PRESUPUESTOS_COMPARAR',N'Presupuestos',N'Comparar presupuesto real',N'Consulta y exporta ejecución presupuestaria.'))s(Codigo,Modulo,Nombre,Descripcion) ON t.Codigo=s.Codigo
 WHEN MATCHED THEN UPDATE SET Modulo=s.Modulo,Nombre=s.Nombre,Descripcion=s.Descripcion,Activo=1 WHEN NOT MATCHED THEN INSERT(Codigo,Modulo,Nombre,Descripcion,Activo)VALUES(s.Codigo,s.Modulo,s.Nombre,s.Descripcion,1);
 IF OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NOT NULL INSERT dbo.PerfilPermisos(PerfilId,PermisoId,UsuarioAsignacionId,UsuarioAsignacionNombre)
 SELECT p.PerfilId,pm.PermisoId,NULL,N'Migración 0009' FROM dbo.Perfiles p CROSS JOIN dbo.Permisos pm WHERE p.Nombre=N'Administrador' AND pm.Codigo LIKE N'PRESUPUESTOS_%' AND NOT EXISTS(SELECT 1 FROM dbo.PerfilPermisos x WHERE x.PerfilId=p.PerfilId AND x.PermisoId=pm.PermisoId);
END;
COMMIT;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_GetOptions AS BEGIN SET NOCOUNT ON; SELECT DepartamentoId,Nombre FROM dbo.DepartamentosOperativos WHERE Activo=1 ORDER BY Nombre; SELECT CategoriaId,Nombre FROM dbo.CategoriasGasto WHERE Activo=1 ORDER BY Nombre; END;
GO
CREATE OR ALTER PROCEDURE dbo.sp_Budget_List @Anio INT=NULL,@DepartamentoId INT=NULL,@Estado NVARCHAR(30)=NULL,@Pagina INT=1,@TamanoPagina INT=20 AS
BEGIN
 SET NOCOUNT ON; SET @Pagina=CASE WHEN @Pagina<1 THEN 1 ELSE @Pagina END; SET @TamanoPagina=CASE WHEN @TamanoPagina<1 THEN 20 WHEN @TamanoPagina>100 THEN 100 ELSE @TamanoPagina END;
 ;WITH q AS(SELECT p.PresupuestoId,p.Anio,p.DepartamentoId,d.Nombre Departamento,p.Moneda,p.Estado,p.Notas,p.MontoAnual,p.CreadoPorNombre,p.FechaCreacionUtc,p.Activo,COUNT(*) OVER() TotalResultados FROM dbo.PresupuestosAnuales p INNER JOIN dbo.DepartamentosOperativos d ON d.DepartamentoId=p.DepartamentoId WHERE(@Anio IS NULL OR p.Anio=@Anio)AND(@DepartamentoId IS NULL OR p.DepartamentoId=@DepartamentoId)AND(@Estado IS NULL OR p.Estado=@Estado))
 SELECT * FROM q ORDER BY Anio DESC,Departamento OFFSET(@Pagina-1)*@TamanoPagina ROWS FETCH NEXT @TamanoPagina ROWS ONLY;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_Create @Anio INT,@DepartamentoId INT,@CategoriaId INT,@MontoAnual DECIMAL(18,2),@Notas NVARCHAR(800)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
 IF @Anio NOT BETWEEN 2000 AND 2100 OR @MontoAnual<=0 THROW 54200,N'Datos presupuestarios inválidos.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.DepartamentosOperativos WHERE DepartamentoId=@DepartamentoId AND Activo=1) OR NOT EXISTS(SELECT 1 FROM dbo.CategoriasGasto WHERE CategoriaId=@CategoriaId AND Activo=1) THROW 54216,N'Departamento o categoría inactivo.',1;
 BEGIN TRANSACTION;
 IF EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales WITH(UPDLOCK,HOLDLOCK) WHERE Anio=@Anio AND DepartamentoId=@DepartamentoId AND Estado IN(N'Borrador',N'Presentado',N'Aprobado',N'Rechazado') AND Activo=1) THROW 54201,N'Ya existe un presupuesto activo para el departamento y año.',1;
 INSERT dbo.PresupuestosAnuales(Anio,DepartamentoId,MontoAnual,Notas,CreadoPorUsuarioId,CreadoPorNombre)VALUES(@Anio,@DepartamentoId,@MontoAnual,NULLIF(LTRIM(RTRIM(@Notas)),N''),@UsuarioId,@UsuarioNombre);
 DECLARE @id INT=CONVERT(INT,SCOPE_IDENTITY()),@mes INT=1,@regular DECIMAL(18,2)=ROUND(@MontoAnual/12,2),@acumulado DECIMAL(18,2)=0;
 WHILE @mes<=12 BEGIN DECLARE @monto DECIMAL(18,2)=CASE WHEN @mes=12 THEN @MontoAnual-@acumulado ELSE @regular END; INSERT dbo.PresupuestoDetalles(PresupuestoId,CategoriaId,Mes,MontoAsignado)VALUES(@id,@CategoriaId,@mes,@monto); SET @acumulado+=@monto; SET @mes+=1; END;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@id,N'Crear',@UsuarioId,@UsuarioNombre,N'Presupuesto creado en borrador y distribuido en 12 meses.');
 COMMIT; SELECT @id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_GetById @PresupuestoId INT AS
BEGIN
 SET NOCOUNT ON;
 SELECT p.PresupuestoId,p.Anio,p.DepartamentoId,d.Nombre Departamento,p.Moneda,p.Estado,p.Notas,p.MontoAnual,p.CreadoPorNombre,p.FechaCreacionUtc,p.Activo FROM dbo.PresupuestosAnuales p INNER JOIN dbo.DepartamentosOperativos d ON d.DepartamentoId=p.DepartamentoId WHERE p.PresupuestoId=@PresupuestoId;
 SELECT pd.PresupuestoDetalleId,pd.CategoriaId,c.Nombre,pd.Mes,pd.MontoAsignado,pd.Notas FROM dbo.PresupuestoDetalles pd INNER JOIN dbo.CategoriasGasto c ON c.CategoriaId=pd.CategoriaId WHERE pd.PresupuestoId=@PresupuestoId ORDER BY c.Nombre,pd.Mes;
 SELECT Accion,UsuarioNombre,FechaUtc,Detalle FROM dbo.PresupuestoAuditoria WHERE PresupuestoId=@PresupuestoId ORDER BY FechaUtc DESC;
 SELECT CategoriaId,Nombre FROM dbo.CategoriasGasto WHERE Activo=1 ORDER BY Nombre;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_UpdateDraft @PresupuestoId INT,@Anio INT,@MontoAnual DECIMAL(18,2),@Notas NVARCHAR(800)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON;SET XACT_ABORT ON;SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;BEGIN TRANSACTION;
 IF @Anio NOT BETWEEN 2000 AND 2100 OR @MontoAnual<=0 THROW 54200,N'Datos presupuestarios inválidos.',1;
 DECLARE @dep INT;SELECT @dep=DepartamentoId FROM dbo.PresupuestosAnuales WITH(UPDLOCK,HOLDLOCK) WHERE PresupuestoId=@PresupuestoId AND Estado IN(N'Borrador',N'Rechazado')AND Activo=1;
 IF @dep IS NULL THROW 54202,N'Sólo se puede editar un borrador o presupuesto rechazado.',1;
 IF EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales WHERE PresupuestoId<>@PresupuestoId AND Anio=@Anio AND DepartamentoId=@dep AND Estado IN(N'Borrador',N'Presentado',N'Aprobado',N'Rechazado')AND Activo=1) THROW 54201,N'Ya existe un presupuesto activo para el departamento y año.',1;
 UPDATE dbo.PresupuestosAnuales SET Anio=@Anio,MontoAnual=@MontoAnual,Notas=NULLIF(LTRIM(RTRIM(@Notas)),N''),FechaActualizacionUtc=SYSUTCDATETIME()WHERE PresupuestoId=@PresupuestoId;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@PresupuestoId,N'Editar encabezado',@UsuarioId,@UsuarioNombre,CONCAT(N'Año ',@Anio,N', monto ',@MontoAnual,N'.'));COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_SaveDetail @PresupuestoId INT,@PresupuestoDetalleId INT=NULL,@CategoriaId INT,@Mes TINYINT,@MontoAsignado DECIMAL(18,2),@Notas NVARCHAR(300)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales WHERE PresupuestoId=@PresupuestoId AND Estado IN(N'Borrador',N'Rechazado') AND Activo=1) THROW 54202,N'Sólo se puede editar un borrador o presupuesto rechazado.',1;
 IF @PresupuestoDetalleId IS NULL INSERT dbo.PresupuestoDetalles(PresupuestoId,CategoriaId,Mes,MontoAsignado,Notas)VALUES(@PresupuestoId,@CategoriaId,@Mes,@MontoAsignado,NULLIF(LTRIM(RTRIM(@Notas)),N''));
 ELSE BEGIN UPDATE dbo.PresupuestoDetalles SET CategoriaId=@CategoriaId,Mes=@Mes,MontoAsignado=@MontoAsignado,Notas=NULLIF(LTRIM(RTRIM(@Notas)),N'') WHERE PresupuestoDetalleId=@PresupuestoDetalleId AND PresupuestoId=@PresupuestoId; IF @@ROWCOUNT<>1 THROW 54203,N'La línea no existe.',1; END;
 UPDATE dbo.PresupuestosAnuales SET FechaActualizacionUtc=SYSUTCDATETIME() WHERE PresupuestoId=@PresupuestoId;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@PresupuestoId,N'Editar detalle',@UsuarioId,@UsuarioNombre,CONCAT(N'Categoría ',@CategoriaId,N', mes ',@Mes,N', monto ',@MontoAsignado,N'.'));
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_Distribute @PresupuestoId INT,@CategoriaId INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
 DECLARE @total DECIMAL(18,2); SELECT @total=MontoAnual FROM dbo.PresupuestosAnuales WITH(UPDLOCK) WHERE PresupuestoId=@PresupuestoId AND Estado IN(N'Borrador',N'Rechazado') AND Activo=1;
 IF @total IS NULL THROW 54204,N'El presupuesto no es editable.',1;
 DELETE dbo.PresupuestoDetalles WHERE PresupuestoId=@PresupuestoId;
 DECLARE @mes INT=1,@regular DECIMAL(18,2)=ROUND(@total/12,2),@suma DECIMAL(18,2)=0;
 WHILE @mes<=12 BEGIN DECLARE @m DECIMAL(18,2)=CASE WHEN @mes=12 THEN @total-@suma ELSE @regular END; INSERT dbo.PresupuestoDetalles(PresupuestoId,CategoriaId,Mes,MontoAsignado)VALUES(@PresupuestoId,@CategoriaId,@mes,@m); SET @suma+=@m; SET @mes+=1; END;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@PresupuestoId,N'Distribuir',@UsuarioId,@UsuarioNombre,N'Distribución exacta en 12 meses; ajuste de centavos en diciembre.'); COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_Transition @PresupuestoId INT,@Accion NVARCHAR(20),@Motivo NVARCHAR(500)=NULL,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; BEGIN TRANSACTION;
 DECLARE @estado NVARCHAR(20),@creador INT,@nuevo NVARCHAR(20); SELECT @estado=Estado,@creador=CreadoPorUsuarioId FROM dbo.PresupuestosAnuales WITH(UPDLOCK,HOLDLOCK) WHERE PresupuestoId=@PresupuestoId AND Activo=1;
 IF @estado IS NULL THROW 54205,N'El presupuesto no existe.',1;
 IF @Accion=N'Presentar' BEGIN IF @estado NOT IN(N'Borrador',N'Rechazado') THROW 54206,N'Transición inválida.',1; IF (SELECT ISNULL(SUM(MontoAsignado),0) FROM dbo.PresupuestoDetalles WHERE PresupuestoId=@PresupuestoId)<>(SELECT MontoAnual FROM dbo.PresupuestosAnuales WHERE PresupuestoId=@PresupuestoId) THROW 54207,N'El detalle debe sumar exactamente el monto anual.',1; SET @nuevo=N'Presentado'; END
 ELSE IF @Accion=N'Aprobar' BEGIN IF @estado<>N'Presentado' THROW 54206,N'Transición inválida.',1; IF @creador=@UsuarioId THROW 54208,N'El creador no puede aprobar su propio presupuesto.',1; IF EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales p JOIN dbo.PresupuestosAnuales actual ON actual.PresupuestoId=@PresupuestoId WHERE p.Anio=actual.Anio AND p.DepartamentoId=actual.DepartamentoId AND p.Estado=N'Aprobado' AND p.Activo=1) THROW 54209,N'Ya existe un presupuesto aprobado activo.',1; SET @nuevo=N'Aprobado'; END
 ELSE IF @Accion=N'Rechazar' BEGIN IF @estado<>N'Presentado' OR NULLIF(LTRIM(RTRIM(@Motivo)),N'') IS NULL THROW 54210,N'El rechazo requiere un motivo y estado presentado.',1; SET @nuevo=N'Rechazado'; END
 ELSE IF @Accion=N'Cerrar' BEGIN IF @estado<>N'Aprobado' THROW 54211,N'Sólo se puede cerrar un presupuesto aprobado.',1; SET @nuevo=N'Cerrado'; END
 ELSE THROW 54212,N'Acción presupuestaria inválida.',1;
 UPDATE dbo.PresupuestosAnuales SET Estado=@nuevo,FechaActualizacionUtc=SYSUTCDATETIME(),AprobadoPorUsuarioId=CASE WHEN @nuevo=N'Aprobado' THEN @UsuarioId ELSE AprobadoPorUsuarioId END,AprobadoPorNombre=CASE WHEN @nuevo=N'Aprobado' THEN @UsuarioNombre ELSE AprobadoPorNombre END,FechaAprobacionUtc=CASE WHEN @nuevo=N'Aprobado' THEN SYSUTCDATETIME() ELSE FechaAprobacionUtc END WHERE PresupuestoId=@PresupuestoId;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@PresupuestoId,@Accion,@UsuarioId,@UsuarioNombre,CONCAT(@estado,N' -> ',@nuevo,N'. ',COALESCE(@Motivo,N''))); COMMIT;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Budget_Copy @PresupuestoOrigenId INT,@AnioDestino INT,@UsuarioId INT,@UsuarioNombre NVARCHAR(150) AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON; SET TRANSACTION ISOLATION LEVEL SERIALIZABLE; BEGIN TRANSACTION;
 IF @AnioDestino NOT BETWEEN 2000 AND 2100 THROW 54213,N'Año destino inválido.',1;
 DECLARE @dep INT,@monto DECIMAL(18,2),@notas NVARCHAR(800); SELECT @dep=DepartamentoId,@monto=MontoAnual,@notas=Notas FROM dbo.PresupuestosAnuales WHERE PresupuestoId=@PresupuestoOrigenId;
 IF @dep IS NULL THROW 54214,N'El presupuesto origen no existe.',1;
 IF EXISTS(SELECT 1 FROM dbo.PresupuestosAnuales WITH(UPDLOCK,HOLDLOCK) WHERE Anio=@AnioDestino AND DepartamentoId=@dep AND Estado IN(N'Borrador',N'Presentado',N'Aprobado',N'Rechazado') AND Activo=1) THROW 54215,N'Ya existe un presupuesto activo en el año destino.',1;
 INSERT dbo.PresupuestosAnuales(Anio,DepartamentoId,MontoAnual,Notas,CreadoPorUsuarioId,CreadoPorNombre)VALUES(@AnioDestino,@dep,@monto,@notas,@UsuarioId,@UsuarioNombre); DECLARE @id INT=CONVERT(INT,SCOPE_IDENTITY());
 INSERT dbo.PresupuestoDetalles(PresupuestoId,CategoriaId,Mes,MontoAsignado,Notas)SELECT @id,CategoriaId,Mes,MontoAsignado,Notas FROM dbo.PresupuestoDetalles WHERE PresupuestoId=@PresupuestoOrigenId;
 INSERT dbo.PresupuestoAuditoria(PresupuestoId,Accion,UsuarioId,UsuarioNombre,Detalle)VALUES(@id,N'Copiar',@UsuarioId,@UsuarioNombre,CONCAT(N'Copiado desde presupuesto ',@PresupuestoOrigenId,N'.')); COMMIT; SELECT @id;
END;
GO

IF OBJECT_ID(N'dbo.PresupuestosAnuales',N'U') IS NULL OR OBJECT_ID(N'dbo.PresupuestoDetalles',N'U') IS NULL OR OBJECT_ID(N'dbo.sp_Budget_Transition',N'P') IS NULL THROW 54290,N'Validación posterior 0009 fallida.',1;
GO
IF OBJECT_ID(N'dbo.SchemaMigrationHistory',N'U') IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.SchemaMigrationHistory WHERE MigrationId=N'0009_annual_department_budgets')
 INSERT dbo.SchemaMigrationHistory(MigrationId,FileName,FileSha256,Status,AppliedBy,EnvironmentName,Notes)VALUES(N'0009_annual_department_budgets',N'0009_annual_department_budgets.sql',CONVERT(CHAR(64),HASHBYTES('SHA2_256',N'0009_annual_department_budgets_v1'),2),N'Applied',ORIGINAL_LOGIN(),DB_NAME(),N'CU-221: presupuesto anual normalizado, flujo de aprobación y segregación de funciones.');
GO

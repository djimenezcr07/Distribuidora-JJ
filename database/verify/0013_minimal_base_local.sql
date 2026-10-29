SET NOCOUNT ON;
SET XACT_ABORT ON;

IF OBJECT_ID(N'dbo.Usuarios',N'U') IS NULL
    CREATE TABLE dbo.Usuarios(UsuarioId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Usuarios PRIMARY KEY,NombreCompleto NVARCHAR(150) NOT NULL);
IF OBJECT_ID(N'dbo.Productos',N'U') IS NULL
    CREATE TABLE dbo.Productos(ProductoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Productos PRIMARY KEY,Nombre NVARCHAR(150) NOT NULL,Stock INT NOT NULL,Activo BIT NOT NULL);
IF OBJECT_ID(N'dbo.MovimientosInventario',N'U') IS NULL
    CREATE TABLE dbo.MovimientosInventario
    (
        MovimientoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_MovimientosInventario PRIMARY KEY,
        ProductoId INT NOT NULL,ProductoNombre NVARCHAR(150) NOT NULL,TipoMovimiento NVARCHAR(30) NOT NULL,Cantidad INT NOT NULL,
        StockAnterior INT NOT NULL,StockNuevo INT NOT NULL,Motivo NVARCHAR(250) NULL,UsuarioId INT NOT NULL,UsuarioNombre NVARCHAR(150) NOT NULL,
        FechaMovimiento DATETIME2 NOT NULL CONSTRAINT DF_MovimientosInventario_Fecha DEFAULT SYSDATETIME(),
        CONSTRAINT FK_MovimientosInventario_Producto FOREIGN KEY(ProductoId) REFERENCES dbo.Productos(ProductoId),
        CONSTRAINT FK_MovimientosInventario_Usuario FOREIGN KEY(UsuarioId) REFERENCES dbo.Usuarios(UsuarioId)
    );
IF OBJECT_ID(N'dbo.Permisos',N'U') IS NULL
    CREATE TABLE dbo.Permisos(PermisoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Permisos PRIMARY KEY,Codigo NVARCHAR(100) NOT NULL CONSTRAINT UQ_Permisos_Codigo UNIQUE,Modulo NVARCHAR(100) NOT NULL,Nombre NVARCHAR(150) NOT NULL,Descripcion NVARCHAR(500) NULL,Activo BIT NOT NULL);
IF OBJECT_ID(N'dbo.Perfiles',N'U') IS NULL
    CREATE TABLE dbo.Perfiles(PerfilId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Perfiles PRIMARY KEY,Nombre NVARCHAR(100) NOT NULL);
IF OBJECT_ID(N'dbo.PerfilPermisos',N'U') IS NULL
    CREATE TABLE dbo.PerfilPermisos(PerfilId INT NOT NULL,PermisoId INT NOT NULL,UsuarioAsignacionId INT NULL,UsuarioAsignacionNombre NVARCHAR(150) NULL,CONSTRAINT PK_PerfilPermisos PRIMARY KEY(PerfilId,PermisoId));

IF NOT EXISTS(SELECT 1 FROM dbo.Usuarios) INSERT dbo.Usuarios(NombreCompleto) VALUES(N'QA Compras');
IF NOT EXISTS(SELECT 1 FROM dbo.Productos) INSERT dbo.Productos(Nombre,Stock,Activo) VALUES(N'Producto QA',10,1),(N'Producto inactivo',5,0);
IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WHERE Nombre=N'Compras') INSERT dbo.Perfiles(Nombre) VALUES(N'Compras');
IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WHERE Nombre=N'Administrador') INSERT dbo.Perfiles(Nombre) VALUES(N'Administrador');
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetPurchaseSuggestions @MesesRecientes INT=3,@MesesCobertura INT=2 AS
BEGIN
    SET NOCOUNT ON;
    SELECT ProductoId,Nombre,Stock StockActual,1 StockMinimo,0 UnidadesVendidasVentana,CONVERT(DECIMAL(18,2),0) PromedioVentaMensual,
           @MesesCobertura MesesCobertura,0 CantidadSugerida,CONVERT(BIT,1) DatosInsuficientes
    FROM dbo.Productos WHERE Activo=1;
END;
GO

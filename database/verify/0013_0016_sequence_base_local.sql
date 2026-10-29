SET NOCOUNT ON;
SET XACT_ABORT ON;

IF CONVERT(INT,SERVERPROPERTY(N'IsLocalDB'))<>1 OR DB_NAME() NOT LIKE N'TrilogiaMigrations[_]%'
    THROW 55400,N'Esta fixture solo puede ejecutarse en la LocalDB desechable del harness 0013-0016.',1;

IF NOT EXISTS(SELECT 1 FROM dbo.Perfiles WHERE Nombre=N'Gerente') INSERT dbo.Perfiles(Nombre) VALUES(N'Gerente');
IF COL_LENGTH(N'dbo.Usuarios',N'PerfilId') IS NULL ALTER TABLE dbo.Usuarios ADD PerfilId INT NULL;
IF COL_LENGTH(N'dbo.Usuarios',N'Activo') IS NULL ALTER TABLE dbo.Usuarios ADD Activo BIT NOT NULL CONSTRAINT DF_Usuarios_Activo_QA DEFAULT 1;
IF COL_LENGTH(N'dbo.Usuarios',N'Correo') IS NULL ALTER TABLE dbo.Usuarios ADD Correo NVARCHAR(320) NULL;
GO
UPDATE dbo.Usuarios SET PerfilId=(SELECT TOP(1) PerfilId FROM dbo.Perfiles WHERE Nombre=N'Administrador') WHERE PerfilId IS NULL;
UPDATE dbo.Usuarios SET Correo=COALESCE(Correo,N'qa@example.invalid');

IF COL_LENGTH(N'dbo.Productos',N'Categoria') IS NULL ALTER TABLE dbo.Productos ADD Categoria NVARCHAR(100) NULL;
IF COL_LENGTH(N'dbo.Productos',N'Precio') IS NULL ALTER TABLE dbo.Productos ADD Precio DECIMAL(18,2) NULL;
IF COL_LENGTH(N'dbo.Productos',N'ImagenUrl') IS NULL ALTER TABLE dbo.Productos ADD ImagenUrl NVARCHAR(255) NULL;
GO
UPDATE dbo.Productos SET Categoria=COALESCE(Categoria,N'QA'),Precio=COALESCE(Precio,100),ImagenUrl=COALESCE(ImagenUrl,N'~/img/whisky-premium.webp');
ALTER TABLE dbo.Productos ALTER COLUMN Categoria NVARCHAR(100) NOT NULL;
ALTER TABLE dbo.Productos ALTER COLUMN Precio DECIMAL(18,2) NOT NULL;

IF OBJECT_ID(N'dbo.Pedidos',N'U') IS NULL
 CREATE TABLE dbo.Pedidos(PedidoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Pedidos PRIMARY KEY,UsuarioId INT NULL,VendedorUsuarioId INT NULL,Estado NVARCHAR(30) NOT NULL);
IF OBJECT_ID(N'dbo.PedidoDetalle',N'U') IS NULL
 CREATE TABLE dbo.PedidoDetalle(PedidoDetalleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_PedidoDetalle PRIMARY KEY,PedidoId INT NOT NULL,ProductoId INT NOT NULL,Cantidad INT NOT NULL,CONSTRAINT FK_PedidoDetalle_Pedido FOREIGN KEY(PedidoId) REFERENCES dbo.Pedidos(PedidoId),CONSTRAINT FK_PedidoDetalle_Producto FOREIGN KEY(ProductoId) REFERENCES dbo.Productos(ProductoId));
IF OBJECT_ID(N'dbo.Facturas',N'U') IS NULL
 CREATE TABLE dbo.Facturas(FacturaId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Facturas PRIMARY KEY,PedidoId INT NOT NULL,FechaFactura DATETIME2(0) NOT NULL,Total DECIMAL(18,2) NOT NULL,Estado NVARCHAR(30) NOT NULL);
IF OBJECT_ID(N'dbo.FacturaDetalle',N'U') IS NULL
 CREATE TABLE dbo.FacturaDetalle(FacturaDetalleId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_FacturaDetalle PRIMARY KEY,FacturaId INT NOT NULL,ProductoId INT NOT NULL,Cantidad INT NOT NULL,Subtotal DECIMAL(18,2) NOT NULL,CONSTRAINT FK_FacturaDetalle_Factura FOREIGN KEY(FacturaId) REFERENCES dbo.Facturas(FacturaId),CONSTRAINT FK_FacturaDetalle_Producto FOREIGN KEY(ProductoId) REFERENCES dbo.Productos(ProductoId));

SELECT N'Fixture secuencial 0013-0016 lista' Resultado;

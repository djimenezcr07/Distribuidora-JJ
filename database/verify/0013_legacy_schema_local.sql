SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE dbo.Proveedores
(
    ProveedorId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Proveedores PRIMARY KEY,
    Nombre NVARCHAR(150) NOT NULL,Contacto NVARCHAR(150) NULL,Telefono NVARCHAR(30) NULL,Email NVARCHAR(150) NULL,
    Activo BIT NOT NULL CONSTRAINT DF_Proveedores_Activo DEFAULT(1),FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_Proveedores_FechaCreacion DEFAULT SYSUTCDATETIME(),FechaActualizacion DATETIME2(0) NULL
);
CREATE TABLE dbo.OrdenesCompra
(
    OrdenCompraId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_OrdenesCompra PRIMARY KEY,ProveedorId INT NOT NULL,
    Estado NVARCHAR(20) NOT NULL CONSTRAINT DF_OrdenesCompra_Estado DEFAULT N'Pendiente',Notas NVARCHAR(300) NULL,
    UsuarioCreacionId INT NULL,UsuarioCreacionNombre NVARCHAR(150) NULL,FechaCreacion DATETIME2(0) NOT NULL CONSTRAINT DF_OrdenesCompra_FechaCreacion DEFAULT SYSUTCDATETIME(),FechaRecepcion DATETIME2(0) NULL,
    CONSTRAINT FK_OrdenesCompra_Proveedores FOREIGN KEY(ProveedorId) REFERENCES dbo.Proveedores(ProveedorId),
    CONSTRAINT CK_OrdenesCompra_Estado CHECK(Estado IN(N'Pendiente',N'RecibidaParcial',N'Recibida',N'ConDiscrepancia'))
);
CREATE TABLE dbo.DetalleOrdenCompra
(
    DetalleOrdenCompraId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_DetalleOrdenCompra PRIMARY KEY,OrdenCompraId INT NOT NULL,ProductoId INT NOT NULL,
    CantidadOrdenada INT NOT NULL,CantidadRecibida INT NOT NULL CONSTRAINT DF_DetalleOrdenCompra_CantidadRecibida DEFAULT(0),PrecioUnitario DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_DetalleOrdenCompra_Ordenes FOREIGN KEY(OrdenCompraId) REFERENCES dbo.OrdenesCompra(OrdenCompraId),
    CONSTRAINT FK_DetalleOrdenCompra_Productos FOREIGN KEY(ProductoId) REFERENCES dbo.Productos(ProductoId),
    CONSTRAINT CK_DetalleOrdenCompra_Cantidad CHECK(CantidadOrdenada>0 AND CantidadRecibida>=0)
);

INSERT dbo.Proveedores(Nombre,Contacto,Activo) VALUES(N'Proveedor legado',N'Contacto QA',1);
INSERT dbo.OrdenesCompra(ProveedorId,Estado,Notas,UsuarioCreacionId,UsuarioCreacionNombre) VALUES(1,N'RecibidaParcial',N'Orden preservada',1,N'QA Compras');
INSERT dbo.DetalleOrdenCompra(OrdenCompraId,ProductoId,CantidadOrdenada,CantidadRecibida,PrecioUnitario) VALUES(1,1,5,2,1000.00);
GO

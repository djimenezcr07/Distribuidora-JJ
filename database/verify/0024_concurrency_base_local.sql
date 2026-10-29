SET NOCOUNT ON;
SET XACT_ABORT ON;

CREATE TABLE dbo.Permisos
(
    PermisoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Permisos PRIMARY KEY,
    Codigo NVARCHAR(100) NOT NULL CONSTRAINT UQ_Permisos_Codigo UNIQUE,
    Modulo NVARCHAR(100) NOT NULL,
    Nombre NVARCHAR(150) NOT NULL,
    Descripcion NVARCHAR(500) NULL,
    Activo BIT NOT NULL
);
CREATE TABLE dbo.Perfiles
(
    PerfilId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Perfiles PRIMARY KEY,
    Nombre NVARCHAR(100) NOT NULL
);
CREATE TABLE dbo.PerfilPermisos
(
    PerfilId INT NOT NULL,
    PermisoId INT NOT NULL,
    UsuarioAsignacionId INT NULL,
    UsuarioAsignacionNombre NVARCHAR(150) NULL,
    CONSTRAINT PK_PerfilPermisos PRIMARY KEY (PerfilId, PermisoId)
);
CREATE TABLE dbo.Vehiculos
(
    VehiculoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_Vehiculos PRIMARY KEY,
    Placa NVARCHAR(20) NOT NULL,
    Descripcion NVARCHAR(150) NOT NULL,
    KilometrajeActual INT NOT NULL
);
CREATE TABLE dbo.VehiculoKilometraje
(
    KilometrajeId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_VehiculoKilometraje PRIMARY KEY,
    VehiculoId INT NOT NULL,
    ChoferUsuarioId INT NULL,
    ChoferNombre NVARCHAR(150) NULL,
    Fecha DATE NOT NULL CONSTRAINT DF_Verify0024_Fecha DEFAULT CAST(SYSDATETIME() AS DATE),
    KmInicial INT NOT NULL,
    KmFinal INT NULL,
    Observaciones NVARCHAR(300) NULL,
    FechaRegistro DATETIME2 NOT NULL CONSTRAINT DF_Verify0024_Registro DEFAULT SYSDATETIME(),
    FechaCierre DATETIME2 NULL
);

INSERT dbo.Perfiles (Nombre) VALUES (N'Administrador');
INSERT dbo.Vehiculos (Placa, Descripcion, KilometrajeActual) VALUES (N'QA-0024', N'Vehículo desechable', 100);
INSERT dbo.VehiculoKilometraje (VehiculoId, ChoferUsuarioId, ChoferNombre, KmInicial)
VALUES (1, 42, N'Chofer QA', 100);

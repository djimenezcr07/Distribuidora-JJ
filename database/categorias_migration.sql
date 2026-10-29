USE DistribuidoraJJ_DB;
GO

IF OBJECT_ID('dbo.Categorias', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.Categorias (
        CategoriaId INT IDENTITY(1,1) PRIMARY KEY,
        Nombre NVARCHAR(100) NOT NULL UNIQUE,
        Activo BIT NOT NULL DEFAULT 1,
        FechaCreacion DATETIME2 NOT NULL DEFAULT SYSDATETIME()
    );
END
GO

IF COL_LENGTH('dbo.Productos', 'CategoriaId') IS NULL
BEGIN
    ALTER TABLE dbo.Productos ADD CategoriaId INT NULL;
END
GO

INSERT INTO dbo.Categorias (Nombre)
SELECT DISTINCT p.Categoria
FROM dbo.Productos p
LEFT JOIN dbo.Categorias c ON c.Nombre = p.Categoria
WHERE p.Categoria IS NOT NULL
  AND LTRIM(RTRIM(p.Categoria)) <> ''
  AND c.CategoriaId IS NULL;
GO

UPDATE p
SET p.CategoriaId = c.CategoriaId
FROM dbo.Productos p
INNER JOIN dbo.Categorias c ON c.Nombre = p.Categoria
WHERE p.CategoriaId IS NULL;
GO

IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id = OBJECT_ID('dbo.Productos') AND name = 'CategoriaId' AND is_nullable = 1)
   AND NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE CategoriaId IS NULL)
BEGIN
    ALTER TABLE dbo.Productos ALTER COLUMN CategoriaId INT NOT NULL;
END
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_Productos_Categorias'
)
AND NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE CategoriaId IS NULL)
BEGIN
    ALTER TABLE dbo.Productos
    ADD CONSTRAINT FK_Productos_Categorias FOREIGN KEY (CategoriaId) REFERENCES dbo.Categorias(CategoriaId);
END
GO

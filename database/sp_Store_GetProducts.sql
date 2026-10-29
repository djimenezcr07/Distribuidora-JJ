USE DistribuidoraJJ_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        '~/img/whisky-premium.webp' AS ImagenUrl
    FROM dbo.Productos
    WHERE Activo = 1
      AND (
            @Categoria IS NULL
            OR Categoria LIKE '%' + @Categoria + '%'
          )
      AND (
            @Buscar IS NULL
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Categoria LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
          )
    ORDER BY Nombre ASC;
END
GO

USE DistribuidoraJJ_DB;
GO

SELECT
    u.UsuarioId,
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Perfil,
    u.Activo
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p
    ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Administrador';




USE DistribuidoraJJ_DB;
GO

DECLARE @DemoPasswordSeedOne NVARCHAR(256) = N'<SET_AT_EXECUTION>';

IF @DemoPasswordSeedOne = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 51001, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

INSERT INTO dbo.Usuarios
(
    PerfilId,
    NombreCompleto,
    Correo,
    Contrasena,
    Activo
)
VALUES
(
    (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador'),
    'Administrador General',
    'dannyJJ@labodega.com',
    @DemoPasswordSeedOne,
    1
);


USE DistribuidoraJJ_DB;
GO

SELECT DISTINCT Categoria, Activo
FROM dbo.Productos
ORDER BY Categoria;


USE DistribuidoraJJ_DB;
GO

IF COL_LENGTH('dbo.Productos', 'ImagenUrl') IS NULL
BEGIN
    ALTER TABLE dbo.Productos
    ADD ImagenUrl NVARCHAR(300) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Whisky Black Label 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Whisky Black Label 750ml',
        'Whisky',
        'Whisky premium de 750ml.',
        35900,
        15,
        1,
        '~/img/DES-Whisky Black Label.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Ron Añejo 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Ron Añejo 750ml',
        'Ron',
        'Ron añejo de presentación estándar.',
        12900,
        20,
        1,
        '~/img/CAT- Ron.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vodka Premium 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vodka Premium 750ml',
        'Vodka',
        'Vodka clásico de 750ml.',
        10900,
        18,
        1,
        '~/img/CAT-Vodka.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Tequila Reposado 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Tequila Reposado 750ml',
        'Tequila',
        'Tequila reposado de 750ml.',
        16900,
        12,
        1,
        '~/img/CAT-Tequila.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vino Tinto Reserva 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vino Tinto Reserva 750ml',
        'Vino',
        'Vino tinto reserva de 750ml.',
        8900,
        25,
        1,
        '~/img/DES-Vino Tinto Reserva 750ml.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Pack Cervezas 6 unidades')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Pack Cervezas 6 unidades',
        'Cerveza',
        'Pack de 6 cervezas.',
        6900,
        30,
        1,
        '~/img/DES-Pack Cervezas (6 unidades).webp'
    );
END
GO




USE DistribuidoraJJ_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Categoria
    FROM dbo.Productos
    WHERE Activo = 1
      AND Categoria IS NOT NULL
      AND LTRIM(RTRIM(Categoria)) <> ''
    ORDER BY Categoria ASC;
END
GO




USE DistribuidoraJJ_DB;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        ISNULL(NULLIF(LTRIM(RTRIM(ImagenUrl)), ''), '~/img/whisky-premium.webp') AS ImagenUrl
    FROM dbo.Productos
    WHERE Activo = 1
      AND (
            @Categoria IS NULL
            OR Categoria = @Categoria
          )
      AND (
            @Buscar IS NULL
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Categoria LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
          )
    ORDER BY Nombre ASC;
END
GO




USE DistribuidoraJJ_DB;
GO

IF COL_LENGTH('dbo.Productos', 'ImagenUrl') IS NULL
BEGIN
    ALTER TABLE dbo.Productos
    ADD ImagenUrl NVARCHAR(300) NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Whisky Black Label 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Whisky Black Label 750ml',
        'Whisky',
        'Whisky premium de 750ml.',
        35900,
        15,
        1,
        '~/img/DES-Whisky Black Label.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Ron Añejo 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Ron Añejo 750ml',
        'Ron',
        'Ron añejo de presentación estándar.',
        12900,
        20,
        1,
        '~/img/CAT- Ron.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vodka Premium 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vodka Premium 750ml',
        'Vodka',
        'Vodka clásico de 750ml.',
        10900,
        18,
        1,
        '~/img/CAT-Vodka.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Tequila Reposado 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Tequila Reposado 750ml',
        'Tequila',
        'Tequila reposado de 750ml.',
        16900,
        12,
        1,
        '~/img/CAT-Tequila.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vino Tinto Reserva 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vino Tinto Reserva 750ml',
        'Vino',
        'Vino tinto reserva de 750ml.',
        8900,
        25,
        1,
        '~/img/DES-Vino Tinto Reserva 750ml.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Pack Cervezas 6 unidades')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Pack Cervezas 6 unidades',
        'Cerveza',
        'Pack de 6 cervezas.',
        6900,
        30,
        1,
        '~/img/DES-Pack Cervezas (6 unidades).webp'
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Categoria
    FROM dbo.Productos
    WHERE Activo = 1
      AND Categoria IS NOT NULL
      AND LTRIM(RTRIM(Categoria)) <> ''
    ORDER BY Categoria ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        ISNULL(NULLIF(LTRIM(RTRIM(ImagenUrl)), ''), '~/img/whisky-premium.webp') AS ImagenUrl
    FROM dbo.Productos
    WHERE Activo = 1
      AND (
            @Categoria IS NULL
            OR Categoria = @Categoria
          )
      AND (
            @Buscar IS NULL
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Categoria LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
          )
    ORDER BY Nombre ASC;
END
GO

SELECT DISTINCT Categoria
FROM dbo.Productos
WHERE Activo = 1
ORDER BY Categoria;
GO

SELECT
    u.UsuarioId,
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Perfil,
    u.Activo
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p
    ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Administrador';
GO





USE DistribuidoraJJ_DB;
GO

SELECT
    u.UsuarioId,
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Perfil,
    u.Activo
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p
    ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Administrador';
GO

DECLARE @DemoPasswordSeedTwo NVARCHAR(256) = N'<SET_AT_EXECUTION>';

IF @DemoPasswordSeedTwo = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 51002, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

INSERT INTO dbo.Usuarios
(
    PerfilId,
    NombreCompleto,
    Correo,
    Contrasena,
    Activo
)
VALUES
(
    (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador'),
    'Administrador General',
    'admin@labodega.com',
    @DemoPasswordSeedTwo,
    1
);
GO







USE DistribuidoraJJ_DB;
GO

/* =========================================================
   1. AGREGAR COLUMNA ImagenUrl SI NO EXISTE
   ========================================================= */
IF COL_LENGTH('dbo.Productos', 'ImagenUrl') IS NULL
BEGIN
    ALTER TABLE dbo.Productos
    ADD ImagenUrl NVARCHAR(300) NULL;
END
GO

/* =========================================================
   2. INSERTAR PRODUCTOS BASE PARA LAS NUEVAS CATEGORIAS
   ========================================================= */

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Whisky Black Label 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Whisky Black Label 750ml',
        'Whisky',
        'Whisky premium de 750ml.',
        35900,
        15,
        1,
        '~/img/DES-Whisky Black Label.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Ron Añejo 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Ron Añejo 750ml',
        'Ron',
        'Ron añejo de presentación estándar.',
        12900,
        20,
        1,
        '~/img/CAT- Ron.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vodka Premium 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vodka Premium 750ml',
        'Vodka',
        'Vodka clásico de 750ml.',
        10900,
        18,
        1,
        '~/img/CAT-Vodka.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Tequila Reposado 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Tequila Reposado 750ml',
        'Tequila',
        'Tequila reposado de 750ml.',
        16900,
        12,
        1,
        '~/img/CAT-Tequila.webp'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Vino Tinto Reserva 750ml')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Vino Tinto Reserva 750ml',
        'Vino',
        'Vino tinto reserva de 750ml.',
        8900,
        25,
        1,
        '~/img/DES-Vino Tinto Reserva 750ml.png'
    );
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Productos WHERE Nombre = 'Pack Cervezas 6 unidades')
BEGIN
    INSERT INTO dbo.Productos
    (
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        Activo,
        ImagenUrl
    )
    VALUES
    (
        'Pack Cervezas 6 unidades',
        'Cerveza',
        'Pack de 6 cervezas.',
        6900,
        30,
        1,
        '~/img/DES-Pack Cervezas (6 unidades).webp'
    );
END
GO

/* =========================================================
   3. PROCEDIMIENTO PARA OBTENER CATEGORIAS DE TIENDA
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Store_GetCategories
AS
BEGIN
    SET NOCOUNT ON;

    SELECT DISTINCT Categoria
    FROM dbo.Productos
    WHERE Activo = 1
      AND Categoria IS NOT NULL
      AND LTRIM(RTRIM(Categoria)) <> ''
    ORDER BY Categoria ASC;
END
GO

/* =========================================================
   4. PROCEDIMIENTO PARA OBTENER PRODUCTOS DE TIENDA
   ========================================================= */
CREATE OR ALTER PROCEDURE dbo.sp_Store_GetProducts
    @Categoria NVARCHAR(100) = NULL,
    @Buscar NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        ProductoId,
        Nombre,
        Categoria,
        Descripcion,
        Precio,
        Stock,
        ISNULL(NULLIF(LTRIM(RTRIM(ImagenUrl)), ''), '~/img/whisky-premium.webp') AS ImagenUrl
    FROM dbo.Productos
    WHERE Activo = 1
      AND (
            @Categoria IS NULL
            OR Categoria = @Categoria
          )
      AND (
            @Buscar IS NULL
            OR Nombre LIKE '%' + @Buscar + '%'
            OR Categoria LIKE '%' + @Buscar + '%'
            OR Descripcion LIKE '%' + @Buscar + '%'
          )
    ORDER BY Nombre ASC;
END
GO

/* =========================================================
   5. CONSULTA PARA VER TODAS LAS CATEGORIAS ACTIVAS
   ========================================================= */
SELECT DISTINCT Categoria
FROM dbo.Productos
WHERE Activo = 1
ORDER BY Categoria;
GO

/* =========================================================
   6. CONSULTA PARA VER LOS PRODUCTOS ACTIVOS
   ========================================================= */
SELECT
    ProductoId,
    Nombre,
    Categoria,
    Descripcion,
    Precio,
    Stock,
    Activo,
    ImagenUrl
FROM dbo.Productos
ORDER BY Categoria, Nombre;
GO

/* =========================================================
   7. CONSULTA PARA VER USUARIOS ADMINISTRADORES
   ========================================================= */
SELECT
    u.UsuarioId,
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Perfil,
    u.Activo
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p
    ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Administrador';
GO

/* =========================================================
   8. CREAR ADMIN SI NO EXISTE
   ========================================================= */
DECLARE @DemoPasswordSeedThree NVARCHAR(256) = N'<SET_AT_EXECUTION>';

IF @DemoPasswordSeedThree = N'<SET_AT_EXECUTION>'
BEGIN
    THROW 51003, 'Debe proporcionar una credencial temporal fuera del repositorio.', 1;
END;

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.Usuarios u
    INNER JOIN dbo.Perfiles p
        ON p.PerfilId = u.PerfilId
    WHERE p.Nombre = 'Administrador'
      AND u.Correo = 'admin@labodega.com'
)
BEGIN
    INSERT INTO dbo.Usuarios
    (
        PerfilId,
        NombreCompleto,
        Correo,
        Contrasena,
        Activo
    )
    VALUES
    (
        (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador'),
        'Administrador General',
        'admin@labodega.com',
        @DemoPasswordSeedThree,
        1
    );
END
GO

/* =========================================================
   9. VOLVER A MOSTRAR ADMINS DESPUES DEL INSERT
   ========================================================= */
SELECT
    u.UsuarioId,
    u.NombreCompleto,
    u.Correo,
    p.Nombre AS Perfil,
    u.Activo
FROM dbo.Usuarios u
INNER JOIN dbo.Perfiles p
    ON p.PerfilId = u.PerfilId
WHERE p.Nombre = 'Administrador';
GO

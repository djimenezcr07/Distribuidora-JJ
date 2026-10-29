USE DistribuidoraJJ_DB;
GO

/* =========================================================
   CU-062 - Control de crédito y deudas de clientes
   Implementación segura basada en configuración de crédito
   y movimientos financieros auditables.
   ========================================================= */

IF OBJECT_ID('dbo.Usuarios', 'U') IS NULL
BEGIN
    THROW 52000, 'La tabla dbo.Usuarios no existe.', 1;
END
GO

IF OBJECT_ID('dbo.Perfiles', 'U') IS NULL
BEGIN
    THROW 52001, 'La tabla dbo.Perfiles no existe.', 1;
END
GO

IF NOT EXISTS (SELECT 1 FROM dbo.Perfiles WHERE Nombre = 'Cliente')
BEGIN
    INSERT INTO dbo.Perfiles (Nombre, Descripcion)
    VALUES ('Cliente', 'Cliente registrado para realizar pedidos');
END
GO

IF OBJECT_ID('dbo.ClienteCreditos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ClienteCreditos
    (
        ClienteCreditoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClienteCreditos PRIMARY KEY,
        UsuarioId INT NOT NULL,
        LimiteCredito DECIMAL(18,2) NOT NULL CONSTRAINT DF_ClienteCreditos_Limite DEFAULT 0,
        CreditoActivo BIT NOT NULL CONSTRAINT DF_ClienteCreditos_CreditoActivo DEFAULT 0,
        CreditoBloqueado BIT NOT NULL CONSTRAINT DF_ClienteCreditos_CreditoBloqueado DEFAULT 0,
        MotivoBloqueo NVARCHAR(255) NULL,
        FechaCreacion DATETIME2 NOT NULL CONSTRAINT DF_ClienteCreditos_FechaCreacion DEFAULT SYSDATETIME(),
        FechaActualizacion DATETIME2 NOT NULL CONSTRAINT DF_ClienteCreditos_FechaActualizacion DEFAULT SYSDATETIME(),
        CONSTRAINT UQ_ClienteCreditos_UsuarioId UNIQUE (UsuarioId),
        CONSTRAINT FK_ClienteCreditos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_ClienteCreditos_Limite CHECK (LimiteCredito >= 0)
    );
END
GO

IF OBJECT_ID('dbo.ClienteCreditoMovimientos', 'U') IS NULL
BEGIN
    CREATE TABLE dbo.ClienteCreditoMovimientos
    (
        CreditoMovimientoId INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_ClienteCreditoMovimientos PRIMARY KEY,
        UsuarioId INT NOT NULL,
        TipoMovimiento NVARCHAR(30) NOT NULL,
        Monto DECIMAL(18,2) NOT NULL,
        Descripcion NVARCHAR(500) NOT NULL,
        Referencia NVARCHAR(100) NULL,
        RegistradoPorUsuarioId INT NULL,
        RegistradoPorNombre NVARCHAR(150) NULL,
        FechaMovimiento DATETIME2 NOT NULL CONSTRAINT DF_ClienteCreditoMovimientos_Fecha DEFAULT SYSDATETIME(),
        CONSTRAINT FK_ClienteCreditoMovimientos_Usuarios FOREIGN KEY (UsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT FK_ClienteCreditoMovimientos_RegistradoPor FOREIGN KEY (RegistradoPorUsuarioId) REFERENCES dbo.Usuarios(UsuarioId),
        CONSTRAINT CK_ClienteCreditoMovimientos_Monto CHECK (Monto > 0),
        CONSTRAINT CK_ClienteCreditoMovimientos_Tipo CHECK (TipoMovimiento IN ('Cargo', 'Abono', 'AjustePositivo', 'AjusteNegativo'))
    );
END
GO

IF OBJECT_ID('dbo.IX_ClienteCreditoMovimientos_Usuario_Fecha', 'U') IS NULL
BEGIN
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_ClienteCreditoMovimientos_Usuario_Fecha' AND object_id = OBJECT_ID('dbo.ClienteCreditoMovimientos'))
    BEGIN
        CREATE INDEX IX_ClienteCreditoMovimientos_Usuario_Fecha
        ON dbo.ClienteCreditoMovimientos (UsuarioId, FechaMovimiento DESC);
    END
END
GO

IF OBJECT_ID('dbo.Permisos', 'U') IS NOT NULL
BEGIN
    MERGE dbo.Permisos AS target
    USING (VALUES
        ('CREDITOS_VER', 'Créditos', 'Ver créditos de clientes', 'Permite consultar crédito, deuda y movimientos financieros de clientes.'),
        ('CREDITOS_CONFIGURAR', 'Créditos', 'Configurar crédito', 'Permite definir límite, estado y bloqueo de crédito.'),
        ('CREDITOS_MOVIMIENTOS', 'Créditos', 'Registrar movimientos de crédito', 'Permite registrar cargos, abonos y ajustes.'),
        ('CREDITOS_BLOQUEAR', 'Créditos', 'Bloquear crédito', 'Permite bloquear o desbloquear el crédito de un cliente.')
    ) AS source (Codigo, Modulo, Nombre, Descripcion)
    ON target.Codigo = source.Codigo
    WHEN MATCHED THEN
        UPDATE SET
            target.Modulo = source.Modulo,
            target.Nombre = source.Nombre,
            target.Descripcion = source.Descripcion,
            target.Activo = 1
    WHEN NOT MATCHED THEN
        INSERT (Codigo, Modulo, Nombre, Descripcion, Activo)
        VALUES (source.Codigo, source.Modulo, source.Nombre, source.Descripcion, 1);

    IF OBJECT_ID('dbo.PerfilPermisos', 'U') IS NOT NULL
    BEGIN
        DECLARE @PerfilAdministrador INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Administrador');

        IF @PerfilAdministrador IS NOT NULL
        BEGIN
            INSERT INTO dbo.PerfilPermisos (PerfilId, PermisoId, UsuarioAsignacionId, UsuarioAsignacionNombre)
            SELECT @PerfilAdministrador, p.PermisoId, NULL, 'Script CU-062'
            FROM dbo.Permisos p
            WHERE p.Modulo = 'Créditos'
              AND NOT EXISTS (
                    SELECT 1
                    FROM dbo.PerfilPermisos pp
                    WHERE pp.PerfilId = @PerfilAdministrador
                      AND pp.PermisoId = p.PermisoId
              );
        END
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientCredits
    @Buscar NVARCHAR(200) = NULL,
    @EstadoCredito NVARCHAR(30) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    SET @Buscar = NULLIF(LTRIM(RTRIM(ISNULL(@Buscar, ''))), '');
    SET @EstadoCredito = NULLIF(LTRIM(RTRIM(ISNULL(@EstadoCredito, ''))), '');

    ;WITH Movimientos AS
    (
        SELECT
            UsuarioId,
            SUM(CASE WHEN TipoMovimiento IN ('Cargo', 'AjustePositivo') THEN Monto ELSE 0 END) AS TotalCargos,
            SUM(CASE WHEN TipoMovimiento IN ('Abono', 'AjusteNegativo') THEN Monto ELSE 0 END) AS TotalAbonos,
            COUNT(1) AS TotalMovimientos,
            MAX(FechaMovimiento) AS UltimoMovimiento
        FROM dbo.ClienteCreditoMovimientos
        GROUP BY UsuarioId
    ),
    Datos AS
    (
        SELECT
            u.UsuarioId,
            u.NombreCompleto,
            u.Correo,
            u.Telefono,
            CAST(ISNULL(u.Activo, 1) AS BIT) AS ClienteActivo,
            ISNULL(cc.LimiteCredito, 0) AS LimiteCredito,
            CAST(ISNULL(cc.CreditoActivo, 0) AS BIT) AS CreditoActivo,
            CAST(ISNULL(cc.CreditoBloqueado, 0) AS BIT) AS CreditoBloqueado,
            cc.MotivoBloqueo,
            CAST(CASE WHEN ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) < 0 THEN 0 ELSE ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) END AS DECIMAL(18,2)) AS DeudaActual,
            CAST(ISNULL(cc.LimiteCredito, 0) - CASE WHEN ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) < 0 THEN 0 ELSE ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) END AS DECIMAL(18,2)) AS CreditoDisponible,
            ISNULL(m.TotalMovimientos, 0) AS TotalMovimientos,
            m.UltimoMovimiento,
            cc.FechaActualizacion
        FROM dbo.Usuarios u
        LEFT JOIN dbo.ClienteCreditos cc
            ON cc.UsuarioId = u.UsuarioId
        LEFT JOIN Movimientos m
            ON m.UsuarioId = u.UsuarioId
        WHERE u.PerfilId = @ClientePerfilId
          AND (
                @Buscar IS NULL
                OR u.NombreCompleto LIKE '%' + @Buscar + '%'
                OR u.Correo LIKE '%' + @Buscar + '%'
                OR ISNULL(u.Telefono, '') LIKE '%' + @Buscar + '%'
          )
    )
    SELECT *
    FROM Datos
    WHERE
        @EstadoCredito IS NULL
        OR (@EstadoCredito = 'Activo' AND CreditoActivo = 1 AND CreditoBloqueado = 0)
        OR (@EstadoCredito = 'Bloqueado' AND CreditoBloqueado = 1)
        OR (@EstadoCredito = 'Inactivo' AND CreditoActivo = 0)
        OR (@EstadoCredito = 'ConDeuda' AND DeudaActual > 0)
        OR (@EstadoCredito = 'SinDeuda' AND DeudaActual = 0)
        OR (@EstadoCredito = 'SinCredito' AND LimiteCredito = 0 AND CreditoActivo = 0)
    ORDER BY DeudaActual DESC, NombreCompleto ASC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_GetClientCreditDetail
    @UsuarioId INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND PerfilId = @ClientePerfilId)
    BEGIN
        THROW 52002, 'El cliente seleccionado no existe.', 1;
    END

    ;WITH Movimientos AS
    (
        SELECT
            UsuarioId,
            SUM(CASE WHEN TipoMovimiento IN ('Cargo', 'AjustePositivo') THEN Monto ELSE 0 END) AS TotalCargos,
            SUM(CASE WHEN TipoMovimiento IN ('Abono', 'AjusteNegativo') THEN Monto ELSE 0 END) AS TotalAbonos
        FROM dbo.ClienteCreditoMovimientos
        WHERE UsuarioId = @UsuarioId
        GROUP BY UsuarioId
    )
    SELECT TOP 1
        u.UsuarioId,
        u.NombreCompleto,
        u.Correo,
        u.Telefono,
        u.Direccion,
        CAST(ISNULL(u.Activo, 1) AS BIT) AS ClienteActivo,
        ISNULL(cc.LimiteCredito, 0) AS LimiteCredito,
        CAST(ISNULL(cc.CreditoActivo, 0) AS BIT) AS CreditoActivo,
        CAST(ISNULL(cc.CreditoBloqueado, 0) AS BIT) AS CreditoBloqueado,
        cc.MotivoBloqueo,
        CAST(CASE WHEN ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) < 0 THEN 0 ELSE ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) END AS DECIMAL(18,2)) AS DeudaActual,
        CAST(ISNULL(cc.LimiteCredito, 0) - CASE WHEN ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) < 0 THEN 0 ELSE ISNULL(m.TotalCargos, 0) - ISNULL(m.TotalAbonos, 0) END AS DECIMAL(18,2)) AS CreditoDisponible,
        ISNULL(m.TotalCargos, 0) AS TotalCargos,
        ISNULL(m.TotalAbonos, 0) AS TotalAbonos,
        cc.FechaActualizacion
    FROM dbo.Usuarios u
    LEFT JOIN dbo.ClienteCreditos cc
        ON cc.UsuarioId = u.UsuarioId
    LEFT JOIN Movimientos m
        ON m.UsuarioId = u.UsuarioId
    WHERE u.UsuarioId = @UsuarioId
      AND u.PerfilId = @ClientePerfilId;

    SELECT
        CreditoMovimientoId,
        TipoMovimiento,
        Monto,
        Descripcion,
        Referencia,
        RegistradoPorUsuarioId,
        RegistradoPorNombre,
        FechaMovimiento
    FROM dbo.ClienteCreditoMovimientos
    WHERE UsuarioId = @UsuarioId
    ORDER BY FechaMovimiento DESC, CreditoMovimientoId DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_UpdateClientCreditSettings
    @UsuarioId INT,
    @LimiteCredito DECIMAL(18,2),
    @CreditoActivo BIT,
    @CreditoBloqueado BIT,
    @MotivoBloqueo NVARCHAR(255) = NULL,
    @RegistradoPorUsuarioId INT = NULL,
    @RegistradoPorNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    SET @MotivoBloqueo = NULLIF(LTRIM(RTRIM(ISNULL(@MotivoBloqueo, ''))), '');

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND PerfilId = @ClientePerfilId)
    BEGIN
        THROW 52003, 'El cliente seleccionado no existe.', 1;
    END

    IF @LimiteCredito < 0
    BEGIN
        THROW 52004, 'El límite de crédito no puede ser negativo.', 1;
    END

    IF (@CreditoActivo = 0 OR @CreditoBloqueado = 1) AND @MotivoBloqueo IS NULL
    BEGIN
        THROW 52005, 'Debe indicar un motivo si desactiva o bloquea el crédito.', 1;
    END

    IF EXISTS (SELECT 1 FROM dbo.ClienteCreditos WHERE UsuarioId = @UsuarioId)
    BEGIN
        UPDATE dbo.ClienteCreditos
        SET
            LimiteCredito = @LimiteCredito,
            CreditoActivo = @CreditoActivo,
            CreditoBloqueado = @CreditoBloqueado,
            MotivoBloqueo = CASE WHEN @CreditoActivo = 1 AND @CreditoBloqueado = 0 THEN NULL ELSE @MotivoBloqueo END,
            FechaActualizacion = SYSDATETIME()
        WHERE UsuarioId = @UsuarioId;
    END
    ELSE
    BEGIN
        INSERT INTO dbo.ClienteCreditos
        (
            UsuarioId,
            LimiteCredito,
            CreditoActivo,
            CreditoBloqueado,
            MotivoBloqueo
        )
        VALUES
        (
            @UsuarioId,
            @LimiteCredito,
            @CreditoActivo,
            @CreditoBloqueado,
            CASE WHEN @CreditoActivo = 1 AND @CreditoBloqueado = 0 THEN NULL ELSE @MotivoBloqueo END
        );
    END
END
GO

CREATE OR ALTER PROCEDURE dbo.sp_Admin_RegisterClientCreditMovement
    @UsuarioId INT,
    @TipoMovimiento NVARCHAR(30),
    @Monto DECIMAL(18,2),
    @Descripcion NVARCHAR(500),
    @Referencia NVARCHAR(100) = NULL,
    @RegistradoPorUsuarioId INT = NULL,
    @RegistradoPorNombre NVARCHAR(150) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @ClientePerfilId INT = (SELECT TOP 1 PerfilId FROM dbo.Perfiles WHERE Nombre = 'Cliente');
    DECLARE @LimiteCredito DECIMAL(18,2);
    DECLARE @CreditoActivo BIT;
    DECLARE @CreditoBloqueado BIT;
    DECLARE @DeudaActual DECIMAL(18,2);
    DECLARE @NuevaDeuda DECIMAL(18,2);

    SET @TipoMovimiento = LTRIM(RTRIM(ISNULL(@TipoMovimiento, '')));
    SET @Descripcion = LTRIM(RTRIM(ISNULL(@Descripcion, '')));
    SET @Referencia = NULLIF(LTRIM(RTRIM(ISNULL(@Referencia, ''))), '');
    SET @RegistradoPorNombre = NULLIF(LTRIM(RTRIM(ISNULL(@RegistradoPorNombre, ''))), '');

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuarios WHERE UsuarioId = @UsuarioId AND PerfilId = @ClientePerfilId)
    BEGIN
        THROW 52006, 'El cliente seleccionado no existe.', 1;
    END

    IF @TipoMovimiento NOT IN ('Cargo', 'Abono', 'AjustePositivo', 'AjusteNegativo')
    BEGIN
        THROW 52007, 'Tipo de movimiento de crédito no válido.', 1;
    END

    IF @Monto <= 0
    BEGIN
        THROW 52008, 'El monto debe ser mayor a cero.', 1;
    END

    IF @Descripcion = ''
    BEGIN
        THROW 52009, 'La descripción del movimiento es obligatoria.', 1;
    END

    IF NOT EXISTS (SELECT 1 FROM dbo.ClienteCreditos WHERE UsuarioId = @UsuarioId)
    BEGIN
        INSERT INTO dbo.ClienteCreditos (UsuarioId, LimiteCredito, CreditoActivo, CreditoBloqueado)
        VALUES (@UsuarioId, 0, 0, 0);
    END

    SELECT
        @LimiteCredito = LimiteCredito,
        @CreditoActivo = CreditoActivo,
        @CreditoBloqueado = CreditoBloqueado
    FROM dbo.ClienteCreditos
    WHERE UsuarioId = @UsuarioId;

    SELECT @DeudaActual = CAST(CASE WHEN ISNULL(SUM(CASE WHEN TipoMovimiento IN ('Cargo', 'AjustePositivo') THEN Monto ELSE -Monto END), 0) < 0 THEN 0 ELSE ISNULL(SUM(CASE WHEN TipoMovimiento IN ('Cargo', 'AjustePositivo') THEN Monto ELSE -Monto END), 0) END AS DECIMAL(18,2))
    FROM dbo.ClienteCreditoMovimientos
    WHERE UsuarioId = @UsuarioId;

    IF @TipoMovimiento = 'Cargo'
    BEGIN
        IF @CreditoActivo = 0
        BEGIN
            THROW 52010, 'No se puede registrar un cargo porque el crédito del cliente está inactivo.', 1;
        END

        IF @CreditoBloqueado = 1
        BEGIN
            THROW 52011, 'No se puede registrar un cargo porque el crédito del cliente está bloqueado.', 1;
        END

        IF @LimiteCredito <= 0
        BEGIN
            THROW 52012, 'No se puede registrar un cargo porque el cliente no tiene límite de crédito asignado.', 1;
        END

        IF (@DeudaActual + @Monto) > @LimiteCredito
        BEGIN
            THROW 52013, 'El cargo supera el límite de crédito disponible para este cliente.', 1;
        END
    END

    IF @TipoMovimiento IN ('Abono', 'AjusteNegativo') AND @Monto > @DeudaActual
    BEGIN
        THROW 52014, 'El monto no puede superar la deuda actual del cliente.', 1;
    END

    INSERT INTO dbo.ClienteCreditoMovimientos
    (
        UsuarioId,
        TipoMovimiento,
        Monto,
        Descripcion,
        Referencia,
        RegistradoPorUsuarioId,
        RegistradoPorNombre
    )
    VALUES
    (
        @UsuarioId,
        @TipoMovimiento,
        @Monto,
        @Descripcion,
        @Referencia,
        @RegistradoPorUsuarioId,
        @RegistradoPorNombre
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS CreditoMovimientoId;
END
GO
